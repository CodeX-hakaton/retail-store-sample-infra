variable "environment_name" {
  description = "Name prefix used for AWS Backup resources."
  type        = string
}

variable "destination_region" {
  description = "AWS region that receives cross-region backup copies."
  type        = string
}

variable "source_resource_arns" {
  description = "Resource ARNs protected by AWS Backup."
  type        = list(string)
}

variable "schedule" {
  description = "Backup schedule expression."
  type        = string
}

variable "start_window_minutes" {
  description = "Minutes AWS Backup can wait before starting the job."
  type        = number
}

variable "completion_window_minutes" {
  description = "Minutes AWS Backup can spend completing the job."
  type        = number
}

variable "delete_after_days" {
  description = "Retention in days for backups kept in the source region."
  type        = number
}

variable "copy_delete_after_days" {
  description = "Retention in days for cross-region backup copies."
  type        = number
}

variable "tags" {
  description = "Tags applied to AWS Backup resources."
  type        = map(string)
  default     = {}
}
