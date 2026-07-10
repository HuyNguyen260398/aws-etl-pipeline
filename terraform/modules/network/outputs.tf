output "vpc_id" { value = aws_vpc.this.id }
output "private_subnet_ids" { value = [for subnet in aws_subnet.private : subnet.id] }
output "glue_security_group_id" { value = aws_security_group.glue.id }
output "redshift_security_group_id" { value = aws_security_group.redshift.id }
output "s3_vpc_endpoint_id" { value = aws_vpc_endpoint.s3.id }
