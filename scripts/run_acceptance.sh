#!/usr/bin/env bash
set -euo pipefail

required_variables=(
  AWS_REGION
  DATA_LAKE_BUCKET
  ATHENA_WORKGROUP
  REDSHIFT_WORKGROUP
  TEST_ROLE_ARN
)

for variable in "${required_variables[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "${variable} must be set." >&2
    exit 1
  fi
done

python -m pytest tests/e2e/test_pipeline.py -m integration -v
