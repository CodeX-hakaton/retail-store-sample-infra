output "catalog_id" {
  description = "Security group ID for the catalog component."
  value       = aws_security_group.catalog.id
}

output "orders_id" {
  description = "Security group ID for the orders component."
  value       = aws_security_group.orders.id
}

output "checkout_id" {
  description = "Security group ID for the checkout component."
  value       = aws_security_group.checkout.id
}
