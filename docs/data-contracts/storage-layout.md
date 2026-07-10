# Music ETL storage layout

The data lake uses encrypted, versioned S3 storage with a shared KMS key and strict TLS-only bucket policies. Source data is immutable in the raw zone; downstream jobs write new data to clean and analytics zones.

| Zone | Prefix | Purpose |
|---|---|---|
| Raw | `raw/` | Original Kaggle files and Kinesis deliveries; never mutated. |
| Clean | `clean/` | Validated, deduplicated Parquet records. |
| Analytics | `analytics/` | BI-ready fact and dimension datasets. |
| Quarantine | `quarantine/` | Invalid records and data-quality evidence. |
| Athena results | `athena-results/` | Encrypted query result objects. |
| Glue assets | `glue-assets/` | Glue scripts and permanent job assets. |

## Manifest contract

Only a completed raw partition manifest can start event-driven processing. For example:

```text
raw/source=kaggle/ingest_date=2026-07-10/manifest.json
```

The Task 005 Lambda ARN is supplied to the data-lake module as `manifest_notification_lambda_arn`. Its S3 notification filters on the `raw/` prefix and `manifest.json` suffix, preventing every individual uploaded record from triggering a job.

CloudTrail data events for the two data-lake buckets are enabled with the observability implementation in Task 009, where the audit destination and retention policy are defined.
