output "data_lake_bucket_name" { value = aws_s3_bucket.data_lake.id }
output "data_lake_bucket_arn" { value = aws_s3_bucket.data_lake.arn }
output "glue_assets_bucket_name" { value = aws_s3_bucket.glue_assets.id }
output "glue_assets_bucket_arn" { value = aws_s3_bucket.glue_assets.arn }
output "data_lake_kms_key_arn" { value = aws_kms_key.data_lake.arn }

output "zone_prefixes" {
  value = {
    raw            = "raw/"
    clean          = "clean/"
    analytics      = "analytics/"
    quarantine     = "quarantine/"
    athena_results = "athena-results/"
    glue_assets    = "glue-assets/"
  }
}
