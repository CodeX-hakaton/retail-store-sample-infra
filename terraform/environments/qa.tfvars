environment_name        = "codex-qa"
expected_aws_account_id = "010829528421"
region                  = "eu-north-1"
cluster_version         = "1.33"
vpc_cidr                = "10.0.0.0/16"

istio_enabled         = false
opentelemetry_enabled = false

additional_tags = {
  project     = "codex"
  environment = "qa"
  managed_by  = "terraform"
}

managed_ecr_enabled           = true
app_deployment_mode           = "argocd"
argocd_target_revision        = "qa"
cloudflare_zero_trust_enabled = true

cloudflare_zone_name   = "codex-devops.pp.ua"
cloudflare_record_name = "qa"

cloudflare_access_allowed_emails = [
  "oleksijvun@gmail.com",
  "mykola.biloshapka@lnu.edu.ua",
  "artemzaporozec97@gmail.com"
]


container_image_overrides = {
  default_tag = "0.0.89"
}
