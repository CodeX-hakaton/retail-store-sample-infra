package main

test_env_policy_accepts_current_qa_shape {
  results := {msg |
    deny[msg] with input as {
      "environment_name": "codex-qa",
      "expected_aws_account_id": "010829528421",
      "region": "eu-north-1",
      "managed_ecr_enabled": true,
      "app_deployment_mode": "argocd",
      "argocd_target_revision": "qa",
    }
  }
  count(results) == 0
}

test_env_policy_accepts_backup_configuration {
  results := {msg |
    deny[msg] with input as {
      "environment_name": "codex-production",
      "expected_aws_account_id": "382764426605",
      "region": "eu-north-1",
      "managed_ecr_enabled": true,
      "app_deployment_mode": "argocd",
      "argocd_target_revision": "production",
      "aws_backup_enabled": true,
      "aws_backup_destination_region": "eu-central-1",
    }
  }
  count(results) == 0
}

test_env_policy_rejects_missing_expected_account_id {
  some msg
  deny[msg] with input as {
    "environment_name": "codex-qa",
    "managed_ecr_enabled": true,
  }
  msg == "expected_aws_account_id must be set"
}

test_env_policy_rejects_wrong_branch_tracking {
  some msg
  deny[msg] with input as {
    "environment_name": "codex-staging",
    "expected_aws_account_id": "010829528421",
    "managed_ecr_enabled": true,
    "app_deployment_mode": "argocd",
    "argocd_target_revision": "qa",
  }
  msg == "codex-staging must track argocd_target_revision=staging"
}
