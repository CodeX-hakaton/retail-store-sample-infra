environment_name        = "codex-production"
expected_aws_account_id = "382764426605"
region                  = "eu-north-1"
cluster_version         = "1.33"
vpc_cidr                = "10.2.0.0/16"

istio_enabled         = false
opentelemetry_enabled = false
observability_enabled = true

additional_tags = {
  project     = "codex"
  environment = "production"
  managed_by  = "terraform"
}

managed_ecr_enabled            = true
aws_backup_enabled             = true
aws_backup_destination_region  = "eu-central-1"
app_deployment_mode            = "argocd"
argocd_target_revision         = "production"
origin_tls_enabled             = true
argocd_public_enabled          = true
grafana_public_enabled         = true
argocd_cloudflare_record_name  = "argocd"
grafana_cloudflare_record_name = "grafana"
cloudflare_zero_trust_enabled  = false

cloudflare_zone_name   = "codex-devops.pp.ua"
cloudflare_record_name = "@"

container_image_overrides = {
  default_tag = "0.0.89"
}
