output "repository_names" {
  description = "ECR repository names by service."
  value       = { for service, repository in aws_ecr_repository.service : service => repository.name }
}

output "repository_urls" {
  description = "ECR repository URLs by service."
  value       = { for service, repository in aws_ecr_repository.service : service => repository.repository_url }
}
