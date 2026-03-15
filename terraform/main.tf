locals {
  image_catalog_metadata = jsondecode(file("${path.module}/modules/images/generated.tf.json"))
  default_image_tag      = coalesce(try(var.container_image_overrides.default_tag, null), local.image_catalog_metadata.locals.published_tag)
  security_groups_active = !var.opentelemetry_enabled
  common_tags            = merge(module.tags.result, var.additional_tags)
  managed_ecr_registry   = var.managed_ecr_enabled ? "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com" : null
  managed_ecr_repository_urls = var.managed_ecr_enabled ? {
    catalog  = "${local.managed_ecr_registry}/${var.environment_name}-catalog"
    cart     = "${local.managed_ecr_registry}/${var.environment_name}-cart"
    checkout = "${local.managed_ecr_registry}/${var.environment_name}-checkout"
    orders   = "${local.managed_ecr_registry}/${var.environment_name}-orders"
    ui       = "${local.managed_ecr_registry}/${var.environment_name}-ui"
  } : {}
  managed_ecr_image_overrides = { for service, repository_url in local.managed_ecr_repository_urls : service => "${repository_url}:${local.default_image_tag}" }
  normalized_container_image_overrides = {
    for key, value in var.container_image_overrides : key => value
    if value != null
  }
  effective_container_image_overrides = merge(local.managed_ecr_image_overrides, local.normalized_container_image_overrides)
  effective_alert_email_recipients    = length(var.alert_email_recipients) > 0 ? var.alert_email_recipients : var.cloudflare_access_allowed_emails
  cloudflare_public_hostname = var.cloudflare_public_hostname != null ? var.cloudflare_public_hostname : (
    var.cloudflare_zone_name == null ? null : (
      contains(["", "@"], trimspace(var.cloudflare_record_name)) ? var.cloudflare_zone_name : "${trimspace(var.cloudflare_record_name)}.${var.cloudflare_zone_name}"
    )
  )
  argocd_public_hostname = var.argocd_public_hostname != null ? var.argocd_public_hostname : (
    var.cloudflare_zone_name == null ? null : (
      contains(["", "@"], trimspace(var.argocd_cloudflare_record_name)) ? var.cloudflare_zone_name : "${trimspace(var.argocd_cloudflare_record_name)}.${var.cloudflare_zone_name}"
    )
  )
  grafana_public_hostname = var.grafana_public_hostname != null ? var.grafana_public_hostname : (
    var.cloudflare_zone_name == null ? null : (
      contains(["", "@"], trimspace(var.grafana_cloudflare_record_name)) ? var.cloudflare_zone_name : "${trimspace(var.grafana_cloudflare_record_name)}.${var.cloudflare_zone_name}"
    )
  )
  normalized_origin_tls_acm_certificate_arn = var.origin_tls_acm_certificate_arn != null ? (
    trimspace(var.origin_tls_acm_certificate_arn) != "" ? var.origin_tls_acm_certificate_arn : null
  ) : null
  normalized_argocd_origin_tls_acm_certificate_arn = var.argocd_origin_tls_acm_certificate_arn != null ? (
    trimspace(var.argocd_origin_tls_acm_certificate_arn) != "" ? var.argocd_origin_tls_acm_certificate_arn : null
  ) : null
  normalized_grafana_origin_tls_acm_certificate_arn = var.grafana_origin_tls_acm_certificate_arn != null ? (
    trimspace(var.grafana_origin_tls_acm_certificate_arn) != "" ? var.grafana_origin_tls_acm_certificate_arn : null
  ) : null
  normalized_aws_backup_destination_region = var.aws_backup_destination_region != null ? (
    trimspace(var.aws_backup_destination_region) != "" ? trimspace(var.aws_backup_destination_region) : null
  ) : null
  managed_edge_certificate_domains = distinct(compact([
    var.origin_tls_enabled && local.normalized_origin_tls_acm_certificate_arn == null ? local.cloudflare_public_hostname : null,
    var.argocd_public_enabled && local.normalized_argocd_origin_tls_acm_certificate_arn == null ? local.argocd_public_hostname : null,
    var.grafana_public_enabled && local.normalized_grafana_origin_tls_acm_certificate_arn == null ? local.grafana_public_hostname : null,
  ]))
  managed_edge_certificate_primary_domain = length(local.managed_edge_certificate_domains) > 0 ? local.managed_edge_certificate_domains[0] : null
  managed_edge_certificate_sans = length(local.managed_edge_certificate_domains) > 1 ? slice(
    local.managed_edge_certificate_domains,
    1,
    length(local.managed_edge_certificate_domains)
  ) : []
  managed_edge_certificate_arn = try(module.edge_certificate[0].certificate_arn, null)
  effective_origin_tls_acm_certificate_arn = local.normalized_origin_tls_acm_certificate_arn != null ? local.normalized_origin_tls_acm_certificate_arn : (
    var.origin_tls_enabled ? local.managed_edge_certificate_arn : null
  )
  effective_argocd_origin_tls_acm_certificate_arn = local.normalized_argocd_origin_tls_acm_certificate_arn != null ? local.normalized_argocd_origin_tls_acm_certificate_arn : (
    var.argocd_public_enabled ? local.managed_edge_certificate_arn : null
  )
  effective_grafana_origin_tls_acm_certificate_arn = local.normalized_grafana_origin_tls_acm_certificate_arn != null ? local.normalized_grafana_origin_tls_acm_certificate_arn : (
    var.grafana_public_enabled ? local.managed_edge_certificate_arn : null
  )
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster_auth" "this" {
  name = module.retail_app_eks.eks_cluster_id

  depends_on = [
    module.retail_app_eks
  ]
}

