environment_name = "retail-store-qa"
region           = "eu-north-1"
cluster_version  = "1.33"
vpc_cidr         = "10.0.0.0/16"

istio_enabled         = false
opentelemetry_enabled = false

# Prevent accidental cross-account applies.
# expected_aws_account_id = "123456789012"

# Optional stable IAM principals that should keep cluster-admin access.
# If left empty, Terraform grants access to the IAM principal running apply.
# eks_cluster_admin_principal_arns = [
#   "arn:aws:iam::123456789012:role/terraform-production",
# ]

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

# Optional AWS Backup protection for the durable data behind the stateless apps.
# This currently covers the Aurora clusters for catalog and orders plus the
# carts DynamoDB table, then copies recovery points into a second AWS region.
# aws_backup_enabled = true
# aws_backup_destination_region = "eu-central-1"
# aws_backup_schedule = "cron(0 3 * * ? *)"
# aws_backup_delete_after_days = 35
# aws_backup_copy_delete_after_days = 90

# Optional GitOps deployment via Argo CD.
app_deployment_mode = "terraform"
# argocd_repo_url = "https://github.com/CodeX-hakaton/retail-store-sample-infra.git"
# argocd_target_revision = "qa"
# argocd_public_enabled = true
# argocd_cloudflare_record_name = "argocd-qa"
# argocd_origin_tls_acm_certificate_arn = "arn:aws:acm:eu-north-1:123456789012:certificate/11111111-1111-1111-1111-111111111111" # optional override; Terraform creates one by default

# Cloudflare DNS is always managed by Terraform for the public app hostname.
cloudflare_zero_trust_enabled = false
cloudflare_zone_name          = "codex-devops.pp.ua"
cloudflare_record_name        = "@"

# Optional origin TLS at the AWS load balancer. Terraform creates and validates
# an ACM certificate through Cloudflare automatically unless you set an override ARN.
# origin_tls_enabled             = true
# origin_tls_acm_certificate_arn = "arn:aws:acm:eu-north-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"

# Set these via `.env`, private tfvars, or CI/CD variable injection.
# cloudflare_access_allowed_emails = ["user1@example.com", "user2@example.com"]
# cloudflare_access_allowed_email_domains = ["example.com"]
# cloudflare_access_allowed_identity_provider_ids = ["1234567890abcdef"]
# cloudflare_account_id = "..."
# cloudflare_zone_id    = "..."

# cloudflare_public_hostname = "shop.codex-devops.pp.ua"
# cloudflare_zero_trust_organization_enabled = true
# cloudflare_zero_trust_organization_name    = "example"
# cloudflare_zero_trust_auth_domain          = "example.cloudflareaccess.com"
