# Deployment outputs. After `terraform apply`, run:
#   terraform -chdir=terraform/environments/dev output
# or a single value, e.g.:
#   terraform -chdir=terraform/environments/dev output -raw data_lake_bucket_name

output "aws_region" {
  description = "Region the stack is deployed in."
  value       = var.aws_region
}

output "name_prefix" {
  description = "Prefix applied to all named resources (project-environment)."
  value       = module.common.name_prefix
}

# ---------- Storage ----------
output "data_lake_bucket_name" {
  description = "S3 data-lake bucket holding the raw/clean/analytics/quarantine zones."
  value       = module.data_lake.data_lake_bucket_name
}

output "glue_assets_bucket_name" {
  description = "S3 bucket holding Glue job scripts and the packaged quality library."
  value       = module.data_lake.glue_assets_bucket_name
}

output "data_lake_kms_key_arn" {
  description = "KMS key encrypting the data lake, Glue assets, and analytics stores."
  value       = module.data_lake.data_lake_kms_key_arn
}

output "zone_prefixes" {
  description = "Object-key prefixes for each data-lake zone."
  value       = module.data_lake.zone_prefixes
}

# ---------- Networking ----------
output "vpc_id" {
  description = "VPC hosting the private subnets and S3 gateway endpoint."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets used by Glue and Redshift Serverless."
  value       = module.network.private_subnet_ids
}

# ---------- Ingestion & ETL ----------
output "kinesis_stream_name" {
  description = "Kinesis Data Stream that receives streaming events."
  value       = module.streaming.kinesis_stream_name
}

output "validator_lambda_arn" {
  description = "Manifest-validator Lambda invoked by raw/ manifest.json uploads."
  value       = module.streaming.validator_lambda_arn
}

output "raw_to_clean_job_name" {
  description = "Glue job that writes canonical Parquet to the clean zone."
  value       = module.glue.raw_to_clean_job_name
}

output "clean_to_analytics_job_name" {
  description = "Glue job that builds BI models in the analytics zone."
  value       = module.glue.clean_to_analytics_job_name
}

# ---------- Catalog & analytics ----------
output "glue_catalog_databases" {
  description = "Glue Data Catalog databases for each zone."
  value = {
    raw       = module.governance.raw_database_name
    clean     = module.governance.clean_database_name
    analytics = module.governance.analytics_database_name
  }
}

output "athena_workgroup_name" {
  description = "Athena workgroup (scan-capped) for querying the analytics zone."
  value       = module.analytics.athena_workgroup_name
}

output "redshift_workgroup_name" {
  description = "Redshift Serverless workgroup that MERGEs analytics Parquet into fact tables."
  value       = module.analytics.redshift_workgroup_name
}

output "redshift_namespace_name" {
  description = "Redshift Serverless namespace holding the music_analytics database."
  value       = module.analytics.redshift_namespace_name
}

# ---------- Access ----------
output "analytics_reader_role_arn" {
  description = "Least-privilege role that can query analytics only (raw is denied)."
  value       = module.iam.analytics_reader_role_arn
}

# ---------- Observability ----------
output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard summarizing pipeline health."
  value       = module.observability.dashboard_name
}
