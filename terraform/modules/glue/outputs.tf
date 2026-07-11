output "raw_to_clean_job_name" { value = aws_glue_job.raw_to_clean.name }
output "clean_to_analytics_job_name" { value = aws_glue_job.clean_to_analytics.name }
output "security_configuration_name" { value = aws_glue_security_configuration.this.name }
