variable "project_name" {
  description = "Project identifier."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "common_tags" {
  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}
