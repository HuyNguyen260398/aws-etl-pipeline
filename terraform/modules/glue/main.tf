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

data "aws_caller_identity" "current" {}

locals {
  glue_catalog_arn = "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:catalog"
  glue_database_arns = [
    for database in var.catalog_database_names : "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:database/${database}"
  ]
  glue_table_arns = [
    for database in var.catalog_database_names : "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${database}/*"
  ]
  glue_log_group_arn = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/*"
}

resource "aws_iam_role_policy" "catalog_access" {
  name = "${var.name_prefix}-glue-catalog"
  role = var.glue_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["glue:GetDatabases"]
        Resource = local.glue_catalog_arn
      },
      {
        Effect   = "Allow"
        Action   = ["glue:GetDatabase"]
        Resource = local.glue_database_arns
      },
      {
        Effect   = "Allow"
        Action   = ["glue:GetTable", "glue:GetTables", "glue:GetPartitions", "glue:BatchCreatePartition", "glue:UpdateTable"]
        Resource = local.glue_table_arns
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup"]
        Resource = local.glue_log_group_arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${var.glue_assets_bucket_name}/glue-assets/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:AssociateKmsKey", "logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]
        Resource = "${local.glue_log_group_arn}:*"
      },
    ]
  })
}

locals {
  common_default_arguments = {
    "--enable-job-bookmark"              = "job-bookmark-enable"
    "--enable-glue-datacatalog"          = "true"
    "--enable-continuous-cloudwatch-log" = "true"
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
    "--continuous-log-logGroup" = var.raw_to_clean_log_group_name
    "--raw-prefix"              = "raw/"
    "--data-lake-bucket"        = var.data_lake_bucket_name
    "--clean-prefix"            = "s3://${var.data_lake_bucket_name}/clean/"
    "--quarantine-prefix"       = "s3://${var.data_lake_bucket_name}/quarantine/"
    "--run-id"                  = "scheduled"
    "--ingest-date"             = "1970-01-01"
  })
  # Raw-to-clean is driven by both batch manifests (via Lambda) and streaming
  # backfills, which can overlap; allow a few concurrent runs.
  execution_property { max_concurrent_runs = 3 }
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
    "--continuous-log-logGroup" = var.clean_to_analytics_log_group_name
    "--clean-prefix"            = "s3://${var.data_lake_bucket_name}/clean/"
    "--analytics-prefix"        = "s3://${var.data_lake_bucket_name}/analytics/"
  })
  execution_property { max_concurrent_runs = 1 }
  tags = var.tags
}

# Chain clean-to-analytics after raw-to-clean succeeds. Standalone Glue
# conditional triggers do not fire for jobs started via StartJobRun (the
# manifest Lambda), so an EventBridge rule invokes an orchestrator Lambda
# that starts clean-to-analytics.
data "archive_file" "orchestrator" {
  type        = "zip"
  source_dir  = var.orchestrator_source_dir
  output_path = "${path.module}/orchestrator.zip"
}

resource "aws_iam_role" "orchestrator" {
  name = "${var.name_prefix}-glue-orchestrator"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "orchestrator" {
  name = "${var.name_prefix}-glue-orchestrator"
  role = aws_iam_role.orchestrator.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["glue:StartJobRun"]
        Resource = aws_glue_job.clean_to_analytics.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.orchestrator.arn}:*"
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "orchestrator" {
  name              = "/aws/lambda/${var.name_prefix}-glue-orchestrator"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_lambda_function" "orchestrator" {
  function_name    = "${var.name_prefix}-glue-orchestrator"
  role             = aws_iam_role.orchestrator.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.orchestrator.output_path
  source_code_hash = data.archive_file.orchestrator.output_base64sha256
  timeout          = 30

  environment {
    variables = { GLUE_JOB_NAME = aws_glue_job.clean_to_analytics.name }
  }

  depends_on = [aws_cloudwatch_log_group.orchestrator]
  tags       = var.tags
}

resource "aws_cloudwatch_event_rule" "raw_to_clean_succeeded" {
  name        = "${var.name_prefix}-raw-to-clean-succeeded"
  description = "Start clean-to-analytics when raw-to-clean succeeds."
  event_pattern = jsonencode({
    source      = ["aws.glue"]
    detail-type = ["Glue Job State Change"]
    detail = {
      jobName = [aws_glue_job.raw_to_clean.name]
      state   = ["SUCCEEDED"]
    }
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "start_clean_to_analytics" {
  rule = aws_cloudwatch_event_rule.raw_to_clean_succeeded.name
  arn  = aws_lambda_function.orchestrator.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.raw_to_clean_succeeded.arn
}
