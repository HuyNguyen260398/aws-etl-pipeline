locals {
  service_principals = {
    lambda   = "lambda.amazonaws.com"
    firehose = "firehose.amazonaws.com"
    glue     = "glue.amazonaws.com"
    redshift = "redshift.amazonaws.com"
  }
}

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

data "aws_iam_policy_document" "github_oidc_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main"]
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

resource "aws_iam_role" "github_oidc" {
  name               = "${var.name_prefix}-github-oidc"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role.json
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
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.data_lake_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "data_lake_access" {
  for_each = data.aws_iam_policy_document.data_lake_access

  name   = "${var.name_prefix}-${replace(each.key, "_", "-")}-data-lake"
  role   = local.data_lake_role_ids[each.key]
  policy = each.value.json
}
