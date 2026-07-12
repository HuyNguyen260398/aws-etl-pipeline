locals {
  service_principals = {
    lambda   = "lambda.amazonaws.com"
    firehose = "firehose.amazonaws.com"
    glue     = "glue.amazonaws.com"
    redshift = "redshift.amazonaws.com"
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "service_assume_role" {
  for_each = local.service_principals

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [each.value]
    }
  }
}

data "aws_iam_policy_document" "analytics_reader_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.analytics_reader_trusted_principal_arn]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name_prefix}-lambda"
  assume_role_policy = data.aws_iam_policy_document.service_assume_role["lambda"].json
  tags               = var.tags
}

resource "aws_iam_role" "firehose" {
  name               = "${var.name_prefix}-firehose"
  assume_role_policy = data.aws_iam_policy_document.service_assume_role["firehose"].json
  tags               = var.tags
}

resource "aws_iam_role" "glue" {
  name               = "${var.name_prefix}-glue"
  assume_role_policy = data.aws_iam_policy_document.service_assume_role["glue"].json
  tags               = var.tags
}

resource "aws_iam_role" "redshift" {
  name               = "${var.name_prefix}-redshift"
  assume_role_policy = data.aws_iam_policy_document.service_assume_role["redshift"].json
  tags               = var.tags
}

resource "aws_iam_role" "analytics_reader" {
  name               = "${var.name_prefix}-analytics-reader"
  assume_role_policy = data.aws_iam_policy_document.analytics_reader_assume_role.json
  tags               = var.tags
}

locals {
  data_lake_role_ids = {
    lambda           = aws_iam_role.lambda.id
    firehose         = aws_iam_role.firehose.id
    glue             = aws_iam_role.glue.id
    redshift         = aws_iam_role.redshift.id
    analytics_reader = aws_iam_role.analytics_reader.id
  }

  data_lake_kms_actions = {
    lambda           = ["kms:Decrypt", "kms:DescribeKey"]
    firehose         = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    glue             = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    redshift         = ["kms:Decrypt", "kms:DescribeKey"]
    analytics_reader = ["kms:Decrypt", "kms:DescribeKey"]
  }

  firehose_kinesis_stream_arn = "arn:aws:kinesis:${var.aws_region}:${data.aws_caller_identity.current.account_id}:stream/${var.name_prefix}-events"
  lambda_dlq_arn              = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.name_prefix}-manifest-dlq"
  lambda_glue_job_arn         = "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:job/${var.name_prefix}-raw-to-clean"
  lambda_log_group_arn        = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}-manifest-validator"

  athena_workgroup_arn   = "arn:aws:athena:${var.aws_region}:${data.aws_caller_identity.current.account_id}:workgroup/${var.name_prefix}-analytics"
  glue_catalog_arn       = "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:catalog"
  analytics_database_arn = "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:database/music_analytics"
  analytics_tables_arn   = "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/music_analytics/*"
}

data "aws_iam_policy_document" "data_lake_access" {
  for_each = {
    lambda = {
      actions = ["s3:GetObject"]
      paths   = ["raw/*"]
    }
    firehose = {
      actions = ["s3:PutObject", "s3:AbortMultipartUpload"]
      paths   = ["raw/*"]
    }
    glue = {
      actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      paths   = ["raw/*", "clean/*", "analytics/*", "quarantine/*"]
    }
    redshift = {
      actions = ["s3:GetObject"]
      paths   = ["analytics/*"]
    }
    analytics_reader = {
      actions = ["s3:GetObject"]
      paths   = ["analytics/*"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = concat(each.value.actions, ["s3:ListBucket"])
    resources = concat([var.data_lake_bucket_arn], [for path in each.value.paths : "${var.data_lake_bucket_arn}/${path}"])
  }

  statement {
    effect    = "Allow"
    actions   = local.data_lake_kms_actions[each.key]
    resources = [var.data_lake_kms_key_arn]
  }

  dynamic "statement" {
    for_each = each.key == "firehose" ? [true] : []

    content {
      effect = "Allow"
      # Firehose with a Kinesis stream source must read the stream, not just describe it.
      actions = [
        "kinesis:DescribeStream",
        "kinesis:GetShardIterator",
        "kinesis:GetRecords",
        "kinesis:ListShards",
      ]
      resources = [local.firehose_kinesis_stream_arn]
    }
  }

  dynamic "statement" {
    for_each = each.key == "lambda" ? [true] : []

    content {
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [local.lambda_dlq_arn]
    }
  }

  dynamic "statement" {
    for_each = each.key == "lambda" ? [true] : []

    content {
      effect    = "Allow"
      actions   = ["glue:StartJobRun"]
      resources = [local.lambda_glue_job_arn]
    }
  }

  dynamic "statement" {
    for_each = each.key == "lambda" ? [true] : []

    content {
      effect = "Allow"
      actions = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      resources = ["${local.lambda_log_group_arn}:*"]
    }
  }

  dynamic "statement" {
    for_each = each.key == "glue" ? [true] : []

    content {
      effect  = "Allow"
      actions = ["s3:PutObject", "s3:DeleteObject"]
      # The EMR filesystem used by Glue writes top-level directory markers
      # (e.g. clean_$folder$) that do not match the "<zone>/*" object patterns.
      resources = [
        for zone in ["clean", "analytics", "quarantine"] :
        "${var.data_lake_bucket_arn}/${zone}_$folder$"
      ]
    }
  }

  # The analytics reader queries the analytics zone through Athena. Data
  # authorization is governed by Lake Formation (SELECT on analytics only,
  # nothing on raw); these statements grant the matching API access. Glue
  # catalog access is scoped to the analytics database so raw stays denied.
  dynamic "statement" {
    for_each = each.key == "analytics_reader" ? [true] : []

    content {
      effect = "Allow"
      actions = [
        "athena:StartQueryExecution",
        "athena:StopQueryExecution",
        "athena:GetQueryExecution",
        "athena:GetQueryResults",
        "athena:GetWorkGroup",
      ]
      resources = [local.athena_workgroup_arn]
    }
  }

  dynamic "statement" {
    for_each = each.key == "analytics_reader" ? [true] : []

    content {
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:PutObject"]
      resources = ["${var.data_lake_bucket_arn}/athena-results/*"]
    }
  }

  dynamic "statement" {
    for_each = each.key == "analytics_reader" ? [true] : []

    content {
      # Athena verifies the workgroup result bucket before running a query.
      effect    = "Allow"
      actions   = ["s3:GetBucketLocation"]
      resources = [var.data_lake_bucket_arn]
    }
  }

  dynamic "statement" {
    for_each = each.key == "analytics_reader" ? [true] : []

    content {
      effect = "Allow"
      actions = [
        "glue:GetDatabase",
        "glue:GetTable",
        "glue:GetTables",
        "glue:GetPartition",
        "glue:GetPartitions",
      ]
      resources = [local.glue_catalog_arn, local.analytics_database_arn, local.analytics_tables_arn]
    }
  }

  dynamic "statement" {
    for_each = each.key == "analytics_reader" ? [true] : []

    content {
      effect    = "Allow"
      actions   = ["lakeformation:GetDataAccess"]
      resources = ["*"]
    }
  }
}

resource "aws_iam_role_policy" "data_lake_access" {
  for_each = data.aws_iam_policy_document.data_lake_access

  name   = "${var.name_prefix}-${replace(each.key, "_", "-")}-data-lake"
  role   = local.data_lake_role_ids[each.key]
  policy = each.value.json
}
