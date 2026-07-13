variable "data_lake_bucket_name" { type = string }
variable "glue_assets_bucket_name" { type = string }
variable "kms_alias_prefix" { type = string }
variable "aws_region" {
  type        = string
  description = "AWS region of the deployment; used to scope the CloudWatch Logs KMS grant."
}
variable "tags" { type = map(string) }

variable "raw_retention_days" {
  type    = number
  default = 90
}

variable "clean_retention_days" {
  type    = number
  default = 180
}

variable "analytics_retention_days" {
  type    = number
  default = 365
}

variable "glue_assets_retention_days" {
  type    = number
  default = 30
}

variable "kms_deletion_window_days" {
  type    = number
  default = 7
}

variable "manifest_notification_lambda_arn" {
  type        = string
  default     = null
  nullable    = true
  description = "Lambda ARN attached in Task 005; only raw manifest objects trigger it."
}
