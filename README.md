# AWS ETL Pipeline — Music Streaming Habits 2026

A production-oriented, cost-conscious AWS data platform for analyzing Music Streaming Habits 2026. The project uses Terraform to deploy one `dev` environment in `ap-southeast-1`.

## Architecture

```text
Kaggle snapshot ──┐
                 ├──> S3 raw zone ──> Lambda orchestration ──> AWS Glue
Streaming events ─┴──> Kinesis ──> managed S3 delivery          │
                                                                 ├──> S3 clean zone (Parquet)
                                                                 ├──> S3 analytics zone (Parquet)
                                                                 └──> Redshift Serverless
                                                                         │
                                                  Athena <──────────────┤
                                                  QuickSight <──────────┘
```

Lake Formation governs catalog and data access. CloudWatch provides logs, metrics, dashboards, and alarms. The VPC uses an S3 Gateway endpoint; NAT is disabled by default to avoid unnecessary development cost.

## Services

- Amazon S3 data lake: raw, clean, analytics, quarantine, and query-result zones
- Amazon Kinesis Data Streams for real-time ingestion
- AWS Lambda and AWS Glue for orchestration, quality checks, and ETL
- AWS Glue Data Catalog and AWS Lake Formation for metadata and governance
- Amazon Athena and Amazon Redshift Serverless for analytics
- Amazon QuickSight for dashboards (opt-in to control cost)
- Amazon VPC, S3 Gateway VPC endpoint, AWS KMS, AWS Secrets Manager, and Amazon CloudWatch
- Terraform for infrastructure as code

## Repository layout

```text
terraform/    Terraform modules and the dev environment composition
src/          Lambda, Glue, and data-contract source code
sql/          Athena and Redshift DDL, load, and dashboard SQL
tests/        Unit, contract, infrastructure, and end-to-end tests
scripts/      Dataset download, event generation, and acceptance commands
docs/         Architecture, security, operations, and data contracts
plan/         Approved implementation plan
```

## Prerequisites

- Terraform 1.7 or later
- AWS CLI v2 authenticated through a profile or assumed role
- Python 3.11 or later
- Git
- Optional local quality tools: TFLint, Checkov, SQLFluff, and pytest
- Kaggle API credentials only when downloading the source dataset

## Configuration

No AWS credentials, account IDs, secrets, or environment-specific values belong in source control. Configure Terraform through input variables and an ignored `terraform.tfvars`.

Supply the remote-state bucket, lock table, state key, and region as `terraform init -backend-config` arguments (or an ignored backend configuration file); Terraform backend blocks cannot reference input variables.

```bash
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
terraform -chdir=terraform/environments/dev init
terraform -chdir=terraform/environments/dev plan
```

> [!IMPORTANT]
> The Terraform modules and the `dev` composition are implemented. Review a Terraform plan and confirm its cost and security implications before applying, and supply account-specific values through an ignored `terraform.tfvars` or CI variables.

## Development principles

- Deploy only one low-cost `dev` environment by default.
- Keep `aws_region` configurable; its default is `ap-southeast-1`.
- Preserve all required architecture components while avoiding fixed-cost development resources where possible.
- Use S3 Gateway VPC endpoints; leave NAT disabled unless private-subnet internet egress becomes necessary.
- Use IAM least privilege, KMS encryption, Lake Formation grants, Secrets Manager, and GitHub OIDC.
- Create exactly one conventional Git commit after every completed implementation-plan task.

## Implementation plan

Read and execute [the development plan](plan/infrastructure-aws-etl-1.md) in order. It defines concrete files, validation commands, architecture decisions, cost controls, and the commit message for each task.

The architecture rationale is in [the design specification](docs/superpowers/specs/2026-07-10-music-streaming-etl-design.md).