resource "null_resource" "aws_account_guardrail" {
  triggers = {
    current_account_id  = data.aws_caller_identity.current.account_id
    expected_account_id = var.expected_aws_account_id != null ? var.expected_aws_account_id : ""
  }

  lifecycle {
    precondition {
      condition = (
        var.expected_aws_account_id == null ? true : (
          trimspace(var.expected_aws_account_id) == "" ? true : data.aws_caller_identity.current.account_id == trimspace(var.expected_aws_account_id)
        )
      )
      error_message = "AWS account mismatch for ${var.environment_name}: expected ${var.expected_aws_account_id}, but the current caller identity is ${data.aws_caller_identity.current.account_id}. Re-run with the correct AWS credentials/profile."
    }
  }
}

resource "null_resource" "argocd_config" {
  count = var.app_deployment_mode == "argocd" ? 1 : 0

  triggers = {
    repo_url        = var.argocd_repo_url != null ? var.argocd_repo_url : ""
    target_revision = var.argocd_target_revision != null ? var.argocd_target_revision : ""
  }

  lifecycle {
    precondition {
      condition     = trimspace(var.argocd_repo_url != null ? var.argocd_repo_url : "") != ""
      error_message = "argocd_repo_url must be set when app_deployment_mode is \"argocd\"."
    }

    precondition {
      condition     = trimspace(var.argocd_target_revision != null ? var.argocd_target_revision : "") != ""
      error_message = "argocd_target_revision must be set when app_deployment_mode is \"argocd\"."
    }
  }
}

resource "null_resource" "cloudflare_config" {
  triggers = {
    zone_id               = var.cloudflare_zone_id != null ? var.cloudflare_zone_id : ""
    public_hostname       = local.cloudflare_public_hostname != null ? local.cloudflare_public_hostname : ""
    zero_trust_enabled    = tostring(var.cloudflare_zero_trust_enabled)
    cloudflare_account_id = var.cloudflare_account_id != null ? var.cloudflare_account_id : ""
  }

  lifecycle {
    precondition {
      condition     = trimspace(var.cloudflare_zone_id != null ? var.cloudflare_zone_id : "") != ""
      error_message = "cloudflare_zone_id must be set because Cloudflare DNS is always managed by this stack."
    }

    precondition {
      condition     = trimspace(local.cloudflare_public_hostname != null ? local.cloudflare_public_hostname : "") != ""
      error_message = "Set cloudflare_public_hostname or cloudflare_zone_name/cloudflare_record_name so Terraform can create the Cloudflare DNS record."
    }

    precondition {
      condition = (
        var.cloudflare_zero_trust_enabled ? trimspace(var.cloudflare_account_id != null ? var.cloudflare_account_id : "") != "" : true
      )
      error_message = "cloudflare_account_id must be set when cloudflare_zero_trust_enabled is true."
    }
  }
}

