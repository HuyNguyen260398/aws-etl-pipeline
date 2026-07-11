# GitHub Actions operations

## Terraform check

`terraform-check.yml` runs on pull requests that change Terraform. It performs format, backend-free initialization, validation, TFLint, Checkov, and a speculative plan, then retains `plan.out` for seven days.

Configure the following non-secret repository variables before enabling the plan step: `AWS_REGION`, `TF_PROJECT_NAME`, `VPC_CIDR`, `PRIVATE_SUBNET_CIDRS_JSON`, `NAT_PUBLIC_SUBNET_CIDR`, `S3_ENDPOINT_ALLOWED_BUCKET_ARNS_JSON`, `S3_ENDPOINT_ALLOWED_PRINCIPAL_ARNS_JSON`, `DATA_LAKE_BUCKET_NAME`, `GLUE_ASSETS_BUCKET_NAME`, `KMS_ALIAS_PREFIX`, `OIDC_PROVIDER_ARN`, `ANALYTICS_READER_TRUSTED_PRINCIPAL_ARN`, and `REDSHIFT_ADMIN_SECRET_ARN`.

The plan uses non-secret inputs only. PRs that cannot obtain AWS credentials can still complete format, init, validate, TFLint, and Checkov; configure an approved read-only plan role before relying on plan artifacts from untrusted forks.

## Protected deployment

`terraform-deploy.yml` runs only for `main` pushes or manual dispatch and targets the GitHub environment `dev`. Configure environment protection rules requiring approval before jobs in that environment can run. The workflow obtains short-lived credentials through GitHub OIDC using `AWS_DEPLOY_ROLE_ARN`; it never uses long-lived access keys.

Set these `dev` environment variables: `AWS_DEPLOY_ROLE_ARN`, `TF_STATE_BUCKET`, `TF_STATE_LOCK_TABLE`, `TF_STATE_KEY`, plus the non-secret Terraform input variables listed above. The workflow initializes the S3/DynamoDB backend, plans, and applies the exact saved plan.

## Operational safeguards

- `terraform-dev` concurrency prevents overlapping applies; new deploys wait for an active deployment rather than canceling it.
- All third-party actions are pinned to immutable commit SHAs and annotated with their release version.
- Rotate OIDC role trust only through Terraform and limit it to the repository and `main` branch.
- Never place secret values, Terraform state, or AWS access keys in workflow files, repository variables, logs, or pull-request comments.
