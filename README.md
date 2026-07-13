# AWS ETL Pipeline — Reference Architecture

[![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.7-7B42BC?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![Python](https://img.shields.io/badge/Python-3.11%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![AWS](https://img.shields.io/badge/AWS-Serverless-232F3E?logo=amazonwebservices&logoColor=white)](https://aws.amazon.com/)
[![AWS Glue](https://img.shields.io/badge/AWS%20Glue-PySpark%204.0-E25A1C?logo=apachespark&logoColor=white)](https://aws.amazon.com/glue/)
[![Analytics](https://img.shields.io/badge/Analytics-Athena%20%C2%B7%20Redshift-FF9900?logo=amazonredshift&logoColor=white)](https://aws.amazon.com/redshift/serverless/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A production-oriented, cost-conscious **AWS data-platform reference architecture**,
built with Terraform, Python, and SQL. It ingests batch and streaming data,
processes it through a raw → clean → analytics data lake, and serves it via
Athena, Redshift Serverless, and (opt-in) QuickSight.

The sample workload is the *Music Streaming Habits 2026* dataset, but nothing in
the infrastructure is dataset-specific — it is meant to be **cloned, configured
with your own values, and deployed into any AWS account**. No account IDs,
ARNs, bucket names, regions, or secrets are hardcoded; every environment-specific
value is a Terraform input variable.

## Contents

- [Architecture](#architecture)
- [What gets deployed](#what-gets-deployed)
- [Repository layout](#repository-layout)
- [Cost note](#cost-note)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Testing](#testing)
- [Teardown](#teardown)
- [Documentation](#documentation)

## Architecture

![AWS ETL Pipeline reference architecture: batch and streaming ingestion land in an S3 raw zone, Lambda + AWS Glue drive the raw → clean → analytics flow, and the analytics zone is served through Athena, Redshift Serverless, and opt-in QuickSight — all inside a single VPC with IAM, KMS, Secrets Manager, Lake Formation, CloudWatch, and an SQS DLQ as cross-cutting concerns.](docs/architecture/aws-etl-pipeline.png)

> [!NOTE]
> The image is exported from [`docs/architecture/aws-etl-pipeline.drawio`](docs/architecture/aws-etl-pipeline.drawio).
> Re-render it after edits with
> `drawio -x -f png --scale 2 --border 10 -o docs/architecture/aws-etl-pipeline.png docs/architecture/aws-etl-pipeline.drawio`.

Lake Formation governs catalog and data access; an analytics-reader role can
query `analytics` only and is denied `raw`. CloudWatch provides logs, metrics,
alarms, and a dashboard. The VPC uses an S3 Gateway endpoint with NAT disabled
by default to minimize cost.

Detailed component, sequence, and flow diagrams live in
[`docs/architecture/pipeline-diagrams.md`](docs/architecture/pipeline-diagrams.md).

## What gets deployed

- **Amazon S3** data lake — `raw`, `clean`, `analytics`, `quarantine`, and
  `athena-results` zones, plus a separate Glue-assets bucket (KMS-encrypted,
  versioned, TLS-only)
- **Amazon Kinesis Data Streams** + **Amazon Data Firehose** for streaming ingestion
- **AWS Lambda** (manifest validation, Glue orchestration) and **AWS Glue**
  (PySpark ETL with a shared data-quality library)
- **AWS Glue Data Catalog** + **AWS Lake Formation** for metadata and governance
- **Amazon Athena** and **Amazon Redshift Serverless** for analytics
- **Amazon QuickSight** dashboards (opt-in, off by default)
- **Amazon VPC**, S3 Gateway endpoint, **AWS KMS**, **AWS Secrets Manager**,
  **Amazon EventBridge**, **Amazon SQS** (DLQ), and **Amazon CloudWatch**

## Repository layout

```text
aws-etl-pipeline/
├── terraform/                # Infrastructure as code (HCL)
│   ├── bootstrap/            # One-time remote-state bucket + DynamoDB lock table
│   ├── environments/dev/     # Env composition: main.tf, variables.tf, outputs.tf
│   └── modules/              # Reusable, environment-agnostic modules, composed in order:
│                             #   common → network → data_lake → iam → governance →
│                             #   streaming → glue → analytics → observability → quicksight
├── src/                      # Application source code
│   ├── lambda/
│   │   ├── validator/        # Manifest validator — triggers the raw-to-clean job
│   │   └── orchestrator/     # Chains clean-to-analytics on Glue SUCCEEDED
│   ├── glue/
│   │   ├── jobs/             # PySpark ETL: raw_to_clean.py, clean_to_analytics.py
│   │   └── lib/              # Shared data-quality library (quality.py)
│   └── contracts/            # JSON Schema for the music-streaming event
├── sql/
│   ├── athena/               # External-table DDL over the analytics zone
│   └── redshift/             # Schema, idempotent MERGE, dashboard views
├── tests/                    # pytest: contracts · lambda · glue · sql · terraform · e2e
├── scripts/                  # Dataset download, event generator, schema seed, acceptance
├── docs/                     # Architecture, data contracts, security, runbooks, operations, BI
└── data/sample/              # De-identified sample input (real/downloaded data is gitignored)
```

---

## Cost note

This stack is intentionally low-cost for a `dev` footprint (on-demand Kinesis,
serverless Glue/Redshift/Athena, NAT disabled). Even so, **Redshift Serverless,
Kinesis, and KMS incur charges while deployed.** Review `terraform plan` before
applying, and run `terraform destroy` when you are done (see [Teardown](#teardown)).

## Prerequisites

Install locally:

| Tool | Version | Purpose |
|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.7 | Provision infrastructure |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 | Authentication; used by the schema-seed step |
| [Python](https://www.python.org/downloads/) | ≥ 3.11 | Tests, event generator |
| `bash`, `git` | — | Scripts and version control |

Optional quality tooling: `tflint`, `checkov`, `sqlfluff`, `pre-commit`, and
Kaggle API credentials (only if you download the real dataset).

You also need:

- An **AWS account** and credentials with permission to create the services
  listed above (S3, KMS, IAM, VPC, Kinesis, Firehose, Lambda, Glue, Lake
  Formation, Athena, Redshift Serverless, CloudWatch, Secrets Manager, SQS,
  EventBridge, DynamoDB).
- Two **globally unique S3 bucket names** you will choose (state bucket +
  data-lake bucket) and a third for Glue assets.
- A **region** to deploy into (default in the examples is `ap-southeast-1`;
  change it freely).

---

## Setup

All commands are run from the repository root. `-chdir` keeps you there while
pointing Terraform at the right directory.

### 1. Clone and set up Python

```bash
git clone <your-fork-url> aws-etl-pipeline
cd aws-etl-pipeline

python -m venv .venv
source .venv/bin/activate
pip install -r src/lambda/validator/requirements.txt   # runtime deps
pip install pytest jsonschema                            # to run unit tests
```

### 2. Authenticate to AWS

Use any standard mechanism (SSO, profile, or environment variables):

```bash
aws configure sso            # or: aws configure
export AWS_PROFILE=your-profile
aws sts get-caller-identity  # confirm the account and identity
```

The Terraform provider also accepts `aws_profile` and `assume_role_arn`
variables if you prefer to set them in `terraform.tfvars`.

### 3. Bootstrap the Terraform remote state

This creates the S3 state bucket, its KMS key, and the DynamoDB lock table.
Because the state bucket does not exist yet, bootstrap runs with **local
state** (`-backend=false`).

```bash
cp terraform/bootstrap/terraform.tfvars.example terraform/bootstrap/terraform.tfvars
# Edit the file: set a globally unique terraform_state_bucket, aws_region, etc.

terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap plan
terraform -chdir=terraform/bootstrap apply
```

Note the `terraform_state_bucket`, `terraform_lock_table`, and `aws_region`
values — you will pass them to the dev environment's backend in step 6.

### 4. Create the Redshift admin secret

Redshift Serverless reads its admin credentials from Secrets Manager (never from
Terraform variables). Create a secret whose value is JSON with `username` and
`password` keys:

```bash
aws secretsmanager create-secret \
  --name music-etl-dev-redshift-admin \
  --secret-string '{"username":"analytics_admin","password":"<a-strong-password>"}' \
  --query ARN --output text
```

Copy the printed ARN into `redshift_admin_secret_arn` in the next step.

### 5. Configure the dev environment variables

```bash
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
```

Edit `terraform/environments/dev/terraform.tfvars` and set at minimum:

| Variable | What to set |
|---|---|
| `aws_region` | Your target region |
| `data_lake_bucket_name` | A globally unique bucket name |
| `glue_assets_bucket_name` | A globally unique bucket name |
| `redshift_admin_secret_arn` | The ARN from step 4 |
| `analytics_reader_trusted_principal_arn` | An IAM principal allowed to assume the analytics-reader role |
| `s3_endpoint_allowed_principal_arns` | Principal ARNs permitted through the S3 gateway endpoint |
| `common_tags.Owner` | Your name / team |

Leave `quicksight_enabled = false` unless you have completed the QuickSight
prerequisites (see step 10).

### 6. Initialize the dev environment against the remote backend

The S3 backend cannot read variables, so pass its settings on the command line
(substitute the values from step 3):

```bash
terraform -chdir=terraform/environments/dev init \
  -backend-config="bucket=<your-state-bucket>" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=<your-region>" \
  -backend-config="dynamodb_table=<your-lock-table>"
```

> Tip: put those four lines in an ignored `backend.hcl` file and run
> `terraform ... init -backend-config=backend.hcl` instead.

### 7. Plan and apply

```bash
terraform -chdir=terraform/environments/dev plan       # review carefully
terraform -chdir=terraform/environments/dev apply
```

Applying takes several minutes (Redshift Serverless is the slowest resource).
The apply also runs `scripts/seed_schema.sh` automatically to create the Athena
external tables and Redshift schema/views, so the stack is query-ready without a
manual step. This requires the AWS CLI to be authenticated locally.

### 8. Retrieve deployment info

All the resource names you need are exposed as Terraform outputs:

```bash
# Everything at once:
terraform -chdir=terraform/environments/dev output

# A single value (e.g. for scripts or CLI calls):
terraform -chdir=terraform/environments/dev output -raw data_lake_bucket_name
terraform -chdir=terraform/environments/dev output -raw kinesis_stream_name
terraform -chdir=terraform/environments/dev output -raw athena_workgroup_name
terraform -chdir=terraform/environments/dev output -raw redshift_workgroup_name
terraform -chdir=terraform/environments/dev output -raw analytics_reader_role_arn
```

Available outputs include the data-lake and Glue-assets buckets, KMS key ARN,
zone prefixes, VPC and subnet IDs, Kinesis stream, both Glue job names, the
Glue Catalog databases, Athena/Redshift workgroups, the analytics-reader role
ARN, and the CloudWatch dashboard name. See
[`terraform/environments/dev/outputs.tf`](terraform/environments/dev/outputs.tf).

### 9. Send test data (optional smoke test)

Generate deterministic streaming events into your Kinesis stream:

```bash
export KINESIS_STREAM_NAME="$(terraform -chdir=terraform/environments/dev output -raw kinesis_stream_name)"
python scripts/generate_stream_events.py --seed 2026 --count 10
```

For batch ingestion, upload partition files plus a `manifest.json` under
`raw/source=<name>/ingest_date=<yyyy-mm-dd>/` in the data-lake bucket — the
`manifest.json` object triggers the validator Lambda and the Glue pipeline. Then
query results in Athena or Redshift using the workgroups from step 8.

### 10. Enable QuickSight dashboards (optional)

Only after subscribing the account to QuickSight, set in `terraform.tfvars`:
`quicksight_enabled = true`, `quicksight_principal_arn`, and
`quicksight_vpc_connection_role_arn`; then re-apply. See
[`docs/bi/music-streaming-dashboard.md`](docs/bi/music-streaming-dashboard.md).

---

## Testing

```bash
# Unit + contract tests (no AWS required):
python -m pytest tests -m "not integration"

# Deployed acceptance/integration tests (require a live stack + exported inputs):
scripts/run_acceptance.sh   # fails fast if required env vars are unset
```

See [`runbook.md`](runbook.md) for the full acceptance variable list and evidence
steps, and [`docs/operations/acceptance-evidence.md`](docs/operations/acceptance-evidence.md)
for a sample evidence record.

## Teardown

```bash
# 1. Destroy the dev environment:
terraform -chdir=terraform/environments/dev destroy

# 2. (Optional) destroy the bootstrap state resources — do this last, and only
#    if you no longer need the remote state:
terraform -chdir=terraform/bootstrap destroy
```

The `dev` S3 buckets and Athena workgroup are created with `force_destroy` so
they empty cleanly during a `dev` teardown.

## Documentation

- [`docs/architecture/pipeline-diagrams.md`](docs/architecture/pipeline-diagrams.md) — component, sequence, and flow diagrams
- [`docs/data-contracts/`](docs/data-contracts) — event contract and storage layout
- [`docs/security/access-matrix.md`](docs/security/access-matrix.md) — IAM/Lake Formation access model
- [`docs/runbooks/`](docs/runbooks) — pipeline failure, DLQ replay, cost controls
- [`CLAUDE.md`](CLAUDE.md) — repository conventions and quality gates

## License

Released under the MIT License. See [`LICENSE`](LICENSE).
