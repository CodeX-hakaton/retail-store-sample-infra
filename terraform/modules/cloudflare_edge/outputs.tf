output "dns_record_id" {
  description = "Cloudflare DNS record ID for the application hostname."
  value       = cloudflare_dns_record.application.id
}

output "hostname" {
  description = "Public hostname managed by Cloudflare."
  value       = var.public_hostname
}

output "access_application_id" {
  description = "Cloudflare Zero Trust Access application ID."
  value       = try(cloudflare_zero_trust_access_application.application[0].id, null)
}

output "access_policy_id" {
  description = "Cloudflare Zero Trust Access policy ID."
  value       = try(cloudflare_zero_trust_access_policy.allow[0].id, null)
}
