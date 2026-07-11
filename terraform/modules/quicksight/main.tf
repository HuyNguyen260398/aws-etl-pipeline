data "aws_caller_identity" "current" {}

data "aws_secretsmanager_secret_version" "redshift_admin" {
  count     = var.quicksight_enabled ? 1 : 0
  secret_id = var.redshift_admin_secret_arn
}

locals {
  redshift_admin = var.quicksight_enabled ? jsondecode(data.aws_secretsmanager_secret_version.redshift_admin[0].secret_string) : null
}

resource "aws_quicksight_vpc_connection" "redshift" {
  count = var.quicksight_enabled ? 1 : 0

  aws_account_id     = data.aws_caller_identity.current.account_id
  vpc_connection_id  = "${var.name_prefix}-redshift"
  name               = "${var.name_prefix}-redshift"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = var.security_group_ids
  role_arn           = var.quicksight_vpc_connection_role_arn
}

resource "aws_quicksight_data_source" "redshift" {
  count = var.quicksight_enabled ? 1 : 0

  aws_account_id = data.aws_caller_identity.current.account_id
  data_source_id = "${var.name_prefix}-redshift"
  name           = "${var.name_prefix}-redshift"
  type           = "REDSHIFT"

  parameters {
    redshift {
      cluster_id = var.redshift_workgroup_name
      database   = var.redshift_database_name
    }
  }

  vpc_connection_properties {
    vpc_connection_arn = aws_quicksight_vpc_connection.redshift[0].arn
  }

  credentials {
    credential_pair {
      username = local.redshift_admin.username
      password = local.redshift_admin.password
    }
  }
}

resource "aws_quicksight_data_set" "dashboard" {
  count = var.quicksight_enabled ? 1 : 0

  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = "${var.name_prefix}-dashboard"
  name           = "${var.name_prefix}-dashboard"
  import_mode    = "SPICE"

  physical_table_map {
    physical_table_map_id = "dashboardevents"

    relational_table {
      data_source_arn = aws_quicksight_data_source.redshift[0].arn
      schema          = "analytics"
      name            = "vw_dashboard_events"
      input_columns {
        name = "event_id"
        type = "STRING"
      }
      input_columns {
        name = "user_id"
        type = "STRING"
      }
      input_columns {
        name = "track_id"
        type = "STRING"
      }
      input_columns {
        name = "artist_id"
        type = "STRING"
      }
      input_columns {
        name = "played_at"
        type = "DATETIME"
      }
      input_columns {
        name = "duration_seconds"
        type = "INTEGER"
      }
      input_columns {
        name = "platform"
        type = "STRING"
      }
      input_columns {
        name = "ingest_date"
        type = "DATETIME"
      }
      input_columns {
        name = "is_skip"
        type = "INTEGER"
      }
    }
  }

  permissions {
    principal = var.quicksight_principal_arn
    actions = [
      "quicksight:DescribeDataSet",
      "quicksight:DescribeDataSetPermissions",
      "quicksight:PassDataSet",
      "quicksight:DescribeIngestion",
      "quicksight:ListIngestions",
      "quicksight:UpdateDataSet",
      "quicksight:DeleteDataSet",
      "quicksight:CreateIngestion",
      "quicksight:CancelIngestion",
    ]
  }
}

resource "aws_quicksight_refresh_schedule" "dashboard" {
  count = var.quicksight_enabled ? 1 : 0

  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = aws_quicksight_data_set.dashboard[0].data_set_id
  schedule_id    = "${var.name_prefix}-dashboard-refresh"

  schedule {
    refresh_type = "FULL_REFRESH"

    schedule_frequency {
      interval        = var.quicksight_refresh_schedule
      time_of_the_day = "02:00"
      timezone        = "Asia/Singapore"
    }
  }
}
