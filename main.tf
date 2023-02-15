# VPC
resource "aws_vpc" "example" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "my-${var.name_prefix}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "my-igw"
  }
}

# Public subnets
resource "aws_subnet" "public" {
  count = 3

  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, count.index)
  vpc_id            = aws_vpc.example.id
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "my-${var.name_prefix}-public-${count.index + 1}"
  }
}

# Private subnets
resource "aws_subnet" "private" {
  count = 3

  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, count.index + 11)
  vpc_id            = aws_vpc.example.id
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "my-${var.name_prefix}-private-${count.index + 1}"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }

  tags = {
    Name = "my-${var.name_prefix}-public-rt"
  }
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "my-${var.name_prefix}-private-rt"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Data Sources
data "aws_availability_zones" "available" {}

# Variables
variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

# resource "aws_vpc" "my_vpc" {
#   cidr_block = "10.0.0.0/16"

#   tags = {
#     Name = "myVpc"
#   }
# }

# resource "aws_internet_gateway" "my_igw" {
#   vpc_id = aws_vpc.my_vpc.id

#   tags = {
#     Name = "my-igw"
#   }
# }

# resource "aws_subnet" "public_subnet_1" {
#   vpc_id                  = aws_vpc.my_vpc.id
#   cidr_block              = "10.0.1.0/24"
#   availability_zone       = "${var.aws_region}${var.aws_zone[0]}"
#   map_public_ip_on_launch = true

#   tags = {
#     Name = "public-subnet-1"
#   }
# }

# resource "aws_subnet" "public_subnet_2" {
#   vpc_id                  = aws_vpc.my_vpc.id
#   cidr_block              = "10.0.2.0/24"
#   availability_zone       = "${var.aws_region}${var.aws_zone[1]}"
#   map_public_ip_on_launch = true

#   tags = {
#     Name = "public-subnet-2"
#   }
# }

# resource "aws_subnet" "public_subnet_3" {
#   vpc_id                  = aws_vpc.my_vpc.id
#   cidr_block              = "10.0.3.0/24"
#   availability_zone       = "${var.aws_region}${var.aws_zone[2]}"
#   map_public_ip_on_launch = true

#   tags = {
#     Name = "public-subnet-3"
#   }
# }

# resource "aws_subnet" "private_subnet_4" {
#   vpc_id            = aws_vpc.my_vpc.id
#   cidr_block        = "10.0.4.0/24"
#   availability_zone = "${var.aws_region}${var.aws_zone[0]}"

#   tags = {
#     Name = "private-subnet-4"
#   }
# }

# resource "aws_subnet" "private_subnet_5" {
#   vpc_id            = aws_vpc.my_vpc.id
#   cidr_block        = "10.0.5.0/24"
#   availability_zone = "${var.aws_region}${var.aws_zone[1]}"

#   tags = {
#     Name = "private-subnet-5"
#   }
# }

# resource "aws_subnet" "private_subnet_6" {
#   vpc_id            = aws_vpc.my_vpc.id
#   cidr_block        = "10.0.6.0/24"
#   availability_zone = "${var.aws_region}${var.aws_zone[2]}"

#   tags = {
#     Name = "private-subnet-6"
#   }
# }

# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.my_vpc.id

#   tags = {
#     Name = "public-route-table"
#   }

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.my_igw.id
#   }
# }

# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.my_vpc.id

#   tags = {
#     Name = "private-route-table"
#   }
# }

# resource "aws_route_table_association" "public-art-1" {
#   subnet_id      = aws_subnet.public_subnet_1.id
#   route_table_id = aws_route_table.public.id
# }

# resource "aws_route_table_association" "public-art-2" {
#   subnet_id      = aws_subnet.public_subnet_2.id
#   route_table_id = aws_route_table.public.id
# }

# resource "aws_route_table_association" "public-art-3" {
#   subnet_id      = aws_subnet.public_subnet_3.id
#   route_table_id = aws_route_table.public.id
# }

# resource "aws_route_table_association" "private-art-4" {
#   subnet_id      = aws_subnet.private_subnet_4.id
#   route_table_id = aws_route_table.private.id
# }

# resource "aws_route_table_association" "private-art-5" {
#   subnet_id      = aws_subnet.private_subnet_5.id
#   route_table_id = aws_route_table.private.id
# }

# resource "aws_route_table_association" "private-art-6" {
#   subnet_id      = aws_subnet.private_subnet_6.id
#   route_table_id = aws_route_table.private.id
# }