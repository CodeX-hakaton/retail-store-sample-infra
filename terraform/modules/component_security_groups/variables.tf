variable "environment_name" {
  description = "Name prefix for the security groups."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security groups will be created."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR allowed to reach the service ports."
  type        = string
}

variable "tags" {
  description = "Tags applied to all security groups."
  type        = map(string)
  default     = {}
}
