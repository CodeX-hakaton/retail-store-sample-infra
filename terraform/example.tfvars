environment_name = "retail-store-qa"
region           = "eu-north-1"
cluster_version  = "1.33"
vpc_cidr         = "10.0.0.0/16"

istio_enabled         = false
opentelemetry_enabled = false

additional_tags = {
  project     = "codex"
  environment = "qa"
}

# Optional image overrides. Leave empty to use the published sample images.
container_image_overrides = {
  # default_repository = "123456789012.dkr.ecr.eu-north-1.amazonaws.com"
  # default_tag        = "latest"
}

# Optional private ECR repositories managed by Terraform.
# When enabled, Terraform creates one repository per service using the
# environment name as a prefix and deploys the workloads from those URLs.
managed_ecr_enabled = false
# managed_ecr_force_delete = true

# Optional GitOps deployment via Argo CD.
app_deployment_mode = "terraform"
# argocd_repo_url = "https://github.com/CodeX-hakaton/retail-store-sample-infra.git"
# argocd_target_revision = "qa"

# Cloudflare DNS is always managed by Terraform for the public app hostname.
cloudflare_zero_trust_enabled = false
cloudflare_zone_name          = "codex-devops.pp.ua"
cloudflare_record_name        = "@"

cloudflare_access_allowed_emails = [
  "oleksijvun@gmail.com",
  "mykola.biloshapka@lnu.edu.ua",
  "artemzaporozec97@gmail.com"
]

# Set these via private tfvars or CI/CD variable injection.
# cloudflare_account_id = "..."
# cloudflare_zone_id    = "..."

# cloudflare_public_hostname = "shop.codex-devops.pp.ua"
# cloudflare_access_allowed_email_domains = ["example.com"]
# cloudflare_access_allowed_identity_provider_ids = ["1234567890abcdef"]
# cloudflare_zero_trust_organization_enabled = true
# cloudflare_zero_trust_organization_name    = "example"
# cloudflare_zero_trust_auth_domain          = "example.cloudflareaccess.com"
