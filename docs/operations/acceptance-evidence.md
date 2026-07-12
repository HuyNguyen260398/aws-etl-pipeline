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

## Step 3 acceptance-environment preflight

- Region: `ap-southeast-1`; data-lake bucket: `music-etl-dev-datalake-010382427026-ap-southeast-1`.
- Athena workgroup and Redshift Serverless workgroup: `music-etl-dev-analytics`.
- Kinesis stream: `music-etl-dev-events`; raw-to-clean Glue job: `music-etl-dev-raw-to-clean`.
- The analytics-reader role assumption succeeded as `arn:aws:sts::010382427026:assumed-role/music-etl-dev-analytics-reader/acceptance-preflight`.
- The Redshift administrator secret ARN is supplied only at runtime and is not recorded here.

## Step 4 acceptance run

- Result: `tests/e2e/test_pipeline.py -m integration` — **6 passed in 234.77s**.
- Run completed: `2026-07-12T07:12Z` (`ap-southeast-1`, account `010382427026`).
- Pipeline code under test: commit `1c08fd4` (final fix); documentation HEAD `873f181` (docs-only delta).
- Tests: batch ingestion, Kinesis ingestion, clean/analytics Parquet presence, Athena+Redshift merged-event visibility, invalid-record quarantine, analytics-reader raw denial.

## Functional evidence

- Raw object keys:
  - `raw/source=acceptance/ingest_date=2026-07-12/manifest.json` (+ `events.json`)
  - `raw/source=kinesis/ingest_date=2026-07-12/music-etl-dev-raw-delivery-1-2026-07-12-07-10-08-b2e3ad37-...gz` (Firehose delivery from the Kinesis stream)
- Glue run IDs (final run):
  - raw-to-clean (batch): `jr_cbb401d7e7c79adc21ca497e5c369aa90a44984d5817559c65773ac0fb177ebb`
  - raw-to-clean (kinesis): `jr_4e6ec072c0fe2b1bcb173ae4ec01418ab031273f6c9937969db4ca478666952e`
  - raw-to-clean (invalid): `jr_318f9d6bd4f4beb3fc479c44ffa1249995058580aab68f79f8caaeb6475f48a5`
  - clean-to-analytics: `jr_b7843731f446c252bc248f5e699adf14cc7073405b5744dbf5fa43e3d34bb974`
- Parquet keys:
  - clean: `clean/ingest_date=2026-07-12/part-00000-db6ee2c0-80fd-4ad8-a405-7428e46444a7.c000.snappy.parquet`
  - analytics: `analytics/fact_stream/part-00001-f27686c0-9870-47a3-abb8-797a07b60097-c000.snappy.parquet`
- Athena: execution `cbbbc7ea-fa6c-4d3b-af29-de02b5720933`, `SELECT COUNT(*) FROM music_analytics.fact_stream` → `2` (SUCCEEDED).
- Redshift Data API: statement `bfc5c9f7-6046-4e84-8cf9-72497c44f823`, `SELECT COUNT(*) FROM analytics.fact_stream` → `2` (FINISHED). Merge `002_merge_fact_stream.sql` verified idempotent (count stable at 2 across re-runs).
- Kinesis: individual sequence number not retained by the test; delivery confirmed by the `raw/source=kinesis/...gz` object above.

## Permission evidence

- Analytics-reader assumed role: `arn:aws:sts::010382427026:assumed-role/music-etl-dev-analytics-reader/acceptance-evidence`.
- Attempted raw-zone query: Athena execution `011b6f3a-3fc9-4d3f-ba7b-f2c9af82194c`, `SELECT COUNT(*) FROM music_raw.events` → **FAILED**.
- Denial reason: `not authorized to perform: glue:GetDatabase on resource: .../database/music_raw` — the reader's Glue/Lake Formation grants are scoped to `music_analytics` only, so raw remains inaccessible. No secret or session credentials recorded.

## Cost and operational evidence

- Resource tags (S3 lake, Glue jobs, Redshift workgroup, Athena workgroup): `Project=music-etl`, `Environment=dev`, `Region=ap-southeast-1`, `Owner=huy`, `ManagedBy=Terraform`, `CostCenter=development`.
- CloudWatch alarms — all `OK` before and after the run: `athena-bytes-scanned`, `dlq-depth`, `firehose-delivery-failure`, `glue-failed`, `glue-timeout`, `kinesis-iterator-age`, `lambda-errors`, `lambda-throttles`, `redshift-capacity`, `redshift-errors`.
- `terraform plan` after the run: **No changes** (deployed stack matches the committed configuration; no drift).

## Failure evidence

- Rejected record: invalid event with the required `event_id` field removed, ingested under `raw/source=acceptance-invalid/ingest_date=2026-07-12/invalid.json`.
- Processed by raw-to-clean run `jr_318f9d6bd4f4beb3fc479c44ffa1249995058580aab68f79f8caaeb6475f48a5` (SUCCEEDED).
- Quarantine object: `quarantine/part-00001-c90ef5c6-aa0a-4744-99ba-27c989136e13-c000.snappy.parquet` (`2026-07-12T07:12Z`).
- Validation reason: a required column (`event_id`) was null/blank, so the row was routed to quarantine with `run_id` and `quarantined_at` metadata. Raw data preserved; no DLQ message (DLQ is for manifest-validation failures, not record-level rejections).
