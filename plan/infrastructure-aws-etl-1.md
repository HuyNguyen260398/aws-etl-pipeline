---
goal: Production-oriented, low-cost AWS ETL pipeline for Music Streaming Habits 2026
version: 1.0
date_created: 2026-07-10
last_updated: 2026-07-10
owner: Huy
status: Planned
tags: [infrastructure, terraform, aws, etl, data-lake, ci-cd]
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

This plan creates a single development deployment of a governed batch-and-streaming AWS data pipeline in `ap-southeast-1`. It keeps all requested architectural services while selecting the smallest practical development configuration. Execute tasks in order; make the one commit listed at the end of every task only after its validation passes.

## 1. Requirements & Constraints

- **REQ-001**: Create raw, clean, and analytics S3 lake zones for the Kaggle Music Streaming Habits 2026 data and streaming events.
- **REQ-002**: Include Kinesis Data Streams, Lambda, Glue Catalog/jobs, Athena, Redshift Serverless, QuickSight, Lake Formation, CloudWatch, VPC, and an S3 VPC endpoint.
- **REQ-003**: Implement all AWS infrastructure with Terraform and all delivery automation with GitHub Actions.
- **REQ-004**: Deliver batch CSV and real-time JSON records to analytics-ready Parquet and Redshift tables.
- **SEC-001**: Use encryption, block public S3 access, least-privilege IAM, Lake Formation grants, OIDC CI authentication, and Secrets Manager; do not commit credentials.
- **SEC-002**: Use an S3 Gateway endpoint; set `enable_nat_gateway = false` by default and do not deploy NAT in dev.
- **OPS-001**: Emit structured logs, metrics, alarms, DLQ records, Glue quarantine data, and runbooks.
- **CST-001**: Deploy only `dev`, default `aws_region = "ap-southeast-1"`, Kinesis on-demand, minimal Glue sizing, bounded log retention, Athena scan caps, and low Redshift Serverless capacity.
- **CON-001**: Treat all credentials and environment-specific Terraform configuration as variables or GitHub/AWS secrets; no hard-coded values.
- **CON-002**: Make exactly one conventional Git commit after each TASK completion.
- **GUD-001**: Retain every service in the requested architecture; do not replace it with a different architecture.
- **PAT-001**: Land immutable input in raw, canonical partitioned Parquet in clean, and consumer-ready fact/dimensions in analytics.

## 2. Implementation Steps

### Implementation Phase 1

- **GOAL-001**: Create an executable repository baseline and secure Terraform provider contract.

| Task | Description | Completed | Date |
|---|---|---|---|
| TASK-001 | Create repository tooling, Terraform remote-state contract, variable validation, and dev example values. | | |
| TASK-002 | Create the VPC, private subnets, security groups, and S3 Gateway VPC endpoint with NAT disabled by default. | | |

### Implementation Phase 2

- **GOAL-002**: Implement secured, governed ingestion and data-lake storage.

| Task | Description | Completed | Date |
|---|---|---|---|
| TASK-003 | Create KMS, raw/clean/analytics/quarantine/artifact S3 prefixes, lifecycle policies, and event notifications. | | |
| TASK-004 | Create IAM roles, Glue Catalog databases, Lake Formation locations, LF-tags, and grants. | | |
| TASK-005 | Create Kinesis, Firehose delivery to raw S3, Lambda validation/orchestration, and SQS DLQ. | | |

### Implementation Phase 3

- **GOAL-003**: Implement repeatable ETL, query, and warehouse models.

| Task | Description | Completed | Date |
|---|---|---|---|
| TASK-006 | Add dataset acquisition, deterministic event generation, schema contracts, and test fixtures. | | |
| TASK-007 | Add Glue Spark validation/clean and analytics jobs with bookmarks, Parquet partitions, and quarantine output. | | |
| TASK-008 | Create Athena workgroups/tables and Redshift Serverless namespace/workgroup/schema/load procedures. | | |

### Implementation Phase 4

- **GOAL-004**: Make the pipeline observable and continuously deliverable.

| Task | Description | Completed | Date |
|---|---|---|---|
| TASK-009 | Add CloudWatch dashboards, alarms, metric filters, and operational runbooks. | | |
| TASK-010 | Add Terraform GitHub Actions validation/plan/deploy workflows with AWS OIDC and protected apply. | | |
| TASK-011 | Define the QuickSight data source, dataset, refresh contract, and Music Streaming Habits dashboard build guide. | | |

### Implementation Phase 5

- **GOAL-005**: Prove the deployed system meets functional, security, and cost constraints.

