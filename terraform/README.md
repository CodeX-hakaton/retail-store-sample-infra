# Retail Store Sample Infra

This directory is the root Terraform stack for the retail store sample on AWS.

It provisions:

- a VPC with public and private subnets
- an EKS cluster with managed node groups
- managed backing services for the application
- either direct Helm-based workloads or Argo CD Applications from the vendored charts in this repo
- optional Istio ingress
- optional OpenTelemetry support
- Cloudflare DNS in front of the public app
- optional Cloudflare Zero Trust Access on top of that hostname

## Layout

```text
.
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── example.tfvars
├── environments/
│   ├── qa.tfvars
│   ├── staging.tfvars
│   └── production.tfvars
├── charts/
└── modules/
```

## What Gets Created

`terraform apply -var-file=environments/<env>.tfvars` creates:

- AWS networking
- an EKS cluster
- Aurora for `catalog`
- Aurora for `orders`
- DynamoDB for `carts`
- ElastiCache Redis for `checkout`
- Amazon MQ for `orders`
- IAM roles and security-group wiring for the workloads
- Kubernetes namespaces for `catalog`, `carts`, `checkout`, `orders`, and `ui`

If `app_deployment_mode = "terraform"`, Terraform also creates:

- Helm releases for `catalog`, `carts`, `checkout`, `orders`, and `ui`

If `app_deployment_mode = "argocd"`, Terraform also creates:

- an Argo CD installation in the `argocd` namespace
- one Argo CD `Application` per service
- Kubernetes Secrets for the generated database and RabbitMQ credentials used by the charts

If `managed_ecr_enabled = true`, Terraform also creates:

- private ECR repositories for `catalog`, `cart`, `checkout`, `orders`, and `ui`
- workload image URLs that point at those private repositories

Terraform also creates:

- a proxied Cloudflare DNS record for the public app hostname

If `cloudflare_zero_trust_enabled = true`, Terraform also creates:

- a Cloudflare Zero Trust Access application
- a Cloudflare Zero Trust allow policy based on email domains and/or email addresses

## Prerequisites

Install:

- Terraform
- AWS CLI
- `kubectl`

Have working AWS credentials for the target account and region.

Bootstrap the Terraform backend before first use:

- create an S3 bucket for remote state
- enable bucket versioning, encryption, and public access block
- create a DynamoDB table with a `LockID` string hash key for state locking

This repo includes [bootstrap/create-tf-backend.sh](/Users/admin/personal/hakathon/retail-store-sample-infra/terraform/bootstrap/create-tf-backend.sh) for that purpose.
If you also want CircleCI OIDC and CI roles, use [bootstrap/create-aws-bootstrap.sh](/Users/admin/personal/hakathon/retail-store-sample-infra/terraform/bootstrap/create-aws-bootstrap.sh).

Because Cloudflare DNS is always managed by this stack, also have:

- a Cloudflare API token exported as `CLOUDFLARE_API_TOKEN`
- the Cloudflare zone ID

If you enable Zero Trust for an environment, also provide:

- the Cloudflare account ID

## Configuration Model

Use committed environment tfvars only for non-sensitive configuration.

Examples of values that are safe to commit:

- `environment_name`
- `region`
- `vpc_cidr`
- `managed_ecr_enabled`
- `cloudflare_zone_name`
- `cloudflare_record_name`
- `cloudflare_zero_trust_enabled`
- `cloudflare_access_allowed_emails`
- `cloudflare_access_allowed_email_domains`

Inject runtime-only values instead of committing them.

Runtime-only values for Cloudflare:

- `CLOUDFLARE_API_TOKEN`
- `TF_VAR_cloudflare_zone_id`

Runtime-only value for Cloudflare Zero Trust:

- `TF_VAR_cloudflare_account_id`

Default Argo CD repo URL:

- `https://github.com/CodeX-hakaton/retail-store-sample-infra.git`

Optional runtime override for Argo CD mode:

- `TF_VAR_argocd_repo_url`

`cloudflare_account_id` and `cloudflare_zone_id` are identifiers rather than secrets, but if you do not want them in git, inject them the same way as secrets.

