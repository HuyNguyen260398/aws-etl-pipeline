# Dev acceptance execution runbook

## Purpose

Execute the remaining deployed acceptance work for the Music Streaming ETL pipeline and collect evidence for Task 12.

## Prerequisites

- The `dev` Terraform stack has valid account-specific values in an ignored `terraform/environments/dev/terraform.tfvars` file or CI variables.
- The Redshift administrator secret exists in Secrets Manager.
- The QuickSight feature remains disabled unless the account is subscribed and its opt-in variables are configured.
- The operator has AWS permissions to deploy, invoke Glue, use Kinesis, query Athena and Redshift, inspect CloudWatch, and assume the analytics-reader role.

## Step 1: Deploy the dev stack

1. Initialize Terraform with the approved remote-state backend configuration.
2. Run a reviewed Terraform plan using the real dev inputs.
3. Apply the saved plan only after confirming its resources and cost implications.
4. Record the Terraform commit SHA, plan timestamp, AWS account, region, and apply output.

Stop if Terraform reports an unexpected replacement, public exposure, missing permission, or cost-sensitive resource outside the approved plan.

## Step 2: Apply analytics SQL

1. Execute `sql/redshift/001_schema.sql` against the deployed Redshift Serverless workgroup.
2. Execute `sql/redshift/003_dashboard_views.sql` after the schema is available.
3. Use `sql/redshift/002_merge_fact_stream.sql` only with the deployed data-lake bucket and Redshift role values substituted through the approved deployment process.
4. Record statement IDs, execution status, and errors without recording secret values.

Stop if the Redshift role cannot read the analytics Parquet zone or if the merge is not idempotent.

## Step 3: Configure acceptance environment

Export the runner’s required variables:

```bash
export AWS_REGION="ap-southeast-1"
export DATA_LAKE_BUCKET="<deployed-data-lake-bucket>"
export ATHENA_WORKGROUP="<deployed-athena-workgroup>"
export REDSHIFT_WORKGROUP="<deployed-redshift-workgroup>"
export TEST_ROLE_ARN="<analytics-reader-role-arn>"
```

Export the additional integration-test inputs:

```bash
export KINESIS_STREAM_NAME="<deployed-kinesis-stream>"
export GLUE_RAW_TO_CLEAN_JOB_NAME="<deployed-raw-to-clean-job>"
export REDSHIFT_SECRET_ARN="<redshift-admin-secret-arn>"
```

Confirm the current operator can assume `TEST_ROLE_ARN`. Never export, print, or commit secret values.

## Step 4: Run acceptance tests

1. Confirm the required-variable guard first:

```bash
env -u AWS_REGION scripts/run_acceptance.sh
```

Expected result: nonzero exit with `AWS_REGION must be set.`

2. Run the deployed integration tests:

```bash
python -m pytest tests/e2e/test_pipeline.py -m integration -v
```

The tests verify batch-manifest and Kinesis delivery, Glue completion, clean/analytics Parquet output, Athena and Redshift visibility, quarantine behavior, and analytics-reader denial of raw data.

Stop and investigate if any test fails. Preserve raw, quarantine, DLQ, and CloudWatch evidence before retrying.

## Step 5: Capture acceptance evidence

Record the following in `docs/operations/acceptance-evidence.md` or the approved evidence store:

- Git commit SHA, run timestamp, AWS account, and region.
- Raw object keys, Kinesis sequence number, Glue run IDs, clean and analytics Parquet keys.
- Athena query execution IDs and Redshift Data API statement IDs.
- Quarantine key and validation reason for the invalid record.
- Analytics-reader assumed-role ARN and raw-query access-denied evidence.
- Resource tags and CloudWatch alarm states before and after the run.
- Any incident, remediation, retry, and final outcome.

## Completion criteria

The deployed acceptance task is complete only when all integration assertions pass, the analytics-reader denial is evidenced, operational/cost evidence is captured, and no unresolved alarm or security finding remains.
