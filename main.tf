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
    description = "TCP Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.security_cidr]
  }

  ingress {
    description = "TCP Access"
    from_port   = 80
    to_port     = 80
    protocol    = var.wsg_protocol
    cidr_blocks = [var.security_cidr]
  }

  ingress {
    description = "TCP Access"
    from_port   = 443
    to_port     = 443
    protocol    = var.wsg_protocol
    cidr_blocks = [var.security_cidr]
  }

  ingress {
    description = "TCP Access"
    from_port   = 8082
    to_port     = 8082
    protocol    = var.wsg_protocol
    cidr_blocks = [var.security_cidr]
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

resource "aws_instance" "my_ami" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.myPublicSubnet[1].id
  key_name                    = var.key_name
  disable_api_termination     = false

  vpc_security_group_ids = [
    aws_security_group.application.id
  ]
  root_block_device {
    delete_on_termination = true
    volume_size           = 50
    volume_type           = "gp2"
  }
  iam_instance_profile = aws_iam_instance_profile.iam_profile.name

  user_data = <<EOF
#!/bin/bash
cd /home/ec2-user || return
touch custom.properties
echo "aws.region=${var.aws_region}" >> custom.properties
echo "aws.s3.bucket=${aws_s3_bucket.s3b.bucket}" >> custom.properties

echo "spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver" >> custom.properties
echo "spring.datasource.url=jdbc:mysql://${aws_db_instance.db_instance.endpoint}:3306/${aws_db_instance.db_instance.db_name}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" >> custom.properties
echo "spring.datasource.username=${aws_db_instance.db_instance.username}" >> custom.properties
echo "spring.datasource.password=${aws_db_instance.db_instance.password}" >> custom.properties

echo "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQL8Dialect" >> custom.properties
echo "spring.jpa.database=mysql" >> custom.properties
echo "spring.jpa.show-sql=true" >> custom.properties
echo "spring.jpa.hibernate.ddl-auto=update" >> custom.properties
echo "server.port=8082" >> custom.properties
  EOF

  tags = {
    Name = "my-${var.name_prefix}-ami"
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
  bucket              = aws_s3_bucket.s3b.id
  block_public_acls   = true
  block_public_policy = true
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



output "ec2instance" {
  value = aws_instance.my_ami.id
}