variable "aws_region" {
  description = "AWS region for bootstrap resources."
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must use an AWS region format, for example ap-southeast-1."
  }
}

variable "aws_profile" {
  description = "Optional AWS CLI profile name. Leave empty to use the default credential chain."
  type        = string
  default     = ""
}

variable "assume_role_arn" {
  description = "Optional IAM role ARN for Terraform to assume."
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Lowercase project identifier used in tags and resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project_name))
    error_message = "project_name must be 3-31 lowercase letters, digits, or hyphens and begin with a letter."
  }
}

variable "environment" {
  description = "Deployment environment for the bootstrap state resources."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "Only the dev environment is in scope for this repository."
  }
}

variable "terraform_state_bucket" {
  description = "Globally unique S3 bucket name for Terraform remote state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.terraform_state_bucket))
    error_message = "terraform_state_bucket must be a valid 3-63 character S3 bucket name."
  }
}

variable "terraform_lock_table" {
  description = "DynamoDB table name used by the Terraform S3 backend lockfile configuration."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{3,255}$", var.terraform_lock_table))
    error_message = "terraform_lock_table must be a valid DynamoDB table name."
  }
}

variable "common_tags" {
  description = "Tags applied to every bootstrap resource."
  type        = map(string)
  default     = {}
}

variable "state_noncurrent_version_expiration_days" {
  description = "Days to retain non-current Terraform state object versions."
  type        = number
  default     = 90

  validation {
    condition     = var.state_noncurrent_version_expiration_days >= 30
    error_message = "state_noncurrent_version_expiration_days must be at least 30 days."
  }
}
