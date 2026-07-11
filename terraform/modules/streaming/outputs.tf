output "validator_lambda_arn" { value = aws_lambda_function.validator.arn }
output "kinesis_stream_name" { value = aws_kinesis_stream.this.name }
