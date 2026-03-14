variable "environment_name" {
  description = "Name prefix for workload resources."
  type        = string
}

variable "istio_enabled" {
  description = "Whether Istio should be enabled for workload namespaces."
  type        = bool
}

variable "opentelemetry_enabled" {
  description = "Whether OpenTelemetry should be enabled for workloads."
  type        = bool
}

variable "tags" {
  description = "Tags applied to AWS resources created by the workloads module."
  type        = map(string)
  default     = {}
}

variable "app_deployment_mode" {
  description = "How application workloads are deployed into the cluster."
  type        = string
}

variable "argocd_repo_url" {
  description = "Git repository URL watched by Argo CD."
  type        = string
  default     = null
  nullable    = true
}

variable "argocd_target_revision" {
  description = "Git branch, tag, or revision watched by Argo CD."
  type        = string
  default     = null
  nullable    = true
}

variable "argocd_namespace" {
  description = "Namespace where Argo CD is installed."
  type        = string
  default     = "argocd"
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

variable "security_group_ids" {
  description = "Security groups assigned to components that use security groups for pods."
  type = object({
    catalog  = string
    orders   = string
    checkout = string
  })
}

variable "cluster" {
  description = "EKS cluster details needed to deploy workloads."
  type = object({
    name                       = string
    endpoint                   = string
    certificate_authority_data = string
    oidc_issuer_url            = string
    cluster_blocker_id         = string
    addons_blocker_id          = string
    adot_namespace             = string
  })
}

variable "dependencies" {
  description = "Backing service connection details for the retail workloads."
  type = object({
    catalog_db_endpoint                   = string
    catalog_db_port                       = number
    catalog_db_master_username            = string
    catalog_db_master_password            = string
    carts_dynamodb_table_name             = string
    carts_dynamodb_policy_arn             = string
    checkout_elasticache_primary_endpoint = string
    checkout_elasticache_port             = number
    orders_db_endpoint                    = string
    orders_db_port                        = number
    orders_db_database_name               = string
    orders_db_master_username             = string
    orders_db_master_password             = string
    mq_broker_endpoint                    = string
    mq_user                               = string
    mq_password                           = string
  })
  sensitive = true
}
