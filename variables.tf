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

variable "name" {
  description = "AWS Instance name tag"
  default     = "vivek-docker-testing"
}

variable "docker_version" {
  type        = string
  default     = "28.0.4"
  description = "Docker version to install"
}

variable "region" {
  default     = "us-east-2"
  description = "AWS region"
}

variable "instance_type" {
  default     = "t3.medium"
  description = "EC2 instance type"
}

variable "vpc_id" {
  type        = string
  default     = "vpc-bfccf4d7"
  description = "VPC ID for EC2 instance"
}

variable "subnet_id" {
  type        = string
  default     = "subnet-6127e62d"
  description = "Subnet ID for EC2 instance"
}

variable "security_group" {
  type        = string
  default     = "sg-08e8243a8cfbea8a0"
  description = "Security Group for EC2 instance"
}

variable "ssh_user" {
  default     = "ubuntu"
  description = "SSH user"
}

variable "AWS_KEY_ID" {
  description = "AWS KEY ID"
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "SECRET KEY ID"
}