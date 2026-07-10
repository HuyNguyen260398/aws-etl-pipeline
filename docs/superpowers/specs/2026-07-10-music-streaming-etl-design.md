# Music Streaming Habits 2026 — AWS ETL Design

## Scope

Build one development environment in `ap-southeast-1` that ingests a Kaggle Music Streaming Habits 2026 snapshot and synthetic streaming events, creates governed raw, clean, and analytics S3 zones, exposes the data through Athena and Redshift Serverless, and supports a QuickSight dashboard. Infrastructure is Terraform and delivery is GitHub Actions.

## Decisions

- Deploy only `dev`; Terraform derives resource names from `project_name`, `environment`, and `aws_region` variables. Credentials, account identifiers, notification endpoints, CIDRs, and service sizing are input variables or CI secrets.
- Preserve all requested services: S3, Kinesis Data Streams, Glue, Lambda, Athena, Redshift, QuickSight, Lake Formation, CloudWatch, VPC, S3 VPC endpoint, Terraform, and GitHub Actions.
- Use an S3 Gateway endpoint. Do not provision a NAT Gateway in dev because the design does not require private subnets to reach public internet services. Keep a configurable NAT module disabled by default for a later production environment.
- Use Kinesis on-demand mode initially, Lambda only for validation/orchestration, and Glue Spark jobs for durable transformations. Deliver streaming records to `raw/kinesis/` before processing them in micro-batches.
- Store immutable source files in `raw`, validated canonical Parquet in `clean`, and BI-ready dimensional/fact datasets in `analytics`. All zones use SSE-KMS, versioning, block-public-access, lifecycle rules, and partitioning by `ingest_date=YYYY-MM-DD`.
- Use Lake Formation permissions over Glue Catalog databases, LF-tags for zone classification, and least-privilege IAM roles. Redshift access is secret-backed and no credential is committed.
- Load Redshift Serverless staging tables from analytics Parquet and merge by deterministic event key. Athena workgroups enforce result-location and bytes-scanned limits.
- Every plan task includes validation and exactly one Git commit with the stated conventional-commit message.

## Flow

`Kaggle CSV + event generator -> S3 raw` and `event generator -> Kinesis -> managed S3 delivery -> S3 raw`; `S3 manifest/object event -> Lambda -> Glue validation/transform job -> clean Parquet -> analytics Parquet -> Athena and Redshift Serverless -> QuickSight`.

## Error Handling and Operations

- Lambda sends failed event metadata to SQS DLQ and emits structured JSON logs and metrics.
- Glue enables job bookmarks, writes invalid records and data-quality failures to a quarantine prefix, and fails the run when required columns or key uniqueness checks fail.
- CloudWatch alarms cover Lambda errors/throttles, Glue failures/duration, Kinesis iterator age, delivery failures, S3 event delivery failures, Redshift capacity/errors, and estimated Athena spend.
- GitHub Actions format, validate, scan, plan, and apply Terraform through an environment-protected workflow. Apply uses OIDC rather than static AWS keys.

## Cost Controls

- Single AWS region and development environment; Kinesis on-demand; Glue minimum supported worker configuration; lifecycle raw data to infrequent access after the configured retention period; bounded CloudWatch retention; Athena scan cap; Redshift Serverless low base capacity; dashboard refreshes only after successful loads.

## Acceptance Criteria

1. Terraform deploys the full requested architecture into `ap-southeast-1` without hard-coded credentials or account IDs.
2. A supplied sample event reaches raw S3, clean Parquet, analytics Parquet, Athena, and Redshift.
3. Lake Formation denies an ungranted principal and permits the analytics-reader role only for the analytics database.
4. GitHub Actions produces a checked Terraform plan on pull requests and performs protected deployment from `main`.
5. Each implementation task is committed individually with its specified message.
