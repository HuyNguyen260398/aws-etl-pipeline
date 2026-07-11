# Music Streaming Habits dashboard

## Enablement contract

QuickSight is disabled by default through `quicksight_enabled = false`. Enable it only after the account is subscribed to QuickSight, the Redshift Serverless workgroup is deployed, `quicksight_principal_arn` identifies the QuickSight user or group that owns the dataset, and `quicksight_vpc_connection_role_arn` identifies the least-privilege role for the private VPC connection.

The Terraform module creates a private VPC connection, Redshift data source, SPICE dataset, and daily refresh schedule. It reads Redshift credentials from the existing Secrets Manager ARN; no credential value belongs in Terraform variables or source control.

## Dashboard visuals

| Visual | Source view | Configuration |
| --- | --- | --- |
| Daily listening minutes trend | `analytics.vw_daily_listening_minutes` | Line chart: `listening_date` on X, `listening_minutes` as value. |
| Top artists | `analytics.vw_top_artists` | Horizontal bar chart: top 10 `artist_name` by `listening_minutes`. |
| Platform distribution | `analytics.vw_platform_distribution` | Donut chart: `platform` grouped by `event_count`. |
| Skip-rate KPI | `analytics.vw_skip_rate` | KPI: latest `skip_rate`; a skip is a play shorter than 30 seconds. |

Use `analytics.vw_dashboard_events` as the dataset source for drill-through and filters. The aggregate views define the visual contracts and keep calculations consistent.

## Refresh contract

Refresh SPICE only after `002_merge_fact_stream.sql` completes successfully. The configured `quicksight_refresh_schedule` is a fallback daily refresh interval; the orchestration that performs the Redshift merge must trigger or approve the refresh after a successful transaction. A failed or rolled-back merge must not trigger refresh.

## Row-level access mapping

Apply QuickSight row-level security from a separate mapping dataset, not from raw or clean lake zones:

| QuickSight principal | Permitted rows |
| --- | --- |
| `analytics-admins` group | All analytics rows. |
| `business-<platform>` group | Rows where `platform` equals the mapped platform. |
| `regional-<market>` group | Rows matching the mapped market after that dimension is introduced. |

Store the mapping in the analytics zone or a governed Redshift table, grant it only to the QuickSight service role, and test deny-by-default behavior before sharing the dashboard.
