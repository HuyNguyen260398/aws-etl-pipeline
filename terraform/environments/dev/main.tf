terraform {
  required_version = ">= 1.7.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile == "" ? null : var.aws_profile

  dynamic "assume_role" {
    for_each = var.assume_role_arn == "" ? [] : [var.assume_role_arn]
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = module.common.tags
  }
}

module "common" {
  source = "../../modules/common"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  common_tags  = var.common_tags
}

module "network" {
  source = "../../modules/network"

  name_prefix            = module.common.name_prefix
  aws_region             = var.aws_region
  vpc_cidr               = var.vpc_cidr
  private_subnet_cidrs   = var.private_subnet_cidrs
  nat_public_subnet_cidr = var.nat_public_subnet_cidr
  s3_endpoint_allowed_bucket_arns = concat(
    var.s3_endpoint_allowed_bucket_arns,
    [module.data_lake.data_lake_bucket_arn, module.data_lake.glue_assets_bucket_arn],
  )
  s3_endpoint_allowed_principal_arns = var.s3_endpoint_allowed_principal_arns
  enable_nat_gateway                 = var.enable_nat_gateway
  flow_log_retention_days            = var.flow_log_retention_days
  flow_log_kms_key_id                = var.flow_log_kms_key_id
  tags                               = module.common.tags
}

module "data_lake" {
  source = "../../modules/data_lake"

  data_lake_bucket_name      = var.data_lake_bucket_name
  glue_assets_bucket_name    = var.glue_assets_bucket_name
  kms_alias_prefix           = var.kms_alias_prefix
  raw_retention_days         = var.raw_retention_days
  clean_retention_days       = var.clean_retention_days
  analytics_retention_days   = var.analytics_retention_days
  glue_assets_retention_days = var.glue_assets_retention_days
  tags                       = module.common.tags
}

module "iam" {
  source = "../../modules/iam"

  name_prefix                            = module.common.name_prefix
  tags                                   = module.common.tags
  github_oidc_provider_arn               = var.github_oidc_provider_arn
  github_repository                      = var.github_repository
  analytics_reader_trusted_principal_arn = var.analytics_reader_trusted_principal_arn
  data_lake_bucket_arn                   = module.data_lake.data_lake_bucket_arn
  data_lake_kms_key_arn                  = module.data_lake.data_lake_kms_key_arn
}

module "governance" {
  source = "../../modules/governance"

  catalog_name_prefix       = var.project_name
  data_lake_bucket_arn      = module.data_lake.data_lake_bucket_arn
  data_lake_bucket_name     = module.data_lake.data_lake_bucket_name
  glue_role_arn             = module.iam.glue_role_arn
  analytics_reader_role_arn = module.iam.analytics_reader_role_arn
}

module "streaming" {
  source               = "../../modules/streaming"
  name_prefix          = module.common.name_prefix
  tags                 = module.common.tags
  kms_key_arn          = module.data_lake.data_lake_kms_key_arn
  data_lake_bucket_arn = module.data_lake.data_lake_bucket_arn
  lambda_role_arn      = module.iam.lambda_role_arn
  firehose_role_arn    = module.iam.firehose_role_arn
  glue_job_name        = module.glue.raw_to_clean_job_name
  lambda_source_dir    = "${path.root}/../../../src/lambda/validator"
}

module "glue" {
  source = "../../modules/glue"

