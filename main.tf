resource "aws_vpc" "myvpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "my-${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "myIgw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "my-${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "myPublicSubnet" {
  count = 3

  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, count.index)
  vpc_id            = aws_vpc.myvpc.id
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "my-${var.name_prefix}-public-${count.index + 1}"
  }
}

resource "aws_subnet" "myPrivateSubnet" {
  count = 3

  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, count.index + 11)
  vpc_id            = aws_vpc.myvpc.id
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "my-${var.name_prefix}-private-${count.index + 1}"
  }
}

resource "aws_route_table" "myPublicRt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myIgw.id
  }

  tags = {
    Name = "my-${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table" "myPrivateRt" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "my-${var.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "publicRtAssoc" {
  count          = 3
  subnet_id      = aws_subnet.myPublicSubnet[count.index].id
  route_table_id = aws_route_table.myPublicRt.id
}

resource "aws_route_table_association" "privateRtAssoc" {
  count          = 3
  subnet_id      = aws_subnet.myPrivateSubnet[count.index].id
  route_table_id = aws_route_table.myPrivateRt.id
}

data "aws_availability_zones" "available" {}

resource "aws_security_group" "application" {
  name        = "application"
  description = "Security group for the Webapp application"
  vpc_id      = aws_vpc.myvpc.id
  ingress {
    description     = "TCP Access"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
  }

  ingress {
    description     = "TCP Access"
    from_port       = 8082
    to_port         = 8082
    protocol        = var.wsg_protocol
    security_groups = [aws_security_group.load_balancer.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.security_cidr]
    # ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "application"
  }
}



//create database security group link to webapp
resource "aws_security_group" "db_security_group" {
  name        = "database"
  description = "Enable MySQL access on port 3306"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description     = "TCP Access"
    from_port       = 3306
    to_port         = 3306
    protocol        = var.wsg_protocol
    security_groups = [aws_security_group.application.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
  }
  tags = {
    Name = "database"
  }
}

resource "random_pet" "rg" {
  keepers = {
    # Generate a new pet name each time we switch to a new profile
    random_name = var.aws_profile
  }
}
// Create s3 bucket
resource "aws_s3_bucket" "s3b" {
  bucket        = random_pet.rg.id
  force_destroy = true
  tags = {
    Name = "${random_pet.rg.id}"
  }
}
resource "aws_s3_bucket_acl" "s3b_acl" {
  bucket = aws_s3_bucket.s3b.id
  acl    = "private"
}
resource "aws_s3_bucket_lifecycle_configuration" "s3b_lifecycle" {
  bucket = aws_s3_bucket.s3b.id
  rule {
    id     = "rule-1"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3b_encryption" {
  bucket = aws_s3_bucket.s3b.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

}

resource "aws_s3_bucket_public_access_block" "s3_block" {
  bucket                  = aws_s3_bucket.s3b.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_db_parameter_group" "mysql_8" {
  name   = "rds-pg-${var.name_prefix}"
  family = "mysql${var.mysql_db_ver}"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }

  parameter {
    name         = "performance_schema"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  depends_on = [aws_subnet.myPrivateSubnet]
  name       = "main"
  subnet_ids = aws_subnet.myPrivateSubnet.*.id

  tags = {
    Name = "DB subnet group"
  }
}

resource "aws_iam_policy" "policy" {
  name        = "WebAppS3"
  description = "policy for s3"

  policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Action" : ["s3:DeleteObject", "s3:PutObject", "s3:GetObject", "s3:ListAllMyBuckets"]
        "Effect" : "Allow"
        "Resource" : ["arn:aws:s3:::${aws_s3_bucket.s3b.bucket}",
        "arn:aws:s3:::${aws_s3_bucket.s3b.bucket}/*"]
      }
    ]
  })
}

resource "aws_iam_role" "ec2-role" {
  name = "EC2-CSYE6225"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_db_instance" "db_instance" {
  identifier        = var.db_name
  allocated_storage = 10
  engine            = "mysql"
  engine_version    = var.mysql_db_ver
  multi_az          = false

  instance_class         = "db.t3.micro"
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds_kmskey.arn
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_pwd
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.mysql_8.name
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  skip_final_snapshot    = true
}

resource "aws_iam_policy_attachment" "web-app-s3-attach" {
  name       = "gh-upload-to-s3-attachment"
  roles      = [aws_iam_role.ec2-role.name]
  policy_arn = aws_iam_policy.policy.arn
}



resource "aws_iam_instance_profile" "iam_profile" {
  name = "iam_profile"
  role = aws_iam_role.ec2-role.name
}

data "aws_route53_zone" "hosted_zone" {
  name         = "${var.aws_profile}.${var.domain_name}"
  private_zone = false
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = data.aws_route53_zone.hosted_zone.name
  type    = "A"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_iam_policy_attachment" "web-app-atach-cloudwatch" {
  name       = "attach-cloudwatch-server-policy-ec2"
  roles      = [aws_iam_role.ec2-role.name]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_security_group" "load_balancer" {
  name        = "load_balancer"
  description = "Security group for the load balancer"
  vpc_id      = aws_vpc.myvpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.security_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.security_cidr]
  }

  tags = {
    Name = "load balancer"
  }
}

