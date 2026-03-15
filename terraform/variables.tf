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

variable "observability_enabled" {
  description = "Deploy the observability stack for metrics, logs, and Grafana."
  type        = bool
  default     = false
}

variable "observability_namespace" {
  description = "Namespace where the observability stack is installed."
  type        = string
  default     = "observability"
}

variable "grafana_admin_password" {
  description = "Optional Grafana admin password override. If omitted, Terraform generates one."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "alert_email_smarthost" {
  description = "SMTP smart host used by Alertmanager, in host:port format."
  type        = string
  default     = null
  nullable    = true
}

variable "alert_email_username" {
  description = "SMTP username used by Alertmanager."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "alert_email_password" {
  description = "SMTP password used by Alertmanager."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "alert_email_recipients" {
  description = "Email recipients for Alertmanager. Defaults to cloudflare_access_allowed_emails when unset."
  type        = list(string)
  default     = []
}

variable "eks_cluster_admin_principal_arns" {
  description = "Additional IAM principal ARNs that should receive EKS cluster-admin access."
  type        = list(string)
  default     = []
}

variable "expected_aws_account_id" {
  description = "Expected AWS account ID for the selected environment. Terraform fails fast if the current caller identity does not match."
  type        = string
  default     = null
  nullable    = true
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

variable "aws_backup_enabled" {
  description = "Enable AWS Backup for durable data behind the stateless application services."
  type        = bool
  default     = false
}

variable "aws_backup_destination_region" {
  description = "Secondary AWS region that receives cross-region backup copies when aws_backup_enabled is true."
  type        = string
  default     = null
  nullable    = true
}

variable "aws_backup_schedule" {
  description = "AWS Backup cron expression for the daily backup rule."
  type        = string
  default     = "cron(0 3 * * ? *)"
}

variable "aws_backup_start_window_minutes" {
  description = "Minutes AWS Backup can wait before starting a scheduled job."
  type        = number
  default     = 60
}

variable "aws_backup_completion_window_minutes" {
  description = "Minutes AWS Backup can spend completing a scheduled job."
  type        = number
  default     = 180
}

variable "aws_backup_delete_after_days" {
  description = "Retention period in days for backups stored in the primary region."
  type        = number
  default     = 35
}

variable "aws_backup_copy_delete_after_days" {
  description = "Retention period in days for copies stored in the disaster recovery region."
  type        = number
  default     = 90
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

variable "argocd_public_enabled" {
  description = "Expose the Argo CD server through a public ALB ingress and Cloudflare DNS."
  type        = bool
  default     = false
}

variable "grafana_public_enabled" {
  description = "Expose Grafana through a public ALB ingress and Cloudflare DNS."
  type        = bool
  default     = false
}

variable "grafana_public_hostname" {
  description = "Optional fully-qualified public hostname for Grafana. Overrides grafana_cloudflare_record_name/cloudflare_zone_name when set."
  type        = string
  default     = null
  nullable    = true
}

variable "grafana_cloudflare_record_name" {
  description = "DNS record name within the Cloudflare zone for the Grafana endpoint."
  type        = string
  default     = "grafana"
}

variable "grafana_origin_tls_acm_certificate_arn" {
  description = "Optional ACM certificate ARN override for the public Grafana ALB ingress. If omitted, Terraform creates and validates a certificate automatically."
  type        = string
  default     = null
  nullable    = true
}

variable "argocd_public_hostname" {
  description = "Optional fully-qualified public hostname for Argo CD. Overrides argocd_cloudflare_record_name/cloudflare_zone_name when set."
  type        = string
  default     = null
  nullable    = true
}

variable "argocd_cloudflare_record_name" {
  description = "DNS record name within the Cloudflare zone for the Argo CD endpoint."
  type        = string
  default     = "argocd"
}

variable "argocd_origin_tls_acm_certificate_arn" {
  description = "Optional ACM certificate ARN override for the public Argo CD ALB ingress. If omitted, Terraform creates and validates a certificate automatically."
  type        = string
  default     = null
  nullable    = true
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

variable "origin_tls_enabled" {
  description = "Terminate HTTPS on the public AWS load balancer instead of exposing the origin over plain HTTP. Currently supported when istio_enabled is false."
  type        = bool
  default     = false
}

variable "origin_tls_acm_certificate_arn" {
  description = "Optional ACM certificate ARN override attached to the public AWS load balancer when origin_tls_enabled is true. If omitted, Terraform creates and validates a certificate automatically."
  type        = string
  default     = null
  nullable    = true
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
