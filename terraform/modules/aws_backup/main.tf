locals {
  source_vault_name       = "${var.environment_name}-primary"
  destination_vault_name  = "${var.environment_name}-${var.destination_region}"
  protected_resource_arns = sort(distinct(var.source_resource_arns))
}

resource "aws_backup_vault" "source" {
  name = local.source_vault_name
  tags = var.tags
}

resource "aws_backup_vault" "destination" {
  provider = aws.destination

  name = local.destination_vault_name
  tags = var.tags
}

resource "aws_iam_role" "service" {
  name = "${var.environment_name}-aws-backup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_plan" "this" {
  name = "${var.environment_name}-daily"

  rule {
    rule_name         = "${var.environment_name}-daily"
    target_vault_name = aws_backup_vault.source.name
    schedule          = var.schedule
    start_window      = var.start_window_minutes
    completion_window = var.completion_window_minutes

    lifecycle {
      delete_after = var.delete_after_days
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.destination.arn

      lifecycle {
        delete_after = var.copy_delete_after_days
      }
    }
  }

  tags = var.tags
}

resource "aws_backup_selection" "this" {
  iam_role_arn = aws_iam_role.service.arn
  name         = "${var.environment_name}-selection"
  plan_id      = aws_backup_plan.this.id
  resources    = local.protected_resource_arns

  depends_on = [
    aws_iam_role_policy_attachment.backup,
    aws_iam_role_policy_attachment.restore,
  ]
}