| Task | Description | Completed | Date |
|---|---|---|---|
| TASK-012 | Execute end-to-end, permissions, failure, IaC, and cost-control acceptance tests. | | |

### Task Details

#### TASK-001: Repository and Terraform foundation

**Files:** Create `.gitignore`, `.editorconfig`, `README.md`, `terraform/bootstrap/main.tf`, `terraform/environments/dev/main.tf`, `terraform/environments/dev/variables.tf`, `terraform/environments/dev/terraform.tfvars.example`, `terraform/modules/common/{main.tf,variables.tf,outputs.tf}`, `.pre-commit-config.yaml`.

**Actions:** Define variables `aws_region`, `project_name`, `environment`, `aws_profile`, `assume_role_arn`, `terraform_state_bucket`, `terraform_lock_table`, `common_tags`; validate region format, lowercase project name, and environment `dev`. Configure S3 backend only through `-backend-config` CI arguments; keep backend values out of tracked tfvars. Add `terraform fmt -check`, `terraform validate`, TFLint, Checkov, and secret scanning commands to README.

**Validation:** Run `terraform -chdir=terraform/environments/dev fmt -check -recursive`, `terraform -chdir=terraform/environments/dev init -backend=false`, and `terraform -chdir=terraform/environments/dev validate`; expected exit code is 0.

**Commit:** `git add .gitignore .editorconfig README.md .pre-commit-config.yaml terraform && git commit -m "chore: bootstrap terraform project"`.

#### TASK-002: Network baseline

**Files:** Create `terraform/modules/network/{main.tf,variables.tf,outputs.tf}`; modify `terraform/environments/dev/main.tf` and `terraform/environments/dev/terraform.tfvars.example`.

**Actions:** Create a VPC with `vpc_cidr`, two private subnets from `private_subnet_cidrs`, route tables, VPC flow logs, endpoint policy allowing only configured lake bucket ARNs, and `aws_vpc_endpoint` type `Gateway` for S3. Define variable `enable_nat_gateway` defaulting to `false`; conditionally create one NAT gateway, EIP, public subnet, and route only when true. Create security groups for Glue and Redshift with no `0.0.0.0/0` inbound rules.

**Validation:** Run `terraform plan -var-file=terraform.tfvars.example`; assert output contains `aws_vpc_endpoint.s3` and contains no `aws_nat_gateway` with default inputs using `terraform show -json plan.out | jq`.

**Commit:** `git add terraform && git commit -m "feat: add private network and s3 endpoint"`.

#### TASK-003: Encrypted data lake

**Files:** Create `terraform/modules/data_lake/{main.tf,variables.tf,outputs.tf}` and `docs/data-contracts/storage-layout.md`.

**Actions:** Create KMS keys and aliases from `kms_alias_prefix`; create S3 bucket names from module outputs and prefixes `raw/`, `clean/`, `analytics/`, `quarantine/`, `athena-results/`, and `glue-assets/`. Enable versioning, SSE-KMS default encryption, bucket-key, public access block, ownership-enforced ACLs, TLS-only bucket policy, lifecycle expiration controlled by `raw_retention_days`, `clean_retention_days`, `analytics_retention_days`, and CloudTrail data-event selector. Configure S3 event notifications only for raw manifest completion objects, never every individual record.

**Validation:** Run `terraform validate` and `checkov -d terraform`; expected: no public S3 finding and all buckets have encryption/versioning. Add a documentation example `raw/source=kaggle/ingest_date=2026-07-10/manifest.json`.

**Commit:** `git add terraform docs/data-contracts/storage-layout.md && git commit -m "feat: add encrypted zoned data lake"`.

#### TASK-004: Governance and identities

**Files:** Create `terraform/modules/governance/{main.tf,variables.tf,outputs.tf}`, `terraform/modules/iam/{main.tf,variables.tf,outputs.tf}`, and `docs/security/access-matrix.md`.

**Actions:** Define separate roles for Lambda, Firehose, Glue, Redshift, GitHub OIDC, and analytics reader. Grant only required S3 prefixes, KMS keys, Glue APIs, Kinesis, CloudWatch, SQS, and Secrets Manager actions. Register lake locations, create Glue databases `music_raw`, `music_clean`, `music_analytics`, apply LF-tags `zone=raw|clean|analytics`, and grant `SELECT` only on analytics to `analytics_reader_principal_arn`. Store Redshift admin and loader connection material in a Secrets Manager secret populated outside source control.

