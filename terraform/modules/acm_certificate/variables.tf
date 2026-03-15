variable "domain_name" {
  description = "Primary domain name for the ACM certificate."
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional hostnames covered by the ACM certificate."
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = "Cloudflare zone ID used for DNS validation records."
  type        = string
}

variable "tags" {
  description = "Tags applied to the ACM certificate."
  type        = map(string)
  default     = {}
}
