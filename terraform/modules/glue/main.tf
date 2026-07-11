data "archive_file" "quality_library" {
  type        = "zip"
  source_dir  = var.quality_library_source_dir
  output_path = "${path.module}/quality-library.zip"
}

resource "aws_s3_object" "raw_to_clean_script" {
  bucket = var.glue_assets_bucket_name
  key    = "glue-assets/scripts/raw_to_clean.py"
  source = var.raw_to_clean_source_path
  etag   = filemd5(var.raw_to_clean_source_path)
}

resource "aws_s3_object" "clean_to_analytics_script" {
  bucket = var.glue_assets_bucket_name
  key    = "glue-assets/scripts/clean_to_analytics.py"
  source = var.clean_to_analytics_source_path
  etag   = filemd5(var.clean_to_analytics_source_path)
}

resource "aws_s3_object" "quality_library" {
  bucket = var.glue_assets_bucket_name
  key    = "glue-assets/libraries/quality-library.zip"
  source = data.archive_file.quality_library.output_path
  etag   = data.archive_file.quality_library.output_md5
}

resource "aws_cloudwatch_log_group" "jobs" {
  name              = "/aws-glue/jobs/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.data_lake_kms_key_arn
  tags              = var.tags
}

resource "aws_glue_security_configuration" "this" {
  name = "${var.name_prefix}-glue-security"

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "SSE-KMS"
      kms_key_arn                = var.data_lake_kms_key_arn
    }

    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "CSE-KMS"
      kms_key_arn                   = var.data_lake_kms_key_arn
    }

    s3_encryption {
      s3_encryption_mode = "SSE-KMS"
      kms_key_arn        = var.data_lake_kms_key_arn
    }
  }
}

resource "aws_iam_role_policy" "catalog_access" {
  name = "${var.name_prefix}-glue-catalog"
  role = var.glue_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["glue:GetDatabase", "glue:GetDatabases", "glue:GetTable", "glue:GetTables", "glue:GetPartitions", "glue:BatchCreatePartition", "glue:UpdateTable"]
      Resource = "*"
    }]
  })
}

locals {
  common_default_arguments = {
    "--enable-job-bookmark"              = "job-bookmark-enable"
    "--enable-glue-datacatalog"          = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.jobs.name
    "--TempDir"                          = "s3://${var.glue_assets_bucket_name}/glue-assets/temporary/"
    "--extra-py-files"                   = "s3://${var.glue_assets_bucket_name}/${aws_s3_object.quality_library.key}"
    "--catalog-databases"                = join(",", var.catalog_database_names)
  }
}

resource "aws_glue_job" "raw_to_clean" {
  name                   = "${var.name_prefix}-raw-to-clean"
  role_arn               = var.glue_role_arn
  glue_version           = var.glue_version
  worker_type            = var.worker_type
  number_of_workers      = var.number_of_workers
  timeout                = var.timeout_minutes
  max_retries            = var.max_retries
  security_configuration = aws_glue_security_configuration.this.name

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.glue_assets_bucket_name}/${aws_s3_object.raw_to_clean_script.key}"
  }
  default_arguments = merge(local.common_default_arguments, {
    "--raw-prefix"        = "raw/"
    "--data-lake-bucket"  = var.data_lake_bucket_name
    "--clean-prefix"      = "s3://${var.data_lake_bucket_name}/clean/"
    "--quarantine-prefix" = "s3://${var.data_lake_bucket_name}/quarantine/"
    "--run-id"            = "scheduled"
    "--ingest-date"       = "1970-01-01"
  })
  execution_property { max_concurrent_runs = 1 }
  tags = var.tags
}

resource "aws_glue_job" "clean_to_analytics" {
  name                   = "${var.name_prefix}-clean-to-analytics"
  role_arn               = var.glue_role_arn
  glue_version           = var.glue_version
  worker_type            = var.worker_type
  number_of_workers      = var.number_of_workers
  timeout                = var.timeout_minutes
  max_retries            = var.max_retries
  security_configuration = aws_glue_security_configuration.this.name

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.glue_assets_bucket_name}/${aws_s3_object.clean_to_analytics_script.key}"
  }
  default_arguments = merge(local.common_default_arguments, {
    "--clean-prefix"     = "s3://${var.data_lake_bucket_name}/clean/"
    "--analytics-prefix" = "s3://${var.data_lake_bucket_name}/analytics/"
  })
  execution_property { max_concurrent_runs = 1 }
  tags = var.tags
}
