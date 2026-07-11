variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "aws_region" { type = string }
variable "github_oidc_provider_arn" { type = string }
variable "github_repository" { type = string }
variable "analytics_reader_trusted_principal_arn" { type = string }
variable "data_lake_bucket_arn" { type = string }
variable "data_lake_kms_key_arn" { type = string }