  name_prefix                       = module.common.name_prefix
  aws_region                        = var.aws_region
  tags                              = module.common.tags
  glue_role_arn                     = module.iam.glue_role_arn
  glue_role_name                    = element(reverse(split("/", module.iam.glue_role_arn)), 0)
  data_lake_bucket_name             = module.data_lake.data_lake_bucket_name
  data_lake_kms_key_arn             = module.data_lake.data_lake_kms_key_arn
  glue_assets_bucket_name           = module.data_lake.glue_assets_bucket_name
  raw_to_clean_source_path          = "${path.root}/../../../src/glue/jobs/raw_to_clean.py"
  clean_to_analytics_source_path    = "${path.root}/../../../src/glue/jobs/clean_to_analytics.py"
  quality_library_source_dir        = "${path.root}/../../../src"
  worker_type                       = var.glue_worker_type
  number_of_workers                 = var.glue_number_of_workers
  timeout_minutes                   = var.glue_timeout_minutes
  max_retries                       = var.glue_max_retries
  glue_version                      = var.glue_version
  catalog_database_names            = ["music_raw", "music_clean", "music_analytics"]
  raw_to_clean_log_group_name       = "/aws-glue/jobs/${module.common.name_prefix}-raw-to-clean"
  clean_to_analytics_log_group_name = "/aws-glue/jobs/${module.common.name_prefix}-clean-to-analytics"
}

module "analytics" {
  source = "../../modules/analytics"

  name_prefix                           = module.common.name_prefix
  tags                                  = module.common.tags
  data_lake_bucket_name                 = module.data_lake.data_lake_bucket_name
  data_lake_kms_key_arn                 = module.data_lake.data_lake_kms_key_arn
  athena_bytes_scanned_cutoff_per_query = var.athena_bytes_scanned_cutoff_per_query
  redshift_base_capacity                = var.redshift_base_capacity
  redshift_admin_secret_arn             = var.redshift_admin_secret_arn
  redshift_role_arn                     = module.iam.redshift_role_arn
  security_group_ids                    = [module.network.redshift_security_group_id]
  subnet_ids                            = module.network.private_subnet_ids
}

module "observability" {
  source = "../../modules/observability"

  name_prefix                   = module.common.name_prefix
  tags                          = module.common.tags
  kms_key_arn                   = module.data_lake.data_lake_kms_key_arn
  log_retention_days            = var.glue_log_retention_days
  alarm_sns_topic_arn           = var.alarm_sns_topic_arn
  lambda_function_name          = "${module.common.name_prefix}-manifest-validator"
  raw_to_clean_job_name         = module.glue.raw_to_clean_job_name
  clean_to_analytics_job_name   = module.glue.clean_to_analytics_job_name
  kinesis_stream_name           = module.streaming.kinesis_stream_name
  firehose_delivery_stream_name = "${module.common.name_prefix}-raw-delivery"
  dlq_name                      = "${module.common.name_prefix}-manifest-dlq"
  redshift_workgroup_name       = module.analytics.redshift_workgroup_name
  athena_workgroup_name         = module.analytics.athena_workgroup_name
}

module "quicksight" {
  source = "../../modules/quicksight"

  name_prefix                        = module.common.name_prefix
  aws_region                         = var.aws_region
  quicksight_enabled                 = var.quicksight_enabled
  quicksight_principal_arn           = var.quicksight_principal_arn
  quicksight_vpc_connection_role_arn = var.quicksight_vpc_connection_role_arn
  quicksight_refresh_schedule        = var.quicksight_refresh_schedule
  redshift_workgroup_name            = module.analytics.redshift_workgroup_name
  redshift_database_name             = "music_analytics"
  redshift_admin_secret_arn          = var.redshift_admin_secret_arn
  private_subnet_ids                 = module.network.private_subnet_ids
  security_group_ids                 = [module.network.redshift_security_group_id]
  tags                               = module.common.tags
}

resource "aws_s3_bucket_notification" "raw_manifest" {
  bucket = module.data_lake.data_lake_bucket_name

  lambda_function {
    lambda_function_arn = module.streaming.validator_lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
    filter_suffix       = "manifest.json"
  }

  depends_on = [aws_lambda_permission.s3_manifest]
}

resource "aws_lambda_permission" "s3_manifest" {
  statement_id  = "AllowDataLakeManifestInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.streaming.validator_lambda_arn
  principal     = "s3.amazonaws.com"
  source_arn    = module.data_lake.data_lake_bucket_arn
}
