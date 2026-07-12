output "athena_workgroup_name" { value = aws_athena_workgroup.analytics.name }
output "redshift_namespace_name" { value = aws_redshiftserverless_namespace.analytics.namespace_name }
output "redshift_workgroup_name" { value = aws_redshiftserverless_workgroup.analytics.workgroup_name }
output "redshift_workgroup_id" { value = aws_redshiftserverless_workgroup.analytics.workgroup_id }