resource "null_resource" "origin_tls_config" {
  triggers = {
    enabled         = tostring(var.origin_tls_enabled)
    certificate_arn = local.effective_origin_tls_acm_certificate_arn != null ? local.effective_origin_tls_acm_certificate_arn : ""
    istio_enabled   = tostring(var.istio_enabled)
  }

  lifecycle {
    precondition {
      condition = (
        var.origin_tls_enabled ? trimspace(local.effective_origin_tls_acm_certificate_arn != null ? local.effective_origin_tls_acm_certificate_arn : "") != "" : true
      )
      error_message = "Enable managed certificate creation or set origin_tls_acm_certificate_arn when origin_tls_enabled is true."
    }

    precondition {
      condition     = !var.origin_tls_enabled || !var.istio_enabled
      error_message = "origin_tls_enabled currently supports the direct UI LoadBalancer path only. Disable Istio or add TLS separately to the Istio ingress gateway."
    }
  }
}

resource "null_resource" "argocd_public_config" {
  count = var.argocd_public_enabled ? 1 : 0

  triggers = {
    hostname        = local.argocd_public_hostname != null ? local.argocd_public_hostname : ""
    certificate_arn = local.effective_argocd_origin_tls_acm_certificate_arn != null ? local.effective_argocd_origin_tls_acm_certificate_arn : ""
    deployment_mode = var.app_deployment_mode
  }

  lifecycle {
    precondition {
      condition     = var.app_deployment_mode == "argocd"
      error_message = "argocd_public_enabled requires app_deployment_mode = \"argocd\"."
    }

    precondition {
      condition     = trimspace(local.argocd_public_hostname != null ? local.argocd_public_hostname : "") != ""
      error_message = "Set argocd_public_hostname or argocd_cloudflare_record_name/cloudflare_zone_name so Terraform can create the Argo CD DNS record."
    }

    precondition {
      condition     = trimspace(local.effective_argocd_origin_tls_acm_certificate_arn != null ? local.effective_argocd_origin_tls_acm_certificate_arn : "") != ""
      error_message = "Enable managed certificate creation or set argocd_origin_tls_acm_certificate_arn when argocd_public_enabled is true."
    }
  }
}

resource "null_resource" "grafana_public_config" {
  count = var.grafana_public_enabled ? 1 : 0

  triggers = {
    hostname        = local.grafana_public_hostname != null ? local.grafana_public_hostname : ""
    certificate_arn = local.effective_grafana_origin_tls_acm_certificate_arn != null ? local.effective_grafana_origin_tls_acm_certificate_arn : ""
    enabled         = tostring(var.observability_enabled)
  }

  lifecycle {
    precondition {
      condition     = var.observability_enabled
      error_message = "grafana_public_enabled requires observability_enabled = true."
    }

    precondition {
      condition     = trimspace(local.grafana_public_hostname != null ? local.grafana_public_hostname : "") != ""
      error_message = "Set grafana_public_hostname or grafana_cloudflare_record_name/cloudflare_zone_name so Terraform can create the Grafana DNS record."
    }

    precondition {
      condition     = trimspace(local.effective_grafana_origin_tls_acm_certificate_arn != null ? local.effective_grafana_origin_tls_acm_certificate_arn : "") != ""
      error_message = "Enable managed certificate creation or set grafana_origin_tls_acm_certificate_arn when grafana_public_enabled is true."
    }
  }
}

resource "null_resource" "aws_backup_config" {
  triggers = {
    enabled            = tostring(var.aws_backup_enabled)
    source_region      = var.region
    destination_region = local.normalized_aws_backup_destination_region != null ? local.normalized_aws_backup_destination_region : ""
  }

  lifecycle {
    precondition {
      condition = (
        !var.aws_backup_enabled || local.normalized_aws_backup_destination_region != null
      )
      error_message = "aws_backup_destination_region must be set when aws_backup_enabled is true."
    }

    precondition {
      condition = (
        !var.aws_backup_enabled || local.normalized_aws_backup_destination_region != trimspace(var.region)
      )
      error_message = "aws_backup_destination_region must be different from region when aws_backup_enabled is true."
    }
  }
}

module "tags" {
  source = "./modules/tags"

