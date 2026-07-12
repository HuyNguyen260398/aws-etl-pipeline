variable "name_prefix" { type = string }
variable "aws_region" { type = string }
variable "tags" { type = map(string) }
variable "glue_role_arn" { type = string }
variable "glue_role_name" { type = string }
variable "data_lake_bucket_name" { type = string }
variable "data_lake_kms_key_arn" { type = string }
variable "glue_assets_bucket_name" { type = string }
variable "raw_to_clean_source_path" { type = string }
variable "clean_to_analytics_source_path" { type = string }
variable "quality_library_source_dir" { type = string }
variable "orchestrator_source_dir" { type = string }
variable "worker_type" {
  type    = string
  default = "G.1X"
}

variable "number_of_workers" {
  type    = number
  default = 2
}

variable "timeout_minutes" {
  type    = number
  default = 30
}

variable "max_retries" {
  type    = number
  default = 1
}

variable "glue_version" {
  type    = string
  default = "4.0"
}
variable "catalog_database_names" { type = list(string) }
variable "raw_to_clean_log_group_name" { type = string }
variable "clean_to_analytics_log_group_name" { type = string }
