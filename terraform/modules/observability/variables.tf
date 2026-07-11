variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "kms_key_arn" { type = string }
variable "log_retention_days" { type = number }
variable "alarm_sns_topic_arn" {
  type     = string
  default  = null
  nullable = true
}
variable "lambda_function_name" { type = string }
variable "raw_to_clean_job_name" { type = string }
variable "clean_to_analytics_job_name" { type = string }
variable "kinesis_stream_name" { type = string }
variable "firehose_delivery_stream_name" { type = string }
variable "dlq_name" { type = string }
variable "redshift_workgroup_name" { type = string }
variable "athena_workgroup_name" { type = string }
