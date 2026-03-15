output "source_vault_name" {
  description = "Name of the backup vault in the primary region."
  value       = aws_backup_vault.source.name
}

output "source_vault_arn" {
  description = "ARN of the backup vault in the primary region."
  value       = aws_backup_vault.source.arn
}

output "destination_vault_name" {
  description = "Name of the backup vault in the destination region."
  value       = aws_backup_vault.destination.name
}

output "destination_vault_arn" {
  description = "ARN of the backup vault in the destination region."
  value       = aws_backup_vault.destination.arn
}

output "plan_id" {
  description = "AWS Backup plan ID."
  value       = aws_backup_plan.this.id
}

output "service_role_arn" {
  description = "IAM role used by AWS Backup."
  value       = aws_iam_role.service.arn
}
