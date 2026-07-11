data "archive_file" "validator" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = "${path.module}/validator.zip"
}

resource "aws_kinesis_stream" "this" {
  name = "${var.name_prefix}-events"
  stream_mode_details { stream_mode = "ON_DEMAND" }
  encryption_type = "KMS"
  kms_key_id      = var.kms_key_arn
  tags            = var.tags
}

resource "aws_sqs_queue" "dlq" {
  name              = "${var.name_prefix}-manifest-dlq"
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

resource "aws_lambda_function" "validator" {
  function_name    = "${var.name_prefix}-manifest-validator"
  role             = var.lambda_role_arn
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.validator.output_path
  source_code_hash = data.archive_file.validator.output_base64sha256
  timeout          = 60
  environment { variables = { GLUE_JOB_NAME = var.glue_job_name } }
  dead_letter_config { target_arn = aws_sqs_queue.dlq.arn }
  tags = var.tags
}

resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowS3ManifestInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.validator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.data_lake_bucket_arn
}

resource "aws_kinesis_firehose_delivery_stream" "raw" {
  name        = "${var.name_prefix}-raw-delivery"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.this.arn
    role_arn           = var.firehose_role_arn
  }
  extended_s3_configuration {
    role_arn            = var.firehose_role_arn
    bucket_arn          = var.data_lake_bucket_arn
    prefix              = "raw/source=kinesis/ingest_date=!{timestamp:yyyy-MM-dd}/"
    error_output_prefix = "quarantine/source=kinesis/errors/!{firehose:error-output-type}/"
    buffering_size      = 5
    buffering_interval  = 60
    compression_format  = "GZIP"
    kms_key_arn         = var.kms_key_arn
  }
  tags = var.tags
}
