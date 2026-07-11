output "data_source_arn" {
  value = try(aws_quicksight_data_source.redshift[0].arn, null)
}

output "data_set_arn" {
  value = try(aws_quicksight_data_set.dashboard[0].arn, null)
}
