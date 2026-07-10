locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(var.common_tags, {
    ManagedBy   = "Terraform"
    Project     = var.project_name
    Environment = var.environment
    Region      = var.aws_region
  })
}
