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
  tags = {
    Name = "my-${var.name_prefix}-ami"
  }

}


output "ec2instance" {
  value = aws_instance.my_ami.id
}