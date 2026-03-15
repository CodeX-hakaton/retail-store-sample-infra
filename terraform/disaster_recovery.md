# Disaster Recovery

This is the shortest supported DR flow for the current stack.

Production defaults:

- primary region: `eu-north-1`
- DR region: `eu-central-1`
- protected data: `catalog` Aurora, `orders` Aurora, `carts` DynamoDB

## Quick Flow

1. Change Terraform to the DR region.
2. Apply only the network and security groups.
3. Run the DR restore/import script.
4. Run full `terraform apply`.
5. Repoint traffic.

## Step 1: Switch Terraform to DR

Update the environment file or use a DR override file.

Minimum changes:

```hcl
region = "eu-central-1"
aws_backup_enabled = false
```

Use a different `environment_name` only if you need the primary and DR stacks to exist side by side.

## Step 2: Create the DR network skeleton

Run:

```sh
terraform apply \
  -var-file=environments/production.tfvars \
  -target=module.vpc \
  -target=module.component_security_groups
```

This creates only the subnets and security groups the restore step needs.

## Step 3: Restore and import the protected data

Run:

```sh
python3 terraform/tools/dr_recover.py \
  --tf-dir terraform \
  --environment-name codex-production \
  --region eu-central-1 \
  --wait \
  --run-imports
```

What the script does:

- finds the latest copied recovery points in the DR backup vault
- creates the Aurora DB subnet groups if they do not exist yet
- restores `catalog` Aurora, `orders` Aurora, and `carts` DynamoDB
- creates the Aurora `-one` DB instances, because AWS Backup restores the cluster but not the instance
- writes `terraform/dr-recovery/<timestamp>/restore-manifest.json`
- writes `terraform/dr-recovery/<timestamp>/terraform-imports.sh`
- runs the generated `terraform state rm` and `terraform import` commands when `--run-imports` is set

If you want to inspect the import script before running it, omit `--run-imports`.

## Step 4: Run full Terraform

Run:

```sh
terraform apply -var-file=environments/production.tfvars
```

After the imports are in state, Terraform can continue from the recovered Aurora clusters, the restored DynamoDB table, and the created DB subnet groups instead of trying to create fresh ones.

## Step 5: Recover remaining dependencies

Not covered by AWS Backup in this stack:

- Amazon MQ
- ElastiCache Redis

Current expectation:

- recreate Redis
- recreate or separately recover Amazon MQ

## Step 6: Cut traffic over

Validate the DR stack, then repoint traffic:

- UI loads
- `catalog`, `orders`, and `carts` work
- order creation succeeds
- Cloudflare points at the DR origin

## Important limitation

This is still restore-based DR, not active replication.

The script removes most of the manual Terraform reconciliation work, but the durable data still has to be restored before the final apply.
