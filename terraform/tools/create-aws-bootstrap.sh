#!/bin/bash

set -euo pipefail

project_name="codex"

if [ "$#" -lt 3 ] || [ "$#" -gt 5 ]; then
  echo "Usage: $0 <circleci-org-id> <circleci-terraform-project-id> <circleci-app-project-id> [region] [production-only]"
  exit 1
fi

circleci_org_id=$1
circleci_terraform_project_id=$2
circleci_app_project_id=$3
region=${4:-eu-north-1}
production_only=${5:-false}

account_id=$(aws sts get-caller-identity --query Account --output text)
bucket_name="${project_name}-tfstate-${account_id}-${region}"
table_name="${project_name}-tfstate-lock"
oidc_provider_arn="arn:aws:iam::${account_id}:oidc-provider/oidc.circleci.com/org/${circleci_org_id}"

echo "Using AWS account: ${account_id}"
echo "Region: ${region}"
echo "Production only: ${production_only}"
echo "Terraform state bucket: ${bucket_name}"
echo "Terraform lock table: ${table_name}"

TERRAFORM_STATE_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::${bucket_name}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::${bucket_name}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:${region}:${account_id}:table/${table_name}"
    }
  ]
}
EOF
)

TERRAFORM_READ_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "eks:Describe*",
        "eks:List*",
        "elasticloadbalancing:Describe*",
        "autoscaling:Describe*",
        "iam:Get*",
        "iam:List*",
        "logs:Describe*",
        "logs:Get*",
        "logs:List*",
        "cloudwatch:Describe*",
        "cloudwatch:Get*",
        "cloudwatch:List*",
        "events:Describe*",
        "events:List*",
        "waf:Get*",
        "waf:List*",
        "wafv2:Get*",
        "wafv2:List*",
        "elasticache:Describe*",
        "rds:Describe*",
        "rds:ListTagsForResource",
        "s3:GetBucket*",
        "s3:List*",
        "s3:GetObject",
        "ssm:Describe*",
        "ssm:Get*",
        "dynamodb:Describe*",
        "dynamodb:GetItem",
        "dynamodb:List*",
        "dynamodb:Query",
        "dynamodb:Scan",
        "mq:Describe*",
        "mq:List*",
        "ecr:Describe*",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:ListImages",
        "acm:Describe*",
        "acm:Get*",
        "acm:List*",
        "kms:Describe*",
        "kms:Get*",
        "kms:List*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

TERRAFORM_APPLY_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "elasticloadbalancing:*",
        "autoscaling:*",
        "iam:*",
        "logs:*",
        "cloudwatch:*",
        "events:*",
        "waf:*",
        "wafv2:*",
        "elasticache:*",
        "rds:*",
        "s3:*",
        "ssm:*",
        "dynamodb:*",
        "mq:*",
        "ecr:*",
        "acm:*",
        "kms:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

IMAGE_PUSH_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:ListImages",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": "arn:aws:ecr:${region}:${account_id}:repository/*"
    }
  ]
}
EOF
)

create_s3_bucket() {
  echo "Ensuring S3 bucket '${bucket_name}' exists..."

  if aws s3api head-bucket --bucket "${bucket_name}" 2>/dev/null; then
    echo "S3 bucket '${bucket_name}' already exists."
  else
    if [ "${region}" = "us-east-1" ]; then
      aws s3api create-bucket --bucket "${bucket_name}"
    else
      aws s3api create-bucket \
        --bucket "${bucket_name}" \
        --region "${region}" \
        --create-bucket-configuration LocationConstraint="${region}"
    fi

    echo "S3 bucket '${bucket_name}' created."
  fi

  aws s3api put-bucket-versioning \
    --bucket "${bucket_name}" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "${bucket_name}" \
    --server-side-encryption-configuration '{
      "Rules": [
        {
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
          }
        }
      ]
    }'

  aws s3api put-public-access-block \
    --bucket "${bucket_name}" \
    --public-access-block-configuration '{
      "BlockPublicAcls": true,
      "IgnorePublicAcls": true,
      "BlockPublicPolicy": true,
      "RestrictPublicBuckets": true
    }'

  echo "S3 bucket '${bucket_name}' hardened."
}

create_dynamodb_table() {
  echo "Ensuring DynamoDB table '${table_name}' exists..."

  if aws dynamodb describe-table --table-name "${table_name}" --region "${region}" >/dev/null 2>&1; then
    echo "DynamoDB table '${table_name}' already exists."
  else
    aws dynamodb create-table \
      --table-name "${table_name}" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --sse-specification Enabled=true \
      --region "${region}"

    aws dynamodb wait table-exists \
      --table-name "${table_name}" \
      --region "${region}"

    echo "DynamoDB table '${table_name}' created."
  fi
}

