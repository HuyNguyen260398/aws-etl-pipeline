variable "aws_region" {
  description = "AWS deployment region."
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must use an AWS region format, for example ap-southeast-1."
  }
}

variable "aws_profile" {
  description = "Optional AWS CLI profile. Leave empty to use the default credential chain."
  type        = string
  default     = ""
}

variable "assume_role_arn" {
  description = "Optional IAM role ARN for Terraform to assume."
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Lowercase project identifier."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project_name))
    error_message = "project_name must be 3-31 lowercase letters, digits, or hyphens and begin with a letter."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "Only dev is supported in the initial implementation."
  }
}

variable "common_tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
