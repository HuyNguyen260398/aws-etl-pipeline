resource "aws_lakeformation_resource" "data_lake" {
  arn                     = var.data_lake_bucket_arn
  use_service_linked_role = true
}

resource "aws_glue_catalog_database" "raw" {
  name         = "${var.catalog_name_prefix}_raw"
  location_uri = "s3://${var.data_lake_bucket_name}/raw/"
  parameters   = { zone = "raw" }
}

resource "aws_glue_catalog_database" "clean" {
  name         = "${var.catalog_name_prefix}_clean"
  location_uri = "s3://${var.data_lake_bucket_name}/clean/"
  parameters   = { zone = "clean" }
}

resource "aws_glue_catalog_database" "analytics" {
  name         = "${var.catalog_name_prefix}_analytics"
  location_uri = "s3://${var.data_lake_bucket_name}/analytics/"
  parameters   = { zone = "analytics" }
}

resource "aws_lakeformation_lf_tag" "zone" {
  key    = "zone"
  values = ["raw", "clean", "analytics"]
}

resource "aws_lakeformation_permissions" "glue_data_location" {
  principal   = var.glue_role_arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = aws_lakeformation_resource.data_lake.arn
  }
}

resource "aws_lakeformation_permissions" "analytics_reader" {
  principal   = var.analytics_reader_role_arn
  permissions = ["DESCRIBE"]

  database { name = aws_glue_catalog_database.analytics.name }
}

resource "aws_lakeformation_permissions" "analytics_reader_tables" {
  principal   = var.analytics_reader_role_arn
  permissions = ["SELECT", "DESCRIBE"]

  table {
    database_name = aws_glue_catalog_database.analytics.name
    wildcard      = true
  }
}
