environment_name = "codex-production"
region           = "eu-north-1"
cluster_version  = "1.33"
vpc_cidr         = "10.2.0.0/16"

istio_enabled         = false
opentelemetry_enabled = false

additional_tags = {
  project     = "codex"
  environment = "production"
  managed_by  = "terraform"
}

managed_ecr_enabled           = false
app_deployment_mode           = "argocd"
argocd_target_revision        = "production"
cloudflare_zero_trust_enabled = false

cloudflare_zone_name   = "codex-devops.pp.ua"
cloudflare_record_name = "@"

cloudflare_access_allowed_emails = [
  "oleksijvun@gmail.com",
  "mykola.biloshapka@lnu.edu.ua",
  "artemzaporozec97@gmail.com"
]
