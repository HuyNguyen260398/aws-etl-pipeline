# Music ETL storage layout

The platform uses two encrypted, versioned S3 buckets that share one KMS key and enforce TLS-only bucket policies: a **data-lake bucket** for pipeline data and a separate **glue-assets bucket** for job code and scratch space. Source data is immutable in the raw zone; downstream jobs write new data to clean and analytics zones.

## Data-lake bucket

| Zone | Prefix | Purpose |
|---|---|---|
| Raw | `raw/` | Original Kaggle files and Kinesis deliveries; never mutated. |
| Clean | `clean/` | Validated, deduplicated Parquet records. |
| Analytics | `analytics/` | BI-ready fact and dimension datasets. |
| Quarantine | `quarantine/` | Invalid records and data-quality evidence. |
| Athena results | `athena-results/` | Encrypted query result objects. |

## Glue-assets bucket

| Prefix | Purpose |
|---|---|
| `glue-assets/scripts/` | Glue PySpark job scripts uploaded by Terraform. |
| `glue-assets/libraries/` | Packaged quality library (`quality-library.zip`). |
| `glue-assets/temporary/` | Glue `--TempDir` scratch space (lifecycle-expired). |

## Manifest contract

Only a completed raw partition manifest can start event-driven processing. For example:

```text
raw/source=kaggle/ingest_date=2026-07-10/manifest.json
```

The Task 005 Lambda ARN is supplied to the data-lake module as `manifest_notification_lambda_arn`. Its S3 notification filters on the `raw/` prefix and `manifest.json` suffix, preventing every individual uploaded record from triggering a job.

## Observability

Pipeline monitoring lives in the observability module: CloudWatch log groups for the validator Lambda, both Glue jobs, and Redshift Serverless, plus metric filters, alarms, and a dashboard. Object-level S3 audit via CloudTrail data events is **not** currently provisioned; if audit-grade access logging is required, add it as a follow-up and document the trail destination and retention here.
