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