  environment_name = var.environment_name
}

module "edge_certificate" {
  count  = length(local.managed_edge_certificate_domains) > 0 ? 1 : 0
  source = "./modules/acm_certificate"

  domain_name               = local.managed_edge_certificate_primary_domain
  subject_alternative_names = local.managed_edge_certificate_sans
  zone_id                   = var.cloudflare_zone_id != null ? var.cloudflare_zone_id : ""
  tags                      = local.common_tags
}

module "vpc" {
  source = "./modules/vpc"

  environment_name = var.environment_name
  vpc_cidr         = var.vpc_cidr

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.environment_name}" = "shared"
    "kubernetes.io/role/elb"                        = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.environment_name}" = "shared"
    "kubernetes.io/role/internal-elb"               = 1
  }

  tags = local.common_tags
}

module "component_security_groups" {
  source = "./modules/component_security_groups"

  environment_name = var.environment_name
  vpc_id           = module.vpc.inner.vpc_id
  vpc_cidr         = module.vpc.inner.vpc_cidr_block
  tags             = local.common_tags
}

module "managed_ecr" {
  count  = var.managed_ecr_enabled ? 1 : 0
  source = "./modules/ecr"

  environment_name = var.environment_name
  force_delete     = var.managed_ecr_force_delete
  tags             = local.common_tags
}

module "retail_app_eks" {
  source = "./modules/eks"

  environment_name                 = var.environment_name
  cluster_version                  = var.cluster_version
  vpc_id                           = module.vpc.inner.vpc_id
  vpc_cidr                         = module.vpc.inner.vpc_cidr_block
  subnet_ids                       = module.vpc.inner.private_subnets
  opentelemetry_enabled            = var.opentelemetry_enabled
  istio_enabled                    = var.istio_enabled
  eks_cluster_admin_principal_arns = var.eks_cluster_admin_principal_arns
  tags                             = local.common_tags
}

module "dependencies" {
  source = "./modules/dependencies"

  environment_name = var.environment_name
  tags             = local.common_tags

  vpc_id     = module.vpc.inner.vpc_id
  subnet_ids = module.vpc.inner.private_subnets

  catalog_security_group_id  = local.security_groups_active ? module.component_security_groups.catalog_id : module.retail_app_eks.node_security_group_id
  orders_security_group_id   = local.security_groups_active ? module.component_security_groups.orders_id : module.retail_app_eks.node_security_group_id
  checkout_security_group_id = local.security_groups_active ? module.component_security_groups.checkout_id : module.retail_app_eks.node_security_group_id
}

module "aws_backup" {
  count  = var.aws_backup_enabled ? 1 : 0
  source = "./modules/aws_backup"

  providers = {
    aws             = aws
    aws.destination = aws.backup_replica
  }

  environment_name   = var.environment_name
  destination_region = local.normalized_aws_backup_destination_region != null ? local.normalized_aws_backup_destination_region : ""
  source_resource_arns = [
    module.dependencies.catalog_db_arn,
    module.dependencies.orders_db_arn,
    module.dependencies.carts_dynamodb_table_arn,
  ]
  schedule                  = var.aws_backup_schedule
  start_window_minutes      = var.aws_backup_start_window_minutes
  completion_window_minutes = var.aws_backup_completion_window_minutes
  delete_after_days         = var.aws_backup_delete_after_days
  copy_delete_after_days    = var.aws_backup_copy_delete_after_days
  tags                      = local.common_tags

  depends_on = [
    null_resource.aws_backup_config,
    module.dependencies,
  ]
}

module "k8s_workloads" {
  source = "./modules/k8s_workloads"

  providers = {
    aws        = aws
    helm       = helm
    kubectl    = kubectl
    kubernetes = kubernetes
  }

