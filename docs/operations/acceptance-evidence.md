# Acceptance evidence

## Preconditions

Deploy the dev stack first. Export the runner’s required values: `AWS_REGION`, `DATA_LAKE_BUCKET`, `ATHENA_WORKGROUP`, `REDSHIFT_WORKGROUP`, and `TEST_ROLE_ARN`. The integration tests additionally require `KINESIS_STREAM_NAME`, `GLUE_RAW_TO_CLEAN_JOB_NAME`, and `REDSHIFT_SECRET_ARN`.

## Functional evidence

Record the acceptance run timestamp, Git commit, raw object keys, Glue run IDs, clean/analytics Parquet keys, Athena query execution IDs/results, and Redshift Data API statement IDs/results. Capture the invalid-record quarantine key and the Kinesis sequence number.

## Permission evidence

Capture the analytics-reader assumed-role ARN, Athena execution ID, and final access-denied reason for the attempted raw-zone query. Do not capture secret values or session credentials.

## Cost and operational evidence

Capture resource tags for the S3 lake, Glue jobs, Redshift workgroup, and Athena workgroup. Record CloudWatch alarm states for Lambda, Glue, Kinesis, Firehose, DLQ, Redshift, and Athena before and after the run. Attach dashboard screenshots or exported metric data with the acceptance timestamp.

## Failure evidence

For a rejected record, retain the source object key, Glue run ID, quarantine object key, validation reason, and any DLQ message ID. Preserve raw data; do not delete quarantine evidence during acceptance.
