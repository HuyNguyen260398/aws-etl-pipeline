variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "data_lake_bucket_name" { type = string }
variable "data_lake_kms_key_arn" { type = string }
variable "athena_bytes_scanned_cutoff_per_query" { type = number }
variable "redshift_base_capacity" { type = number }
variable "redshift_admin_secret_arn" {
  type      = string
  sensitive = true
}
variable "redshift_role_arn" { type = string }
variable "security_group_ids" { type = list(string) }
variable "subnet_ids" { type = list(string) }
