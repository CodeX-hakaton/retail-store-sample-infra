variable "environment_name" {
  description = "Name prefix for the ECR repositories."
  type        = string
}

variable "tags" {
  description = "Tags applied to all ECR repositories."
  type        = map(string)
  default     = {}
}

variable "force_delete" {
  description = "Delete repositories even when images are still present."
  type        = bool
  default     = false
}
