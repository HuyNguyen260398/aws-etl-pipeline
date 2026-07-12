output "lambda_role_arn" { value = aws_iam_role.lambda.arn }
output "firehose_role_arn" { value = aws_iam_role.firehose.arn }
output "glue_role_arn" { value = aws_iam_role.glue.arn }
output "redshift_role_arn" { value = aws_iam_role.redshift.arn }
output "analytics_reader_role_arn" { value = aws_iam_role.analytics_reader.arn }
