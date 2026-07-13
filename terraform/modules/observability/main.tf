locals {
  alarm_actions = var.alarm_sns_topic_arn == null ? [] : [var.alarm_sns_topic_arn]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "raw_to_clean" {
  name              = "/aws-glue/jobs/${var.raw_to_clean_job_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "clean_to_analytics" {
  name              = "/aws-glue/jobs/${var.clean_to_analytics_job_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "redshift" {
  name              = "/aws/redshift-serverless/${var.redshift_workgroup_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_metric_filter" "glue_failed" {
  name           = "${var.name_prefix}-glue-failed"
  log_group_name = aws_cloudwatch_log_group.raw_to_clean.name
  pattern        = "FAILED"

  metric_transformation {
    name      = "GlueFailed"
    namespace = "MusicEtl/Pipeline"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "glue_timeout" {
  name           = "${var.name_prefix}-glue-timeout"
  log_group_name = aws_cloudwatch_log_group.raw_to_clean.name
  pattern        = "TIMEOUT"

  metric_transformation {
    name      = "GlueTimeout"
    namespace = "MusicEtl/Pipeline"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "redshift_error" {
  name           = "${var.name_prefix}-redshift-error"
  log_group_name = aws_cloudwatch_log_group.redshift.name
  pattern        = "ERROR"

  metric_transformation {
    name      = "RedshiftErrors"
    namespace = "MusicEtl/Pipeline"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "redshift_capacity" {
  name           = "${var.name_prefix}-redshift-capacity"
  log_group_name = aws_cloudwatch_log_group.redshift.name
  pattern        = "capacity"

  metric_transformation {
    name      = "RedshiftCapacityEvents"
    namespace = "MusicEtl/Pipeline"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.name_prefix}-lambda-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  dimensions          = { FunctionName = var.lambda_function_name }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.name_prefix}-lambda-throttles"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  dimensions          = { FunctionName = var.lambda_function_name }
}

resource "aws_cloudwatch_metric_alarm" "glue_failed" {
  alarm_name          = "${var.name_prefix}-glue-failed"
  namespace           = "MusicEtl/Pipeline"
  metric_name         = aws_cloudwatch_log_metric_filter.glue_failed.metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "glue_timeout" {
  alarm_name          = "${var.name_prefix}-glue-timeout"
  namespace           = "MusicEtl/Pipeline"
  metric_name         = aws_cloudwatch_log_metric_filter.glue_timeout.metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "kinesis_iterator_age" {
  alarm_name          = "${var.name_prefix}-kinesis-iterator-age"
  namespace           = "AWS/Kinesis"
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 60000
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  dimensions          = { StreamName = var.kinesis_stream_name }
}

resource "aws_cloudwatch_metric_alarm" "firehose_delivery_failure" {
  alarm_name          = "${var.name_prefix}-firehose-delivery-failure"
  namespace           = "AWS/Firehose"
  metric_name         = "DeliveryToS3.Success"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  dimensions          = { DeliveryStreamName = var.firehose_delivery_stream_name }
}

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${var.name_prefix}-dlq-depth"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  dimensions          = { QueueName = var.dlq_name }
}

resource "aws_cloudwatch_metric_alarm" "redshift_errors" {
  alarm_name          = "${var.name_prefix}-redshift-errors"
  namespace           = "MusicEtl/Pipeline"
  metric_name         = aws_cloudwatch_log_metric_filter.redshift_error.metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "redshift_capacity" {
  alarm_name          = "${var.name_prefix}-redshift-capacity"
  namespace           = "MusicEtl/Pipeline"
  metric_name         = aws_cloudwatch_log_metric_filter.redshift_capacity.metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "athena_bytes_scanned" {
  alarm_name          = "${var.name_prefix}-athena-bytes-scanned"
  namespace           = "AWS/Athena"
  metric_name         = "ProcessedBytes"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1073741824
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  dimensions          = { WorkGroup = var.athena_workgroup_name }
}

resource "aws_cloudwatch_dashboard" "pipeline" {
  dashboard_name = "${var.name_prefix}-pipeline"
  dashboard_body = jsonencode({
    widgets = [
      { type = "metric", properties = { title = "Lambda Errors and Throttles", view = "timeSeries", region = var.aws_region, metrics = [["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_name], [".", "Throttles", ".", "."]] } },
      { type = "metric", properties = { title = "Kinesis and Firehose", view = "timeSeries", region = var.aws_region, metrics = [["AWS/Kinesis", "GetRecords.IteratorAgeMilliseconds", "StreamName", var.kinesis_stream_name], ["AWS/Firehose", "DeliveryToS3.Success", "DeliveryStreamName", var.firehose_delivery_stream_name]] } },
      { type = "metric", properties = { title = "DLQ and Athena", view = "timeSeries", region = var.aws_region, metrics = [["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_name], ["AWS/Athena", "ProcessedBytes", "WorkGroup", var.athena_workgroup_name]] } },
    ]
  })
}
