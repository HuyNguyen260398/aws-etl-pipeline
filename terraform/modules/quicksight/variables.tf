variable "name_prefix" { type = string }
variable "aws_region" { type = string }
variable "quicksight_enabled" {
  type    = bool
  default = false
}
variable "quicksight_principal_arn" {
  type     = string
  default  = null
  nullable = true
}
variable "quicksight_vpc_connection_role_arn" {
  description = "IAM role ARN used by QuickSight to create the private VPC connection."
  type        = string
  default     = null
  nullable    = true
}
variable "quicksight_refresh_schedule" {
  description = "QuickSight SPICE refresh interval after a successful Redshift merge."
  type        = string
  default     = "DAILY"
}
variable "redshift_workgroup_name" { type = string }
variable "redshift_database_name" { type = string }
variable "redshift_admin_secret_arn" {
  type      = string
  sensitive = true
}
variable "private_subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "tags" { type = map(string) }
