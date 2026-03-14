variable "environment_name" {
  description = "Name prefix for all resources in this environment."
  type        = string
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-north-1"
}

variable "cluster_version" {
  description = "EKS cluster version."
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "istio_enabled" {
  description = "Enable Istio and expose the UI through the Istio ingress gateway."
  type        = bool
  default     = false
}

variable "opentelemetry_enabled" {
  description = "Enable the ADOT addon and inject OpenTelemetry instrumentation into workloads."
  type        = bool
  default     = false
}

variable "additional_tags" {
  description = "Additional tags merged onto the default environment tags."
  type        = map(string)
  default     = {}
}

variable "container_image_overrides" {
  description = "Optional image overrides for the retail application components."
  type = object({
    default_repository = optional(string)
    default_tag        = optional(string)

    ui       = optional(string)
    catalog  = optional(string)
    cart     = optional(string)
    checkout = optional(string)
    orders   = optional(string)
  })
  default = {}
}

variable "managed_ecr_enabled" {
  description = "Create private ECR repositories for the application services and point workload images at them."
  type        = bool
  default     = false
}

variable "managed_ecr_force_delete" {
  description = "Allow Terraform to delete managed ECR repositories even if they still contain images."
  type        = bool
  default     = false
}

variable "app_deployment_mode" {
  description = "How application workloads are deployed into the cluster."
  type        = string
  default     = "terraform"

  validation {
    condition     = contains(["terraform", "argocd"], var.app_deployment_mode)
    error_message = "app_deployment_mode must be either 'terraform' or 'argocd'."
  }
}

variable "argocd_repo_url" {
  description = "Git repository URL watched by Argo CD when app_deployment_mode is argocd."
  type        = string
  default     = "https://github.com/CodeX-hakaton/retail-store-sample-infra.git"
}

variable "argocd_target_revision" {
  description = "Git branch, tag, or revision watched by Argo CD when app_deployment_mode is argocd."
  type        = string
  default     = null
  nullable    = true
}

variable "argocd_namespace" {
  description = "Namespace where Argo CD is installed."
  type        = string
  default     = "argocd"
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID used for Zero Trust resources. Inject at runtime."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID used for DNS records. Inject at runtime."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_zone_name" {
  description = "Cloudflare DNS zone name used to assemble the public hostname."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_record_name" {
  description = "DNS record name within the Cloudflare zone. Use @ or an empty string for the zone apex."
  type        = string
  default     = "@"
}

variable "cloudflare_public_hostname" {
  description = "Optional fully-qualified hostname. Overrides cloudflare_zone_name/cloudflare_record_name when set."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_proxied" {
  description = "Whether the Cloudflare DNS record should proxy traffic."
  type        = bool
  default     = true
}

variable "cloudflare_access_application_name" {
  description = "Optional display name for the Zero Trust Access application."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_access_policy_name" {
  description = "Optional name for the Zero Trust Access allow policy."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_access_allowed_email_domains" {
  description = "Email domains allowed to access the application."
  type        = list(string)
  default     = []
}

variable "cloudflare_access_allowed_emails" {
  description = "Individual email addresses allowed to access the application."
  type        = list(string)
  default     = []
}

variable "cloudflare_access_allowed_identity_provider_ids" {
  description = "Optional Cloudflare identity provider IDs allowed by the application."
  type        = list(string)
  default     = []
}

variable "cloudflare_access_auto_redirect_to_identity" {
  description = "Whether Access should automatically redirect to the configured identity provider."
  type        = bool
  default     = false
}

variable "cloudflare_access_session_duration" {
  description = "Session duration enforced by the Access application."
  type        = string
  default     = "24h"
}

variable "cloudflare_access_app_launcher_visible" {
  description = "Whether the Access application should appear in the Cloudflare app launcher."
  type        = bool
  default     = true
}

variable "cloudflare_zero_trust_enabled" {
  description = "Whether to manage Cloudflare Zero Trust Access resources for the application hostname."
  type        = bool
  default     = false
}

variable "cloudflare_zero_trust_organization_enabled" {
  description = "Whether to manage the Cloudflare Zero Trust organization resource."
  type        = bool
  default     = false
}

variable "cloudflare_zero_trust_organization_name" {
  description = "Zero Trust organization name."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_zero_trust_auth_domain" {
  description = "Zero Trust authentication domain."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_zero_trust_is_ui_read_only" {
  description = "Whether the Zero Trust UI should be read-only."
  type        = bool
  default     = true
}

variable "cloudflare_zero_trust_session_duration" {
  description = "Session duration for the Zero Trust organization."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_zero_trust_ui_read_only_toggle_reason" {
  description = "Optional reason shown when UI read-only mode is enabled."
  type        = string
  default     = "Managed by Terraform"
}
