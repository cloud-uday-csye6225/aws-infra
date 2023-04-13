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
variable "mysql_db_ver" {
  type    = string
  default = "8.0"
}
variable "db_name" {
  type    = string
  default = "csye6225"
}
variable "db_username" {
  type    = string
  default = "csye6225"
}
variable "db_pwd" {
}
variable "domain_name" {
  default     = "udaykk.me"
  description = "Hosted Zone"
  type        = string
}

variable "cpu_upper_limit" {
  default = "5"
  type    = string
}

variable "cpu_lower_limit" {
  default = "3"
  type    = string
}

variable "accountid" {
}

variable "certificateId" {
}