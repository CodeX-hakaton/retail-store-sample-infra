#!/bin/bash

set -euo pipefail

project_name="codex"

if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [region]"
  exit 1
fi

region=${1:-eu-north-1}

account_id=$(aws sts get-caller-identity --query Account --output text)
bucket_name="${project_name}-tfstate-${account_id}-${region}"
table_name="${project_name}-tfstate-lock"

echo "Using AWS account: ${account_id}"
echo "Bucket: ${bucket_name}"
echo "Lock table: ${table_name}"
echo "Region: ${region}"

if aws s3api head-bucket --bucket "${bucket_name}" 2>/dev/null; then
  echo "S3 bucket '${bucket_name}' already exists."
else
  echo "Creating S3 bucket '${bucket_name}'..."

  if [ "${region}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${bucket_name}"
  else
    aws s3api create-bucket \
      --bucket "${bucket_name}" \
      --region "${region}" \
      --create-bucket-configuration LocationConstraint="${region}"
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

  echo "S3 bucket '${bucket_name}' created and hardened."
fi

if aws dynamodb describe-table --table-name "${table_name}" --region "${region}" >/dev/null 2>&1; then
  echo "DynamoDB table '${table_name}' already exists."
else
  echo "Creating DynamoDB lock table '${table_name}'..."

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

cat <<EOF

Backend bootstrap is ready.

Create a backend config file from backend.hcl.example, for example:

  bucket         = "${bucket_name}"
  key            = "environments/qa/terraform.tfstate"
  region         = "${region}"
  dynamodb_table = "${table_name}"
  encrypt        = true

Then initialize Terraform with:

  terraform init -reconfigure -backend-config=backend.hcl
EOF
