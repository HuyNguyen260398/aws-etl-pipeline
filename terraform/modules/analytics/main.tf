data "aws_secretsmanager_secret_version" "redshift_admin" {
  secret_id = var.redshift_admin_secret_arn
}

locals {
  redshift_admin = jsondecode(data.aws_secretsmanager_secret_version.redshift_admin.secret_string)
}

resource "aws_athena_workgroup" "analytics" {
  name = "${var.name_prefix}-analytics"

  # Allow terraform destroy to remove the workgroup with its query history.
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = var.athena_bytes_scanned_cutoff_per_query

    result_configuration {
      output_location = "s3://${var.data_lake_bucket_name}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = var.data_lake_kms_key_arn
      }
    }
  }

  tags = var.tags
}

resource "aws_redshiftserverless_namespace" "analytics" {
  namespace_name      = "${var.name_prefix}-analytics"
  admin_username      = local.redshift_admin.username
  admin_user_password = local.redshift_admin.password
  db_name             = "music_analytics"
  iam_roles           = [var.redshift_role_arn]
  kms_key_id          = var.data_lake_kms_key_arn

  lifecycle {
    precondition {
      condition     = can(local.redshift_admin.username) && can(local.redshift_admin.password)
      error_message = "redshift_admin_secret_arn must reference JSON with username and password keys."
    }
  }

  tags = var.tags
}

resource "aws_redshiftserverless_workgroup" "analytics" {
  workgroup_name      = "${var.name_prefix}-analytics"
  namespace_name      = aws_redshiftserverless_namespace.analytics.namespace_name
  base_capacity       = var.redshift_base_capacity
  publicly_accessible = false
  security_group_ids  = var.security_group_ids
  subnet_ids          = var.subnet_ids

  tags = var.tags
}
