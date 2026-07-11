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

variable "vpc_cidr" {
  description = "IPv4 CIDR for the development VPC."
  type        = string
}

variable "private_subnet_cidrs" {
  description = "Exactly two private subnet CIDRs across separate Availability Zones."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "private_subnet_cidrs must contain exactly two CIDRs."
  }
}

variable "nat_public_subnet_cidr" {
  description = "Reserved public subnet CIDR used only when NAT is enabled."
  type        = string
}

variable "s3_endpoint_allowed_bucket_arns" {
  description = "S3 bucket ARNs permitted through the S3 Gateway VPC endpoint."
  type        = list(string)
}

variable "s3_endpoint_allowed_principal_arns" {
  description = "IAM role ARNs permitted to use the S3 Gateway VPC endpoint."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Create a single NAT gateway only when private subnet internet egress is required."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention period for VPC flow logs."
  type        = number
  default     = 30
}

variable "flow_log_kms_key_id" {
  description = "KMS key ID or ARN used to encrypt VPC flow logs."
  type        = string
  default     = "alias/aws/logs"
}

variable "data_lake_bucket_name" {
  description = "Globally unique S3 bucket name for raw, clean, analytics, quarantine, and Athena result prefixes."
  type        = string
}

variable "glue_assets_bucket_name" {
  description = "Globally unique S3 bucket name for Glue scripts and temporary assets."
  type        = string
}

variable "kms_alias_prefix" {
  description = "KMS alias prefix for the data lake encryption key."
  type        = string
}

variable "raw_retention_days" {
  type    = number
  default = 90
}

variable "clean_retention_days" {
  type    = number
  default = 180
}

variable "analytics_retention_days" {
  type    = number
  default = 365
}

variable "glue_assets_retention_days" {
  type    = number
  default = 30
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN in this AWS account."
  type        = string
}

variable "github_repository" {
  description = "GitHub owner/repository allowed to assume the deployment role."
  type        = string
}

variable "analytics_reader_trusted_principal_arn" {
  description = "Principal permitted to assume the analytics reader role."
  type        = string
}

variable "glue_worker_type" {
  description = "Glue worker type for both ETL jobs."
  type        = string
  default     = "G.1X"
}

variable "glue_number_of_workers" {
  description = "Minimum number of Glue workers for the development jobs."
  type        = number
  default     = 2
}

variable "glue_timeout_minutes" {
  description = "Maximum Glue job runtime in minutes."
  type        = number
  default     = 30
}

variable "glue_max_retries" {
  description = "Number of Glue job retries after a failed run."
  type        = number
  default     = 1
}

variable "glue_log_retention_days" {
  description = "CloudWatch retention period for Glue job logs."
  type        = number
  default     = 30
}

variable "glue_version" {
  description = "AWS Glue runtime version used by the ETL jobs."
  type        = string
  default     = "4.0"
}

variable "athena_bytes_scanned_cutoff_per_query" {
  description = "Athena workgroup maximum bytes scanned per query."
  type        = number
  default     = 1073741824
}

variable "redshift_base_capacity" {
  description = "Redshift Serverless base capacity in RPUs."
  type        = number
  default     = 8
}

variable "redshift_admin_secret_arn" {
  description = "Secrets Manager ARN containing Redshift admin username and password JSON."
  type        = string
  sensitive   = true
}

variable "alarm_sns_topic_arn" {
  description = "Optional SNS topic ARN for pipeline alarm notifications."
  type        = string
  default     = null
  nullable    = true
}
