variable "rancher_url" {
  type        = string
  description = "Rancher server URL"
}

variable "rancher_token" {
  type        = string
  description = "Rancher API token"
  sensitive   = true
}

variable "ami_id" {
  type        = string
  description = "EC2 AMI ID"
}

variable "docker_version" {
  type        = string
  description = "Docker version to install"
}

variable "region" {
  default     = "us-west-2"
  description = "AWS region"
}

variable "instance_type" {
  default     = "t3.medium"
  description = "EC2 instance type"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for EC2 instance"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for EC2 instance"
}

variable "security_group" {
  type        = string
  description = "Security Group for EC2 instance"
}

variable "ssh_user" {
  default     = "ec2-user"
  description = "SSH user"
}