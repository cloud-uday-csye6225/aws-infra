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
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "privateRtAssoc" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

data "aws_availability_zones" "available" {}

