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
