package main

env_branch(name) = "qa" {
  endswith(name, "-qa")
}

env_branch(name) = "staging" {
  endswith(name, "-staging")
}

env_branch(name) = "production" {
  endswith(name, "-production")
}

deny[msg] {
  object.get(input, "expected_aws_account_id", "") == ""
  msg := "expected_aws_account_id must be set"
}

deny[msg] {
  object.get(input, "managed_ecr_enabled", false) != true
  msg := "managed_ecr_enabled must be true"
}

deny[msg] {
  object.get(input, "app_deployment_mode", "") == "argocd"
  branch := env_branch(object.get(input, "environment_name", ""))
  object.get(input, "argocd_target_revision", "") != branch
  msg := sprintf("%s must track argocd_target_revision=%s", [object.get(input, "environment_name", "environment"), branch])
}

deny[msg] {
  object.get(input, "aws_backup_enabled", false) == true
  object.get(input, "aws_backup_destination_region", "") == ""
  msg := "aws_backup_destination_region must be set when backups are enabled"
}

deny[msg] {
  object.get(input, "aws_backup_enabled", false) == true
  region := object.get(input, "region", "")
  region != ""
  object.get(input, "aws_backup_destination_region", "") == region
  msg := "aws_backup_destination_region must differ from region"
}