**Validation:** Run `terraform validate`; use IAM Access Analyzer policy validation for each generated policy; verify the analytics-reader role has no raw or clean table grant in `terraform show -json` output.

**Commit:** `git add terraform docs/security/access-matrix.md && git commit -m "feat: add lake formation governance and iam"`.

#### TASK-005: Streaming ingestion and orchestration

**Files:** Create `terraform/modules/streaming/{main.tf,variables.tf,outputs.tf}`, `src/lambda/validator/app.py`, `src/lambda/validator/requirements.txt`, `tests/lambda/test_validator.py`.

**Actions:** Create Kinesis stream with `stream_mode = "ON_DEMAND"`, Firehose extended S3 destination to `raw/source=kinesis/`, buffering variables, KMS encryption, and error prefix. Create an SQS DLQ and Lambda subscribed to raw manifest object events. Implement `validate_manifest(event: dict) -> dict`: verify object key begins `raw/`, ends `manifest.json`, and includes source/date; start Glue job with `--raw-prefix`, `--run-id`, and `--ingest-date`; send invalid inputs to DLQ. Emit JSON logs containing `run_id`, `source`, and `ingest_date`.

**Validation:** First run `pytest tests/lambda/test_validator.py -v` with a test for an invalid key and a valid manifest; implement until tests pass. Package Lambda with `terraform` archive resources and run `terraform validate`.

**Commit:** `git add terraform src/lambda tests/lambda && git commit -m "feat: add streaming ingest and glue orchestration"`.

#### TASK-006: Dataset and contracts

**Files:** Create `scripts/download_dataset.sh`, `scripts/generate_stream_events.py`, `src/contracts/music_event.schema.json`, `tests/contracts/test_schema.py`, `data/sample/music_streaming_habits.csv`, and `docs/data-contracts/music-streaming.md`.

**Actions:** Make `download_dataset.sh` require `KAGGLE_USERNAME` and `KAGGLE_KEY` from environment and download dataset slug `uditjain13/music-streaming-habits-2026` to a user-provided ignored directory. Define a versioned JSON schema with non-null `event_id`, `user_id`, `track_id`, `artist_name`, `played_at`, `duration_seconds`, `platform`, and `ingest_date`. Generator must produce seeded, schema-conformant events and use `KINESIS_STREAM_NAME` plus AWS SDK default credential chain; never embed credentials.

**Validation:** Run `pytest tests/contracts/test_schema.py -v`; expected: valid fixture passes and missing `event_id` fails. Run `python scripts/generate_stream_events.py --seed 2026 --count 10 --dry-run`; expected: ten JSON records.

**Commit:** `git add scripts src/contracts tests/contracts data/sample docs/data-contracts && git commit -m "feat: add music streaming data contracts"`.

#### TASK-007: Glue transformations

**Files:** Create `src/glue/jobs/raw_to_clean.py`, `src/glue/jobs/clean_to_analytics.py`, `src/glue/lib/quality.py`, `tests/glue/test_quality.py`, `terraform/modules/glue/{main.tf,variables.tf,outputs.tf}`.

**Actions:** Implement `validate_required_columns(dataframe, columns)`, `quarantine_invalid_records(dataframe, path)`, and `deduplicate_events(dataframe, key="event_id")`. The raw-to-clean job reads only the supplied raw prefix, enforces schema, normalizes timestamps to UTC, removes duplicates, writes Snappy Parquet partitioned by `ingest_date`, enables job bookmarks, and writes rejected records to quarantine. The clean-to-analytics job writes `fact_stream`, `dim_artist`, `dim_track`, and `daily_listening_metrics` Parquet datasets. Configure Glue job worker type/count, timeout, retries, log group, temporary directory, security configuration, catalog permissions, and arguments as variables.

**Validation:** Unit-test quality helpers with PySpark local mode; expected: duplicate count reduces to one and null required field appears in quarantine. Run `python -m compileall src/glue` and `terraform validate`.

**Commit:** `git add src/glue tests/glue terraform && git commit -m "feat: add governed glue etl jobs"`.

#### TASK-008: Athena and Redshift analytics

**Files:** Create `terraform/modules/analytics/{main.tf,variables.tf,outputs.tf}`, `sql/athena/create_tables.sql`, `sql/redshift/001_schema.sql`, `sql/redshift/002_merge_fact_stream.sql`, `tests/sql/test_analytics_contracts.py`.

