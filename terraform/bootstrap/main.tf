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
    tags = merge(var.common_tags, {
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Environment = var.environment
    })
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "terraform_state_kms" {
  statement {
    sid    = "EnableRootAccountPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket
}

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state and lock-table encryption."
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.terraform_state_kms.json
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/${var.project_name}-${var.environment}-terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.state_noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = var.terraform_lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.terraform_state.arn
  }
}
