# Acceptance evidence

## Preconditions

Deploy the dev stack first. Export the runner’s required values: `AWS_REGION`, `DATA_LAKE_BUCKET`, `ATHENA_WORKGROUP`, `REDSHIFT_WORKGROUP`, and `TEST_ROLE_ARN`. The integration tests additionally require `KINESIS_STREAM_NAME`, `GLUE_RAW_TO_CLEAN_JOB_NAME`, and `REDSHIFT_SECRET_ARN`.

## Step 1 deployment record

- Deployment completed: `2026-07-11T23:47:26Z`
- Terraform source baseline: `e1485459c68faa18aedc19459ef559b7b7c19ec6`
- AWS account and region: `010382427026`, `ap-southeast-1`
- Final reconciliation: `terraform plan -detailed-exitcode` returned `No changes.`
- Apply result: the final reconciliation added 18 resources, updated the data-lake KMS policy, and destroyed no resources.
- Remediation recorded in this checkpoint: single-owner Glue-to-Redshift egress, scoped Firehose Kinesis read access, scoped Lambda DLQ send access, Lake Formation catalog-admin bootstrap, and scoped CloudWatch Logs KMS access.

## Step 2 Redshift SQL record

- Workgroup and database: `music-etl-dev-analytics`, `music_analytics`
- `sql/redshift/001_schema.sql`: statement `73aca30e-2c67-401a-9fcd-5cad84111175`, status `FINISHED`, error `null`.
- `sql/redshift/003_dashboard_views.sql`: statement `331e35fd-7159-4f89-b134-ba016d7a77d5`, status `FINISHED`, error `null`.
- `sql/redshift/002_merge_fact_stream.sql` was intentionally not run: it requires deployed analytics Parquet input and the approved runtime substitution of the bucket and Redshift-role values.

## Functional evidence

Record the acceptance run timestamp, Git commit, raw object keys, Glue run IDs, clean/analytics Parquet keys, Athena query execution IDs/results, and Redshift Data API statement IDs/results. Capture the invalid-record quarantine key and the Kinesis sequence number.

## Permission evidence

Capture the analytics-reader assumed-role ARN, Athena execution ID, and final access-denied reason for the attempted raw-zone query. Do not capture secret values or session credentials.

## Cost and operational evidence

Capture resource tags for the S3 lake, Glue jobs, Redshift workgroup, and Athena workgroup. Record CloudWatch alarm states for Lambda, Glue, Kinesis, Firehose, DLQ, Redshift, and Athena before and after the run. Attach dashboard screenshots or exported metric data with the acceptance timestamp.

## Failure evidence

For a rejected record, retain the source object key, Glue run ID, quarantine object key, validation reason, and any DLQ message ID. Preserve raw data; do not delete quarantine evidence during acceptance.
