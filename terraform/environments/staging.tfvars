environment_name        = "codex-staging"
expected_aws_account_id = "010829528421"
region                  = "eu-north-1"
cluster_version         = "1.33"
vpc_cidr                = "10.1.0.0/16"

istio_enabled         = false
opentelemetry_enabled = false
observability_enabled = true

additional_tags = {
  project     = "codex"
  environment = "staging"
  managed_by  = "terraform"
}

managed_ecr_enabled            = true
app_deployment_mode            = "argocd"
argocd_target_revision         = "staging"
origin_tls_enabled             = true
argocd_public_enabled          = true
grafana_public_enabled         = true
argocd_cloudflare_record_name  = "argocd-staging"
grafana_cloudflare_record_name = "grafana-staging"
cloudflare_zero_trust_enabled  = true

cloudflare_zone_name   = "codex-devops.pp.ua"
cloudflare_record_name = "staging"


container_image_overrides = {
  default_tag = "0.0.92"
}