## Environment Files

The committed environment files are:

- [environments/qa.tfvars](/Users/admin/personal/hakathon/retail-store-sample-infra/terraform/environments/qa.tfvars)
- [environments/staging.tfvars](/Users/admin/personal/hakathon/retail-store-sample-infra/terraform/environments/staging.tfvars)
- [environments/production.tfvars](/Users/admin/personal/hakathon/retail-store-sample-infra/terraform/environments/production.tfvars)

Current Cloudflare-related values there:

- `qa`: `cloudflare_record_name = "qa"`, `cloudflare_zero_trust_enabled = true`
- `staging`: `cloudflare_record_name = "staging"`, `cloudflare_zero_trust_enabled = true`
- `production`: `cloudflare_record_name = "@"`, `cloudflare_zero_trust_enabled = false`
- all three use `cloudflare_zone_name = "codex-devops.pp.ua"`
- all three keep the same committed Zero Trust allow-list ready if you switch Access on

Current Argo CD-related values there:

- `qa`: `app_deployment_mode = "argocd"`, `argocd_target_revision = "qa"`
- `staging`: `app_deployment_mode = "argocd"`, `argocd_target_revision = "staging"`
- `production`: `app_deployment_mode = "argocd"`, `argocd_target_revision = "production"`

Argo CD will therefore track the matching branch for each environment. A merge into `qa`, `staging`, or `production` becomes the desired state for that environment after Argo CD detects the new commit.

Hostname behavior:

- `cloudflare_public_hostname` wins if set
- otherwise Terraform builds the hostname from `cloudflare_record_name` and `cloudflare_zone_name`
- `cloudflare_record_name = "@"` means the zone apex, so the hostname becomes `codex-devops.pp.ua`
- `cloudflare_record_name = "shop"` would produce `shop.codex-devops.pp.ua`

## Cloudflare Access Model

When `cloudflare_zero_trust_enabled = true`, the Cloudflare module creates an `allow` policy.

The policy includes:

- all addresses in `cloudflare_access_allowed_emails`
- all domains in `cloudflare_access_allowed_email_domains`

For all committed environment configs, the allow-list is currently email-based, but Zero Trust itself is off by default.

Traffic flow:

1. User opens the Cloudflare hostname.
2. Cloudflare proxies to the AWS load balancer hostname exposed by Kubernetes.
3. If Zero Trust is enabled for that environment, Cloudflare Access checks the user against the allow policy before forwarding traffic.

Origin behavior:

- if `istio_enabled = false`, Cloudflare points to the `ui` service load balancer
- if `istio_enabled = true`, Cloudflare points to the Istio ingress service load balancer

This is Cloudflare DNS, with optional Cloudflare Access, in front of a public AWS origin. It is not Cloudflare Tunnel.

## Injecting Runtime Values

### Manual export

```sh
export CLOUDFLARE_API_TOKEN="..."
export TF_VAR_cloudflare_zone_id="..."
export TF_VAR_argocd_repo_url="https://github.com/CodeX-hakaton/retail-store-sample-infra.git"
```

If Zero Trust is enabled for the target environment:

```sh
export TF_VAR_cloudflare_account_id="..."
```

### AWS Secrets Manager and SSM example

This pattern keeps committed tfvars clean and avoids putting secrets into Terraform files.

```sh
export CLOUDFLARE_API_TOKEN="$(aws secretsmanager get-secret-value \
  --secret-id /retail-store/qa/cloudflare/api-token \
  --query SecretString \
  --output text)"

export TF_VAR_cloudflare_zone_id="$(aws ssm get-parameter \
  --name /retail-store/qa/cloudflare/zone-id \
  --query Parameter.Value \
  --output text)"
```

If Zero Trust is enabled for that environment:

```sh
export TF_VAR_cloudflare_account_id="$(aws ssm get-parameter \
  --name /retail-store/qa/cloudflare/account-id \
  --query Parameter.Value \
  --output text)"
```

If you use CI/CD, inject those same values from your secret store there instead of exporting them locally.