create_oidc_provider() {
  local thumbprint
  thumbprint="9e2ef17e6e580340d1c7694f489f64923f03b5f9"

  echo "Ensuring CircleCI OIDC provider exists..."

  if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${oidc_provider_arn}" >/dev/null 2>&1; then
    echo "OIDC provider already exists."
  else
    aws iam create-open-id-connect-provider \
      --url "https://oidc.circleci.com/org/${circleci_org_id}" \
      --thumbprint-list "${thumbprint}" \
      --client-id-list "${circleci_org_id}"

    echo "OIDC provider created."
  fi
}

get_trust_policy() {
  local branch_pattern=${1:-"refs/heads/*"}
  shift

  local patterns=()
  local project_id

  for project_id in "$@"; do
    patterns+=("\"org/${circleci_org_id}/project/${project_id}/user/*/vcs-origin/*/vcs-ref/${branch_pattern}\"")
  done

  local patterns_json
  patterns_json=$(IFS=,; echo "${patterns[*]}")

  cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.circleci.com/org/${circleci_org_id}:aud": "${circleci_org_id}"
        },
        "StringLike": {
          "oidc.circleci.com/org/${circleci_org_id}:sub": [${patterns_json}]
        }
      }
    }
  ]
}
EOF
}

upsert_role() {
  local role_name=$1
  local trust_policy=$2

  if aws iam get-role --role-name "${role_name}" >/dev/null 2>&1; then
    aws iam update-assume-role-policy \
      --role-name "${role_name}" \
      --policy-document "${trust_policy}" >/dev/null
    echo "Updated trust policy for '${role_name}'."
  else
    aws iam create-role \
      --role-name "${role_name}" \
      --assume-role-policy-document "${trust_policy}" >/dev/null
    echo "Created role '${role_name}'."
  fi
}

put_inline_policy() {
  local role_name=$1
  local policy_name=$2
  local policy_document=$3

  aws iam put-role-policy \
    --role-name "${role_name}" \
    --policy-name "${policy_name}" \
    --policy-document "${policy_document}" >/dev/null

  echo "Attached inline policy '${policy_name}' to '${role_name}'."
}

create_cicd_roles() {
  local apply_branch="refs/heads/*"

  if [ "${production_only}" = "true" ]; then
    apply_branch="refs/heads/production"
  fi

  local terraform_plan_role="cicd-${project_name}-terraform-plan"
  local terraform_apply_role="cicd-${project_name}-terraform-apply"
  local image_push_role="cicd-${project_name}-image-push"

  local trust_plan
  local trust_apply
  local trust_image_push

  trust_plan=$(get_trust_policy "refs/heads/*" "${circleci_terraform_project_id}")
  trust_apply=$(get_trust_policy "${apply_branch}" "${circleci_terraform_project_id}")
  trust_image_push=$(get_trust_policy "refs/heads/*" "${circleci_app_project_id}")

  upsert_role "${terraform_plan_role}" "${trust_plan}"
  put_inline_policy "${terraform_plan_role}" "TerraformStateAccess" "${TERRAFORM_STATE_POLICY}"
  put_inline_policy "${terraform_plan_role}" "TerraformReadAccess" "${TERRAFORM_READ_POLICY}"

  upsert_role "${terraform_apply_role}" "${trust_apply}"
  put_inline_policy "${terraform_apply_role}" "TerraformStateAccess" "${TERRAFORM_STATE_POLICY}"
  put_inline_policy "${terraform_apply_role}" "TerraformApplyAccess" "${TERRAFORM_APPLY_POLICY}"

  upsert_role "${image_push_role}" "${trust_image_push}"
  put_inline_policy "${image_push_role}" "ImagePushAccess" "${IMAGE_PUSH_POLICY}"
}

print_summary() {
  cat <<EOF

Bootstrap is ready.

Created or updated:
  - S3 bucket: ${bucket_name}
  - DynamoDB lock table: ${table_name}
  - OIDC provider: ${oidc_provider_arn}
  - IAM role: cicd-${project_name}-terraform-plan
  - IAM role: cicd-${project_name}-terraform-apply
  - IAM role: cicd-${project_name}-image-push

Backend config for this repo:

  bucket         = "${bucket_name}"
  key            = "environments/qa/terraform.tfstate"
  region         = "${region}"
  dynamodb_table = "${table_name}"
  encrypt        = true

Suggested CircleCI environment variables:

  TFSTATE_BUCKET=${bucket_name}
  TFSTATE_LOCK_TABLE=${table_name}
  AWS_REGION=${region}
  TERRAFORM_PLAN_ROLE_ARN=arn:aws:iam::${account_id}:role/cicd-${project_name}-terraform-plan
  TERRAFORM_APPLY_ROLE_ARN=arn:aws:iam::${account_id}:role/cicd-${project_name}-terraform-apply
  IMAGE_PUSH_ROLE_ARN=arn:aws:iam::${account_id}:role/cicd-${project_name}-image-push

If you use managed ECR in Terraform, the image push role is the one your app pipeline should assume.
EOF
}

main() {
  create_s3_bucket
  create_dynamodb_table
  create_oidc_provider
  create_cicd_roles
  print_summary
}

main
