variable "aws_region" {
}

variable "aws_profile" {
}

variable "name_prefix" {
}

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "security_cidr" {
  default = "0.0.0.0/0"
}
variable "ami_id" {
  # default = "ami-03081c6bdfb5e9f5d"
}
variable "instance_type" {
  default = "t2.micro"
}
variable "key_name" {
  default = "ec2"
}
variable "wsg_protocol" {
  type    = string
  default = "tcp"
}