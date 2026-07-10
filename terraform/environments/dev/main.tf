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

  name_prefix                        = module.common.name_prefix
  aws_region                         = var.aws_region
  vpc_cidr                           = var.vpc_cidr
  private_subnet_cidrs               = var.private_subnet_cidrs
  nat_public_subnet_cidr             = var.nat_public_subnet_cidr
  s3_endpoint_allowed_bucket_arns    = var.s3_endpoint_allowed_bucket_arns
  s3_endpoint_allowed_principal_arns = var.s3_endpoint_allowed_principal_arns
  enable_nat_gateway                 = var.enable_nat_gateway
  flow_log_retention_days            = var.flow_log_retention_days
  flow_log_kms_key_id                = var.flow_log_kms_key_id
  tags                               = module.common.tags
}
