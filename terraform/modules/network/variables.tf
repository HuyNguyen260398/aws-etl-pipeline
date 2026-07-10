variable "name_prefix" { type = string }
variable "aws_region" { type = string }
variable "vpc_cidr" { type = string }
variable "private_subnet_cidrs" { type = list(string) }
variable "nat_public_subnet_cidr" { type = string }
variable "s3_endpoint_allowed_bucket_arns" { type = list(string) }
variable "s3_endpoint_allowed_principal_arns" { type = list(string) }
variable "tags" { type = map(string) }

variable "availability_zone_suffixes" {
  type        = list(string)
  default     = ["a", "b"]
  description = "Availability Zone suffixes matching private_subnet_cidrs."
}

variable "enable_nat_gateway" {
  type        = bool
  default     = false
  description = "Whether to create a single NAT gateway for private subnet internet egress."
}

variable "flow_log_retention_days" {
  type        = number
  default     = 30
  description = "CloudWatch retention for VPC flow logs."
}

variable "flow_log_kms_key_id" {
  type        = string
  default     = "alias/aws/logs"
  description = "KMS key ID or ARN used to encrypt VPC flow logs."
}

variable "redshift_port" {
  type        = number
  default     = 5439
  description = "Redshift Serverless port permitted only from Glue."
}