**Actions:** Create Athena workgroup with KMS result encryption, output location, enforced configuration, and `athena_bytes_scanned_cutoff_per_query`. Define external tables over analytics Parquet partitions. Create Redshift Serverless namespace/workgroup inside the VPC using variables `redshift_base_capacity`, `redshift_admin_secret_arn`, and security group ID. Create `analytics` schema, dimensions, and `fact_stream` keyed by `event_id`; use staging `COPY` from analytics Parquet then transactional `MERGE` to guarantee idempotent loads. Associate the Redshift role with lake KMS/S3 permissions.

**Validation:** Parse SQL using `sqlfluff lint sql`; execute contract tests against local fixtures to assert `event_id` uniqueness and daily metrics query columns. Run `terraform plan` and confirm workgroup is `Redshift Serverless`, not a provisioned cluster.

**Commit:** `git add terraform sql tests/sql && git commit -m "feat: add athena and redshift analytics layer"`.

#### TASK-009: Observability and operations

**Files:** Create `terraform/modules/observability/{main.tf,variables.tf,outputs.tf}`, `docs/runbooks/{pipeline-failure.md,dlq-replay.md,cost-controls.md}`, and `tests/terraform/test_observability.py`.

**Actions:** Create named log groups with variable `log_retention_days`, dashboard widgets, metric filters, and alarms for Lambda Errors/Throttles, Glue FAILED/TIMEOUT, Kinesis iterator age, Firehose delivery failure, DLQ depth, Redshift errors/capacity, and Athena bytes scanned. Alarm actions use variable `alarm_sns_topic_arn`; when it is null, create no external notification action. Runbooks must specify detection query, impact, safe remediation, and evidence to capture.

**Validation:** Run Terraform static tests asserting every Lambda/Glue resource has a log group and every alarm has `treat_missing_data`. Run `terraform validate`.

**Commit:** `git add terraform docs/runbooks tests/terraform && git commit -m "feat: add pipeline monitoring and runbooks"`.

#### TASK-010: GitHub Actions delivery

**Files:** Create `.github/workflows/{terraform-check.yml,terraform-deploy.yml}`, `.github/dependabot.yml`, `docs/operations/github-actions.md`.

**Actions:** `terraform-check.yml` runs on pull requests: fmt, init with `-backend=false`, validate, TFLint, Checkov, and uploads `plan.out` built with injected non-secret variables. `terraform-deploy.yml` runs on pushes to `main`, uses GitHub environment `dev`, `aws-actions/configure-aws-credentials` OIDC role ARN from `AWS_DEPLOY_ROLE_ARN`, initializes remote state from repository/environment variables, plans, and applies only after environment protection approval. Configure `id-token: write`, least-privilege checkout, pinned action SHAs, and concurrency group `terraform-dev`.

**Validation:** Run `actionlint .github/workflows/*.yml`; use `terraform fmt -check -recursive`; inspect workflows to confirm no `AWS_ACCESS_KEY_ID` or secret literal occurs.

**Commit:** `git add .github docs/operations/github-actions.md && git commit -m "ci: add terraform validation and deployment workflows"`.

#### TASK-011: QuickSight dashboard contract

**Files:** Create `terraform/modules/quicksight/{main.tf,variables.tf,outputs.tf}`, `docs/bi/music-streaming-dashboard.md`, `sql/redshift/003_dashboard_views.sql`.

**Actions:** Parameterize `quicksight_enabled`, `quicksight_principal_arn`, and `quicksight_refresh_schedule`; default `quicksight_enabled` to false to avoid dev charges until an account is subscribed. When enabled, create a Redshift data source and dataset from dashboard views. Document four visuals: daily listening minutes trend, top artists, platform distribution, and skip-rate KPI, plus row-level access mapping. Refresh only after the Redshift merge succeeds.

**Validation:** Run `terraform plan -var='quicksight_enabled=false'` and verify no QuickSight resource is planned. Run `sqlfluff lint sql/redshift/003_dashboard_views.sql`.

**Commit:** `git add terraform docs/bi sql/redshift/003_dashboard_views.sql && git commit -m "feat: add quicksight dashboard contract"`.

#### TASK-012: End-to-end acceptance

**Files:** Create `tests/e2e/test_pipeline.py`, `scripts/run_acceptance.sh`, `docs/operations/acceptance-evidence.md`.

**Actions:** Implement parameterized tests that upload a valid batch manifest and publish a valid Kinesis event, wait for Glue completion, assert clean and analytics Parquet objects exist, query Athena for expected count, query Redshift for one merged event, assert invalid record is quarantined, and assert analytics-reader cannot query raw. `run_acceptance.sh` must require `AWS_REGION`, `DATA_LAKE_BUCKET`, `ATHENA_WORKGROUP`, `REDSHIFT_WORKGROUP`, and `TEST_ROLE_ARN` environment variables and fail before running if any are unset. Capture resource tags and CloudWatch alarm state for cost/operations evidence.

