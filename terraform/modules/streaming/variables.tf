variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "kms_key_arn" { type = string }
variable "data_lake_bucket_arn" { type = string }
variable "lambda_role_arn" { type = string }
variable "firehose_role_arn" { type = string }
variable "glue_job_name" { type = string }
variable "lambda_source_dir" { type = string }