## Managed ECR

Set `managed_ecr_enabled = true` to have Terraform create one private ECR repository per service using the environment name as a prefix.

For `environment_name = "codex-qa"`, Terraform creates:

- `codex-qa-catalog`
- `codex-qa-cart`
- `codex-qa-checkout`
- `codex-qa-orders`
- `codex-qa-ui`

When managed ECR is enabled, the Helm releases switch from the published public images to those private repository URLs automatically.

Important:

- Terraform creates the repositories, but it does not build or push images.
- Your CI pipeline must push the images before or immediately after apply, using the same tag Terraform deploys.
- The default deployed tag stays aligned with the repo's published image tag unless you set `container_image_overrides.default_tag`.

## Deploy

Bootstrap remote state once per account and region:

```sh
./bootstrap/create-tf-backend.sh eu-north-1
cp backend.hcl.example backend.hcl
```

Update `backend.hcl` with the bucket and DynamoDB table names printed by the script.

Or bootstrap backend plus CircleCI in one step:

```sh
./bootstrap/create-aws-bootstrap.sh <circleci-org-id> <circleci-terraform-project-id> <circleci-app-project-id> eu-north-1 false
cp backend.hcl.example backend.hcl
```

Initialize once per checkout:

```sh
terraform init -reconfigure -backend-config=backend.hcl
```

Plan:

```sh
terraform plan -var-file=environments/qa.tfvars
```

Apply:

```sh
terraform apply -var-file=environments/qa.tfvars
```

If you are using Argo CD mode, Argo CD tracks `https://github.com/CodeX-hakaton/retail-store-sample-infra.git` by default. Override `TF_VAR_argocd_repo_url` only if you want Argo CD to watch a different repository that contains this repo's `charts/` directory on the `qa`, `staging`, and `production` branches.

## Accessing The Cluster

After apply:

```sh
terraform output -raw configure_kubectl
```

Run the printed command, then inspect the service:

```sh
kubectl get svc -n ui ui
```

If Istio is enabled:

```sh
kubectl get svc -n istio-ingress
```

## Useful Outputs

Important outputs:

- `configure_kubectl`
- `retail_app_url`
- `retail_app_origin_hostname`
- `cloudflare_application_hostname`
- `cloudflare_application_url`
- `cloudflare_access_application_id`
- `managed_ecr_registry`
- `managed_ecr_repository_urls`

Examples:

```sh
terraform output retail_app_url
terraform output cloudflare_application_url
terraform output retail_app_origin_hostname
terraform output managed_ecr_repository_urls
```

## Applying Cloudflare Environments

1. Export `CLOUDFLARE_API_TOKEN`.
2. Export `TF_VAR_cloudflare_zone_id`.
3. If `cloudflare_zero_trust_enabled = true` for that environment, export `TF_VAR_cloudflare_account_id`.
4. Choose one of the committed var files.
5. Run `terraform plan -var-file=environments/<env>.tfvars`.
6. Run `terraform apply -var-file=environments/<env>.tfvars`.

With the committed environment settings, Terraform will always create Cloudflare DNS for these hostnames depending on the selected var file:

- `qa.codex-devops.pp.ua`
- `staging.codex-devops.pp.ua`
- `codex-devops.pp.ua`

If you later enable Zero Trust for an environment, the current allow-list is:

- `oleksijvun@gmail.com`
- `mykola.biloshapka@lnu.edu.ua`
- `artemzaporozec97@gmail.com`

## Destroy

```sh
terraform destroy -var-file=environments/qa.tfvars
```

Use the same injected Cloudflare values for destroy as for apply. `TF_VAR_cloudflare_account_id` is only required when destroying an environment that has Zero Trust enabled.

## Notes

- Do not commit `CLOUDFLARE_API_TOKEN`.
- Do not commit private tfvars containing runtime-only values.
- Do not commit `backend.hcl`.
- Prefer environment variables or CI secret injection for Cloudflare provider auth.
- The root stack still has an existing EKS/Istio dependency-cycle issue during full `terraform validate`; the Cloudflare child module itself validates successfully.
