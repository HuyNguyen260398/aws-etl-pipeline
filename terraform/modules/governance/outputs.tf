output "raw_database_name" { value = aws_glue_catalog_database.raw.name }
output "clean_database_name" { value = aws_glue_catalog_database.clean.name }
output "analytics_database_name" { value = aws_glue_catalog_database.analytics.name }
