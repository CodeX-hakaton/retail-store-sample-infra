output "configure_kubectl" {
  description = "Command to update kubeconfig for this cluster."
  value       = module.retail_app_eks.configure_kubectl
}

output "retail_app_url" {
  description = "URL to access the retail store application once the LoadBalancer is ready."
  value       = module.k8s_workloads.retail_app_url
}

output "retail_app_origin_hostname" {
  description = "Origin hostname behind the public application entrypoint."
  value       = module.k8s_workloads.retail_app_origin_hostname
}

output "cloudflare_application_hostname" {
  description = "Cloudflare-managed hostname for the retail application."
  value       = module.cloudflare_edge.hostname
}

output "cloudflare_application_url" {
  description = "Cloudflare URL for the retail application."
  value       = "https://${module.cloudflare_edge.hostname}"
}

output "managed_edge_certificate_arn" {
  description = "ACM certificate ARN created by Terraform for public edge hostnames when no explicit certificate override is provided."
  value       = try(module.edge_certificate[0].certificate_arn, null)
}

output "managed_edge_certificate_domains" {
  description = "Hostnames covered by the Terraform-managed ACM certificate."
  value       = try(module.edge_certificate[0].domain_names, [])
}

output "argocd_origin_hostname" {
  description = "Origin hostname behind the public Argo CD endpoint."
  value       = var.argocd_public_enabled ? module.k8s_workloads.argocd_origin_hostname : null
}

output "argocd_origin_url" {
  description = "Direct URL for the Argo CD origin ingress."
  value       = var.argocd_public_enabled ? module.k8s_workloads.argocd_url : null
}

output "cloudflare_argocd_hostname" {
  description = "Cloudflare-managed hostname for the Argo CD endpoint."
  value       = var.argocd_public_enabled ? module.cloudflare_argocd_edge[0].hostname : null
}

output "cloudflare_argocd_url" {
  description = "Cloudflare URL for the Argo CD endpoint."
  value       = var.argocd_public_enabled ? "https://${module.cloudflare_argocd_edge[0].hostname}" : null
}

output "cloudflare_argocd_access_application_id" {
  description = "Cloudflare Zero Trust Access application ID for Argo CD when exposed and Zero Trust is enabled."
  value       = var.argocd_public_enabled && var.cloudflare_zero_trust_enabled ? module.cloudflare_argocd_edge[0].access_application_id : null
}

output "cloudflare_access_application_id" {
  description = "Cloudflare Zero Trust Access application ID when Zero Trust is enabled."
  value       = var.cloudflare_zero_trust_enabled ? module.cloudflare_edge.access_application_id : null
}

output "catalog_db_endpoint" {
  description = "Writer endpoint for the catalog database."
  value       = module.dependencies.catalog_db_endpoint
}

output "orders_db_endpoint" {
  description = "Writer endpoint for the orders database."
  value       = module.dependencies.orders_db_endpoint
}

output "checkout_redis_endpoint" {
  description = "Primary endpoint for the checkout Redis cluster."
  value       = module.dependencies.checkout_elasticache_primary_endpoint
}

output "carts_dynamodb_table_name" {
  description = "DynamoDB table name used by the carts service."
  value       = module.dependencies.carts_dynamodb_table_name
}

output "mq_broker_endpoint" {
  description = "Amazon MQ endpoint used by the orders service."
  value       = module.dependencies.mq_broker_endpoint
}

output "aws_backup_plan_id" {
  description = "AWS Backup plan ID when cross-region backups are enabled."
  value       = var.aws_backup_enabled ? module.aws_backup[0].plan_id : null
}

output "aws_backup_source_vault_arn" {
  description = "AWS Backup vault ARN in the primary region when backups are enabled."
  value       = var.aws_backup_enabled ? module.aws_backup[0].source_vault_arn : null
}

output "aws_backup_destination_vault_arn" {
  description = "AWS Backup vault ARN in the disaster recovery region when backups are enabled."
  value       = var.aws_backup_enabled ? module.aws_backup[0].destination_vault_arn : null
}

output "private_subnet_ids" {
  description = "Private subnet IDs for the current region."
  value       = module.vpc.inner.private_subnets
}

output "catalog_security_group_id" {
  description = "Security group ID for the catalog component."
  value       = module.component_security_groups.catalog_id
}

output "orders_security_group_id" {
  description = "Security group ID for the orders component."
  value       = module.component_security_groups.orders_id
}

output "managed_ecr_registry" {
  description = "Private ECR registry used by the stack when managed_ecr_enabled is true."
  value       = var.managed_ecr_enabled ? local.managed_ecr_registry : null
}

output "managed_ecr_repository_names" {
  description = "Managed ECR repository names by service."
  value       = var.managed_ecr_enabled ? module.managed_ecr[0].repository_names : null
}

output "managed_ecr_repository_urls" {
  description = "Managed ECR repository URLs by service."
  value       = var.managed_ecr_enabled ? module.managed_ecr[0].repository_urls : null
}
