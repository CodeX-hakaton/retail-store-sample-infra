locals {
  image_catalog_metadata              = jsondecode(file("${path.module}/modules/images/generated.tf.json"))
  default_image_tag                   = coalesce(try(var.container_image_overrides.default_tag, null), local.image_catalog_metadata.locals.published_tag)
  security_groups_active              = !var.opentelemetry_enabled
  common_tags                         = merge(module.tags.result, var.additional_tags)
  managed_ecr_registry                = var.managed_ecr_enabled ? "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com" : null
  managed_ecr_image_overrides         = var.managed_ecr_enabled ? { for service, repository_url in module.managed_ecr[0].repository_urls : service => "${repository_url}:${local.default_image_tag}" } : {}
  effective_container_image_overrides = merge(local.managed_ecr_image_overrides, var.container_image_overrides)
  cloudflare_public_hostname = var.cloudflare_public_hostname != null ? var.cloudflare_public_hostname : (
    var.cloudflare_zone_name == null ? null : (
      contains(["", "@"], trimspace(var.cloudflare_record_name)) ? var.cloudflare_zone_name : "${trimspace(var.cloudflare_record_name)}.${var.cloudflare_zone_name}"
    )
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
    expected_account_id = coalesce(var.expected_aws_account_id, "")
  }

  lifecycle {
    precondition {
      condition     = var.expected_aws_account_id == null || trimspace(var.expected_aws_account_id) == "" || data.aws_caller_identity.current.account_id == trimspace(var.expected_aws_account_id)
      error_message = "AWS account mismatch for ${var.environment_name}: expected ${var.expected_aws_account_id}, but the current caller identity is ${data.aws_caller_identity.current.account_id}. Re-run with the correct AWS credentials/profile."
    }
  }
}

resource "null_resource" "argocd_config" {
  count = var.app_deployment_mode == "argocd" ? 1 : 0

  triggers = {
    repo_url        = coalesce(var.argocd_repo_url, "")
    target_revision = coalesce(var.argocd_target_revision, "")
  }

  lifecycle {
    precondition {
      condition     = var.argocd_repo_url != null && trimspace(var.argocd_repo_url) != ""
      error_message = "argocd_repo_url must be set when app_deployment_mode is \"argocd\"."
    }

    precondition {
      condition     = var.argocd_target_revision != null && trimspace(var.argocd_target_revision) != ""
      error_message = "argocd_target_revision must be set when app_deployment_mode is \"argocd\"."
    }
  }
}

resource "null_resource" "cloudflare_config" {
  triggers = {
    zone_id               = coalesce(var.cloudflare_zone_id, "")
    public_hostname       = coalesce(local.cloudflare_public_hostname, "")
    zero_trust_enabled    = tostring(var.cloudflare_zero_trust_enabled)
    cloudflare_account_id = coalesce(var.cloudflare_account_id, "")
  }

  lifecycle {
    precondition {
      condition     = var.cloudflare_zone_id != null && trimspace(var.cloudflare_zone_id) != ""
      error_message = "cloudflare_zone_id must be set because Cloudflare DNS is always managed by this stack."
    }

    precondition {
      condition     = local.cloudflare_public_hostname != null && trimspace(local.cloudflare_public_hostname) != ""
      error_message = "Set cloudflare_public_hostname or cloudflare_zone_name/cloudflare_record_name so Terraform can create the Cloudflare DNS record."
    }

    precondition {
      condition     = !var.cloudflare_zero_trust_enabled || (var.cloudflare_account_id != null && trimspace(var.cloudflare_account_id) != "")
      error_message = "cloudflare_account_id must be set when cloudflare_zero_trust_enabled is true."
    }
  }
}

module "tags" {
  source = "./modules/tags"

  environment_name = var.environment_name
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

module "k8s_workloads" {
  source = "./modules/k8s_workloads"

  providers = {
    aws        = aws
    helm       = helm
    kubectl    = kubectl
    kubernetes = kubernetes
  }

  environment_name          = var.environment_name
  istio_enabled             = var.istio_enabled
  opentelemetry_enabled     = var.opentelemetry_enabled
  tags                      = local.common_tags
  app_deployment_mode       = var.app_deployment_mode
  argocd_repo_url           = var.argocd_repo_url
  argocd_target_revision    = var.argocd_target_revision
  argocd_namespace          = var.argocd_namespace
  container_image_overrides = local.effective_container_image_overrides
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
    module.dependencies,
    module.retail_app_eks
  ]
}

module "cloudflare_edge" {
  source = "./modules/cloudflare_edge"

  account_id         = var.cloudflare_account_id
  zero_trust_enabled = var.cloudflare_zero_trust_enabled
  zone_id            = coalesce(var.cloudflare_zone_id, "")
  public_hostname    = coalesce(local.cloudflare_public_hostname, "")
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