**Validation:** Run `pytest tests/e2e/test_pipeline.py -m integration -v` against dev after deployment; expected: all assertions pass. Run `scripts/run_acceptance.sh` with missing variable; expected: nonzero exit and variable name in error.

**Commit:** `git add tests/e2e scripts/run_acceptance.sh docs/operations/acceptance-evidence.md && git commit -m "test: add pipeline acceptance verification"`.

## 3. Alternatives

- **ALT-001**: Lambda-per-record transformations were rejected because Glue micro-batches provide more cost-predictable, scalable transformations and data-quality controls.
- **ALT-002**: A NAT Gateway was rejected for dev because it adds a fixed hourly and data-processing cost; the required S3 access is satisfied by a Gateway endpoint.
- **ALT-003**: Provisioned Redshift was rejected because Redshift Serverless better fits intermittent development workloads.
- **ALT-004**: Crawlers as the only schema definition were rejected because explicit schema contracts prevent silent schema drift; crawlers remain optional discovery tooling.

## 4. Dependencies

- **DEP-001**: AWS account with permissions to create all named services in `ap-southeast-1` and a QuickSight subscription before enabling QuickSight.
- **DEP-002**: Terraform, AWS CLI v2, Python 3.11, pytest, PySpark-compatible local test runtime, TFLint, Checkov, SQLFluff, actionlint, jq, and Git.
- **DEP-003**: Kaggle API credentials supplied only as environment variables for dataset download.
- **DEP-004**: GitHub repository environment `dev`, OIDC provider, state bucket/lock table, and reviewer protection configured before deployment.

## 5. Files

- **FILE-001**: `terraform/` — reusable Terraform modules and dev composition.
- **FILE-002**: `src/lambda/` — manifest validation and Glue orchestration.
- **FILE-003**: `src/glue/` — data quality and Spark transformations.
- **FILE-004**: `src/contracts/` and `docs/data-contracts/` — versioned dataset contract and storage layout.
- **FILE-005**: `sql/` — Athena DDL and Redshift schema/load/dashboard models.
- **FILE-006**: `.github/workflows/` — CI and protected deploy automation.
- **FILE-007**: `tests/` and `scripts/` — unit, contract, infrastructure, and end-to-end evidence.

## 6. Testing

- **TEST-001**: Unit-test Lambda manifest validation, Glue data-quality helpers, and deterministic generator output.
- **TEST-002**: Validate JSON schema against valid and invalid streaming fixtures.
- **TEST-003**: Run `terraform fmt`, `validate`, TFLint, Checkov, and plan assertions on every pull request.
- **TEST-004**: Lint Athena and Redshift SQL and test model contract columns/keys.
- **TEST-005**: Run deployed end-to-end valid, invalid/quarantine, idempotency, and Lake Formation authorization tests.

## 7. Risks & Assumptions

- **RISK-001**: Kaggle schema or download access can change; the local schema contract and sample fixture isolate ETL development from it.
- **RISK-002**: QuickSight subscriptions, Redshift Serverless, Kinesis, Glue, and NAT can incur charges; feature flags, service quotas, budgets, and explicit destroy procedures control dev spend.
- **RISK-003**: Lake Formation permission propagation can delay integration tests; acceptance script retries boundedly and logs the final denied API response.
- **RISK-004**: A single dev environment does not establish production high availability; the modules must be parameterized for later promotion without changing interfaces.
- **ASSUMPTION-001**: Music event fields can be mapped to the defined contract; mappings are documented before Glue job implementation.
- **ASSUMPTION-002**: Network egress is not required in private subnets for the initial dev pipeline; if it becomes necessary, set `enable_nat_gateway=true` through an untracked tfvars or CI variable.

## 8. Related Specifications / Further Reading

[Design specification](../docs/superpowers/specs/2026-07-10-music-streaming-etl-design.md)

[AWS incremental S3-to-Redshift Glue pattern](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/build-an-etl-service-pipeline-to-load-data-incrementally-from-amazon-s3-to-amazon-redshift-using-aws-glue.html)

[Reference production-ready AWS data pipeline article](https://dev.to/aws-builders/building-a-production-ready-data-pipeline-on-aws-a-hands-on-guide-for-data-engineers-43c2)

[Music Streaming Habits 2026 dataset](https://www.kaggle.com/datasets/uditjain13/music-streaming-habits-2026/code)
