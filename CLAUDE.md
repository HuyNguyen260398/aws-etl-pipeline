# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A cost-conscious AWS data platform (Terraform + Python + SQL) for the "Music Streaming Habits 2026" dataset. Exactly one low-cost `dev` environment is deployed, in `ap-southeast-1`. Infrastructure is Terraform; ETL is Lambda + Glue (PySpark); analytics is Athena + Redshift Serverless; dashboards are QuickSight (opt-in). CI/CD is GitHub Actions via OIDC.

`plan/infrastructure-aws-etl-1.md` is the approved, ordered implementation plan. `docs/superpowers/specs/2026-07-10-music-streaming-etl-design.md` holds the architecture rationale. Follow the plan sequentially unless a user instruction changes scope, and make exactly one conventional Git commit per completed plan task.

## Architecture

Data flows raw → clean → analytics, each an S3 zone of Parquet under one data-lake bucket:

- Batch: a partition `manifest.json` lands under `raw/` → S3 event → **`src/lambda/validator/app.py`** validates the manifest key shape and calls `glue.start_job_run`.
- Streaming: events → Kinesis Data Streams → managed S3 delivery into `raw/`.
- **`src/glue/jobs/raw_to_clean.py`** writes validated canonical Parquet to `clean/`; **`clean_to_analytics.py`** builds BI models in `analytics/`. Both use **`src/glue/lib/quality.py`** (required-column validation, quarantine of invalid rows, dedup on `event_id`).
- Analytics: Athena over the Glue Catalog, plus Redshift Serverless that MERGEs `analytics/` Parquet into fact tables. Lake Formation governs catalog/data access; an analytics-reader role must be denied raw access.

Invariants to preserve: raw data is immutable; invalid records go to `quarantine/` with actionable metadata; the Redshift merge must be idempotent.

### Terraform layout

`terraform/environments/dev/main.tf` composes small, environment-agnostic modules from `terraform/modules/` in dependency order: `common → network → data_lake → iam → governance → streaming → glue → analytics → observability → quicksight`. Reusable resources live in modules; environment wiring and inputs live in the dev composition. Never hardcode account IDs, region, CIDRs, ARNs, bucket names, or notification endpoints — everything is a Terraform variable (see `terraform/environments/dev/terraform.tfvars.example`) or a CI variable/secret.

The Lambda and Glue quality-library `.zip` files are **built by Terraform** (`archive_file` data sources in the `streaming` and `glue` modules) from `src/` — do not hand-create or commit them (`quality-library.zip`, `validator.zip` are generated artifacts).

Backend config cannot use variables: pass remote state via `terraform init -backend-config=...` (bucket, dynamodb_table, key, region), as the deploy workflow does.

## Commands

Python unit tests (exclude the deployed AWS acceptance suite):
```bash
python -m pytest tests -m "not integration"
```
Run a single test: `python -m pytest tests/glue/test_quality.py::<TestClass>::<test_method> -v`

Deployed acceptance/integration tests require a live dev stack and exported inputs — use the guarded wrapper (see `runbook.md` for the full variable list and evidence steps):
```bash
scripts/run_acceptance.sh   # fails fast if required env vars are unset
```

Terraform quality gates (run before completing Terraform changes):
```bash
terraform fmt -check -recursive
terraform -chdir=terraform/environments/dev validate   # after: init -backend=false
tflint --chdir=terraform/environments/dev
checkov -d terraform --quiet --framework terraform
```

Other gates: **SQLFluff** for SQL (`sql/*/.sqlfluff` pin dialects — redshift, athena), **actionlint** for workflow changes, and `pre-commit run --all-files` (fmt, validate, checkov, yaml/json/whitespace).

## Conventions

- Do not claim deployment success without command output or AWS evidence; capture acceptance evidence in `docs/operations/acceptance-evidence.md`.
- Keep NAT Gateway disabled by default; rely on the S3 Gateway VPC endpoint. Avoid fixed-cost dev resources; keep QuickSight opt-in.
- Never commit credentials, state files, generated/downloaded data, private tfvars, or the built `.zip` artifacts.
- Update the relevant `docs/` (data contracts, runbooks, security access matrix) whenever architecture, variables, or data contracts change.
