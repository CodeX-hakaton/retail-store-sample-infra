variable "account_id" {
  description = "Cloudflare account ID used for Zero Trust resources."
  type        = string
  default     = null
  nullable    = true
}

variable "zone_id" {
  description = "Cloudflare zone ID used for DNS."
  type        = string
}

variable "public_hostname" {
  description = "Public hostname protected by Cloudflare Access."
  type        = string
}

variable "origin_hostname" {
  description = "Origin hostname that Cloudflare should proxy traffic to."
  type        = string
}

variable "proxied" {
  description = "Whether the DNS record should be proxied through Cloudflare."
  type        = bool
  default     = true
}

variable "zero_trust_enabled" {
  description = "Whether to manage Zero Trust Access resources for the application."
  type        = bool
  default     = false
}

variable "access_application_name" {
  description = "Display name for the Zero Trust Access application."
  type        = string
}

variable "access_policy_name" {
  description = "Name for the Zero Trust Access allow policy."
  type        = string
}

variable "access_allowed_email_domains" {
  description = "Email domains allowed to access the application."
  type        = list(string)
  default     = []
}

variable "access_allowed_emails" {
  description = "Individual email addresses allowed to access the application."
  type        = list(string)
  default     = []
}

variable "access_allowed_identity_provider_ids" {
  description = "Optional Cloudflare identity provider IDs allowed by the application."
  type        = list(string)
  default     = []
}

variable "access_auto_redirect_to_identity" {
  description = "Whether Access should automatically redirect to the configured identity provider."
  type        = bool
  default     = false
}

variable "access_session_duration" {
  description = "Session duration enforced by the Access application."
  type        = string
  default     = "24h"
}

variable "access_app_launcher_visible" {
  description = "Whether the Access application should appear in the Cloudflare app launcher."
  type        = bool
  default     = true
}

variable "manage_zero_trust_organization" {
  description = "Whether to manage the Cloudflare Zero Trust organization resource."
  type        = bool
  default     = false
}

variable "zero_trust_organization_name" {
  description = "Zero Trust organization name."
  type        = string
  default     = null
  nullable    = true
}

variable "zero_trust_auth_domain" {
  description = "Zero Trust authentication domain."
  type        = string
  default     = null
  nullable    = true
}

variable "zero_trust_is_ui_read_only" {
  description = "Whether the Zero Trust UI should be read-only."
  type        = bool
  default     = true
}

variable "zero_trust_session_duration" {
  description = "Session duration for the Zero Trust organization."
  type        = string
  default     = null
  nullable    = true
}

variable "zero_trust_ui_read_only_toggle_reason" {
  description = "Optional reason shown when UI read-only mode is enabled."
  type        = string
  default     = "Managed by Terraform"
}