data "template_file" "user_data" {

  template = <<EOF
#!/bin/bash
cd /home/ec2-user || return
touch application.properties
echo "aws.region=${var.aws_region}" >> application.properties
echo "aws.s3.bucket=${aws_s3_bucket.s3b.bucket}" >> application.properties
echo "server.port=8082" >> application.properties
echo "spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver" >> application.properties
echo "spring.datasource.url=jdbc:mysql://${aws_db_instance.db_instance.endpoint}/${aws_db_instance.db_instance.db_name}?useSSL=true&requireSSL=true&allowPublicKeyRetrieval=true&serverTimezone=UTC" >> application.properties
echo "spring.datasource.username=${aws_db_instance.db_instance.username}" >> application.properties
echo "spring.datasource.password=${aws_db_instance.db_instance.password}" >> application.properties
echo "spring.jpa.properties.hibernate.show_sql=true" >> application.properties
echo "spring.jpa.properties.hibernate.use_sql_comments=true" >> application.properties
echo "spring.jpa.properties.hibernate.format_sql=true" >> application.properties
echo "logging.level.org.hibernate.type=trace" >> application.properties
echo "#spring.jpa.properties.hibernate.dialect = org.hibernate.dialect.MySQL5InnoDBDialect" >> application.properties
echo "spring.jpa.hibernate.ddl-auto=update" >> application.properties
echo "logging.file.path=/home/ec2-user" >> application.properties
echo "logging.file.name=/home/ec2-user/csye6225logs.log" >> application.properties
echo "publish.metrics=true" >> application.properties
echo "metrics.statsd.host=localhost" >> application.properties
echo "metrics.statsd.port=8125" >> application.properties
echo "metrics.prefix=webapp" >> application.properties
sudo cp /tmp/config.json /opt/config.json
sudo chmod 774 /opt/config.json
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/config.json
  EOF

}


resource "aws_launch_template" "asg_launch_config" {
  name = "asg_launch_config"
  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      delete_on_termination = true
      volume_size           = 50
      volume_type           = "gp2"
      encrypted             = true
      kms_key_id            = aws_kms_key.ec2_ebs_key.arn
    }
  }
  disable_api_termination = false
  iam_instance_profile {
    name = aws_iam_instance_profile.iam_profile.name
  }
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  monitoring {
    enabled = true
  }
  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = aws_subnet.myPublicSubnet[1].id
    security_groups             = [aws_security_group.application.id]
  }
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "asg_launch_config"
    }
  }
  user_data = base64encode(data.template_file.user_data.rendered)

}

resource "aws_autoscaling_group" "autoscaling_group" {
  name                = "autoscaling_group"
  desired_capacity    = 1
  max_size            = 3
  min_size            = 1
  default_cooldown    = 60
  vpc_zone_identifier = [for k, v in aws_subnet.myPublicSubnet : v.id]
  target_group_arns   = [aws_lb_target_group.alb_tg.arn]

  tag {
    key                 = "Application"
    value               = "WebApp"
    propagate_at_launch = true
  }

  launch_template {
    id      = aws_launch_template.asg_launch_config.id
    version = "$Latest"
  }
}
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 10
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

resource "aws_cloudwatch_metric_alarm" "upper_limit" {
  alarm_name          = "upper_limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = var.cpu_upper_limit

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }

  alarm_description = "Checks if the ec2 instance crosses the defined upper limit and triggers a scale up policy"
  alarm_actions     = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 10
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

resource "aws_cloudwatch_metric_alarm" "lower_limit" {
  alarm_name          = "lower_limit"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = var.cpu_lower_limit

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }

  alarm_description = "Checks if the ec2 instance falls below the defined lower limit and triggers a scale down policy"
  alarm_actions     = [aws_autoscaling_policy.scale_down.arn]
}

resource "aws_lb" "lb" {
  name               = "webapp-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer.id]
  subnets            = [for subnet in aws_subnet.myPublicSubnet : subnet.id]

  enable_deletion_protection = false

  tags = {
    application = "WebApp"
  }
}

resource "aws_lb_target_group" "alb_tg" {
  name        = "alb-tg"
  target_type = "instance"
  port        = 8082
  protocol    = "HTTP"
  vpc_id      = aws_vpc.myvpc.id
  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    matcher             = "200"
  }
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:${var.accountid}:certificate/${var.certificateId}"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

resource "aws_kms_key" "rds_kmskey" {
  description             = "rds key"
  deletion_window_in_days = 10
  policy = jsonencode({
    Id = "key-consolepolicy-1"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          "AWS" : "arn:aws:iam::${var.accountid}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow use of the key",
        Effect = "Allow",
        Principal = {
          "AWS" : "arn:aws:iam::${var.accountid}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow attachment of persistent resources",
        Effect = "Allow",
        Principal = {
          "AWS" : "arn:aws:iam::${var.accountid}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ],
        Resource = "*",
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
      }
    ]
    Version = "2012-10-17"
  })
}


resource "aws_kms_key" "ec2_ebs_key" {
  description             = "ebs key"
  deletion_window_in_days = 10
  policy = jsonencode({
    Id = "key-consolepolicy-1"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          "AWS" : "arn:aws:iam::${var.accountid}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow use of the key",
        Effect = "Allow",
        Principal = {
          "AWS" : "arn:aws:iam::${var.accountid}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow attachment of persistent resources",
        Effect = "Allow",
        Principal = {
          "AWS" : "arn:aws:iam::${var.accountid}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ],
        Resource = "*",
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
      }
    ]
    Version = "2012-10-17"
  })
}