  environment_name                       = var.environment_name
  istio_enabled                          = var.istio_enabled
  opentelemetry_enabled                  = var.opentelemetry_enabled
  observability_enabled                  = var.observability_enabled
  observability_namespace                = var.observability_namespace
  grafana_admin_password                 = var.grafana_admin_password
  alert_email_smarthost                  = var.alert_email_smarthost
  alert_email_username                   = var.alert_email_username
  alert_email_password                   = var.alert_email_password
  alert_email_recipients                 = local.effective_alert_email_recipients
  grafana_public_enabled                 = var.grafana_public_enabled
  grafana_public_hostname                = local.grafana_public_hostname
  grafana_origin_tls_acm_certificate_arn = local.effective_grafana_origin_tls_acm_certificate_arn
  tags                                   = local.common_tags
  app_deployment_mode                    = var.app_deployment_mode
  argocd_repo_url                        = var.argocd_repo_url
  argocd_target_revision                 = var.argocd_target_revision
  argocd_namespace                       = var.argocd_namespace
  argocd_public_enabled                  = var.argocd_public_enabled
  argocd_public_hostname                 = local.argocd_public_hostname
  argocd_origin_tls_acm_certificate_arn  = local.effective_argocd_origin_tls_acm_certificate_arn
  origin_tls_enabled                     = var.origin_tls_enabled
  origin_tls_acm_certificate_arn         = local.effective_origin_tls_acm_certificate_arn
  container_image_overrides              = local.effective_container_image_overrides
  security_group_ids = {
    catalog  = module.component_security_groups.catalog_id
    orders   = module.component_security_groups.orders_id
    checkout = module.component_security_groups.checkout_id
  }
  cluster = {
    name                       = module.retail_app_eks.eks_cluster_id
    endpoint                   = module.retail_app_eks.cluster_endpoint
    certificate_authority_data = module.retail_app_eks.cluster_certificate_authority_data
    oidc_issuer_url            = module.retail_app_eks.eks_oidc_issuer_url
    cluster_blocker_id         = module.retail_app_eks.cluster_blocker_id
    addons_blocker_id          = module.retail_app_eks.addons_blocker_id
    adot_namespace             = module.retail_app_eks.adot_namespace
  }
  dependencies = {
    catalog_db_endpoint                   = module.dependencies.catalog_db_endpoint
    catalog_db_port                       = module.dependencies.catalog_db_port
    catalog_db_master_username            = module.dependencies.catalog_db_master_username
    catalog_db_master_password            = module.dependencies.catalog_db_master_password
    carts_dynamodb_table_name             = module.dependencies.carts_dynamodb_table_name
    carts_dynamodb_policy_arn             = module.dependencies.carts_dynamodb_policy_arn
    checkout_elasticache_primary_endpoint = module.dependencies.checkout_elasticache_primary_endpoint
    checkout_elasticache_port             = module.dependencies.checkout_elasticache_port
    orders_db_endpoint                    = module.dependencies.orders_db_endpoint
    orders_db_port                        = module.dependencies.orders_db_port
    orders_db_database_name               = module.dependencies.orders_db_database_name
    orders_db_master_username             = module.dependencies.orders_db_master_username
    orders_db_master_password             = module.dependencies.orders_db_master_password
    mq_broker_endpoint                    = module.dependencies.mq_broker_endpoint
    mq_user                               = module.dependencies.mq_user
    mq_password                           = module.dependencies.mq_password
  }

  depends_on = [
    null_resource.argocd_config,
    null_resource.grafana_public_config,
    null_resource.origin_tls_config,
    module.dependencies,
    module.retail_app_eks
  ]
}

module "cloudflare_edge" {
  source = "./modules/cloudflare_edge"

  account_id         = var.cloudflare_account_id
  zero_trust_enabled = var.cloudflare_zero_trust_enabled
  zone_id            = var.cloudflare_zone_id != null ? var.cloudflare_zone_id : ""
  public_hostname    = local.cloudflare_public_hostname != null ? local.cloudflare_public_hostname : ""
  origin_hostname    = module.k8s_workloads.retail_app_origin_hostname
  proxied            = var.cloudflare_proxied

  access_application_name = coalesce(
    var.cloudflare_access_application_name,
    "${var.environment_name}-retail-store"
  )
  access_policy_name = coalesce(
    var.cloudflare_access_policy_name,
    "${var.environment_name}-retail-store-allow"
  )
  access_allowed_email_domains         = var.cloudflare_access_allowed_email_domains
  access_allowed_emails                = var.cloudflare_access_allowed_emails
  access_allowed_identity_provider_ids = var.cloudflare_access_allowed_identity_provider_ids
  access_auto_redirect_to_identity     = var.cloudflare_access_auto_redirect_to_identity
  access_session_duration              = var.cloudflare_access_session_duration
  access_app_launcher_visible          = var.cloudflare_access_app_launcher_visible

