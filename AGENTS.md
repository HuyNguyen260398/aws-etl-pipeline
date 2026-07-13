# Repository Guidance

## Project context

This repository builds a production-oriented AWS ETL data pipeline for Music Streaming Habits 2026. It is owned by Huy, a DevOps Engineer with five years of experience in infrastructure automation, CI/CD, scalable cloud deployments, and AI-enabled operational improvement.

## Engineering requirements

- Implement the approved plan in `docs/superpowers/plan/infrastructure-aws-etl-1.md` sequentially unless a later user instruction changes scope.
- Target one `dev` environment in `ap-southeast-1`; keep region, credentials, account-specific values, resource sizing, CIDRs, and notification endpoints configurable through Terraform variables.
- Preserve the requested services: S3, Kinesis Data Streams, Glue, Lambda, Athena, Redshift, QuickSight, Lake Formation, CloudWatch, VPC, S3 VPC endpoint, and Terraform.
- Prefer the lowest-cost safe development configuration. Keep NAT Gateway disabled by default and use the S3 Gateway VPC endpoint.
- Do not commit credentials, state files, generated data, downloaded Kaggle files, private tfvars, or environment files.
- Use least-privilege IAM, KMS encryption, S3 public-access blocks, Lake Formation grants, Secrets Manager, and GitHub OIDC.
- Run each task's validation commands before completion and make exactly one conventional Git commit with the commit message defined by that task.
- Keep modules small, focused, reusable, and environment-agnostic. Store dev composition in `terraform/environments/dev` and reusable resources in `terraform/modules`.
- Keep raw data immutable; write validated canonical Parquet to clean and BI-ready models to analytics. Quarantine invalid records with actionable metadata.

## Quality gates

- Run `terraform fmt -check -recursive`, `terraform validate`, TFLint, and Checkov for Terraform changes.
- Run pytest for Python changes and SQLFluff for SQL changes.
- Do not claim deployment success without command output or AWS evidence.
- Update documentation whenever architecture, configuration variables, runbooks, or data contracts change.
