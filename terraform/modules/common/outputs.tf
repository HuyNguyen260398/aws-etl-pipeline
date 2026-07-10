output "name_prefix" {
  description = "Consistent prefix for named resources."
  value       = local.name_prefix
}

output "tags" {
  description = "Standard tags for all managed resources."
  value       = local.tags
}