  manage_zero_trust_organization        = var.cloudflare_zero_trust_organization_enabled
  zero_trust_organization_name          = var.cloudflare_zero_trust_organization_name
  zero_trust_auth_domain                = var.cloudflare_zero_trust_auth_domain
  zero_trust_is_ui_read_only            = var.cloudflare_zero_trust_is_ui_read_only
  zero_trust_session_duration           = var.cloudflare_zero_trust_session_duration
  zero_trust_ui_read_only_toggle_reason = var.cloudflare_zero_trust_ui_read_only_toggle_reason

  depends_on = [
    null_resource.cloudflare_config
  ]
}

module "cloudflare_argocd_edge" {
  count  = var.argocd_public_enabled ? 1 : 0
  source = "./modules/cloudflare_edge"

  account_id         = var.cloudflare_account_id
  zero_trust_enabled = var.cloudflare_zero_trust_enabled
  zone_id            = var.cloudflare_zone_id != null ? var.cloudflare_zone_id : ""
  public_hostname    = local.argocd_public_hostname != null ? local.argocd_public_hostname : ""
  origin_hostname    = module.k8s_workloads.argocd_origin_hostname
  proxied            = var.cloudflare_proxied

  access_application_name              = "${var.environment_name}-argocd"
  access_policy_name                   = "${var.environment_name}-argocd-allow"
  access_allowed_email_domains         = var.cloudflare_access_allowed_email_domains
  access_allowed_emails                = var.cloudflare_access_allowed_emails
  access_allowed_identity_provider_ids = var.cloudflare_access_allowed_identity_provider_ids
  access_auto_redirect_to_identity     = var.cloudflare_access_auto_redirect_to_identity
  access_session_duration              = var.cloudflare_access_session_duration
  access_app_launcher_visible          = var.cloudflare_access_app_launcher_visible

  manage_zero_trust_organization        = false
  zero_trust_organization_name          = null
  zero_trust_auth_domain                = null
  zero_trust_is_ui_read_only            = var.cloudflare_zero_trust_is_ui_read_only
  zero_trust_session_duration           = var.cloudflare_zero_trust_session_duration
  zero_trust_ui_read_only_toggle_reason = var.cloudflare_zero_trust_ui_read_only_toggle_reason

  depends_on = [
    null_resource.cloudflare_config,
    null_resource.argocd_public_config
  ]
}

module "cloudflare_grafana_edge" {
  count  = var.grafana_public_enabled ? 1 : 0
  source = "./modules/cloudflare_edge"

  account_id         = var.cloudflare_account_id
  zero_trust_enabled = var.cloudflare_zero_trust_enabled
  zone_id            = var.cloudflare_zone_id != null ? var.cloudflare_zone_id : ""
  public_hostname    = local.grafana_public_hostname != null ? local.grafana_public_hostname : ""
  origin_hostname    = module.k8s_workloads.grafana_origin_hostname
  proxied            = var.cloudflare_proxied

  access_application_name              = "${var.environment_name}-grafana"
  access_policy_name                   = "${var.environment_name}-grafana-allow"
  access_allowed_email_domains         = var.cloudflare_access_allowed_email_domains
  access_allowed_emails                = var.cloudflare_access_allowed_emails
  access_allowed_identity_provider_ids = var.cloudflare_access_allowed_identity_provider_ids
  access_auto_redirect_to_identity     = var.cloudflare_access_auto_redirect_to_identity
  access_session_duration              = var.cloudflare_access_session_duration
  access_app_launcher_visible          = var.cloudflare_access_app_launcher_visible

  manage_zero_trust_organization        = false
  zero_trust_organization_name          = null
  zero_trust_auth_domain                = null
  zero_trust_is_ui_read_only            = var.cloudflare_zero_trust_is_ui_read_only
  zero_trust_session_duration           = var.cloudflare_zero_trust_session_duration
  zero_trust_ui_read_only_toggle_reason = var.cloudflare_zero_trust_ui_read_only_toggle_reason

  depends_on = [
    null_resource.cloudflare_config,
    null_resource.grafana_public_config
  ]
}
