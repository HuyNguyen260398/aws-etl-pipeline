output "lambda_log_group_name" { value = aws_cloudwatch_log_group.lambda.name }
output "raw_to_clean_log_group_name" { value = aws_cloudwatch_log_group.raw_to_clean.name }
output "clean_to_analytics_log_group_name" { value = aws_cloudwatch_log_group.clean_to_analytics.name }
output "dashboard_name" { value = aws_cloudwatch_dashboard.pipeline.dashboard_name }
