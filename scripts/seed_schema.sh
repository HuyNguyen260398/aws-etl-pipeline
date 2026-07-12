#!/usr/bin/env bash
#
# Seed the analytics query schema that lives outside Terraform: the Athena
# external tables and the Redshift schema/views. Idempotent (CREATE ... IF NOT
# EXISTS / CREATE OR REPLACE), so it is safe to re-run on every apply.
#
# Required environment:
#   AWS_REGION DATA_LAKE_BUCKET ATHENA_WORKGROUP ATHENA_DATABASE
#   REDSHIFT_WORKGROUP REDSHIFT_DATABASE REDSHIFT_SECRET_ARN SQL_DIR
#
# Written for portability down to bash 3.2 (macOS): statements are emitted one
# per line and read with the default newline delimiter (no arrays, no NUL).
set -euo pipefail

: "${AWS_REGION:?}" "${DATA_LAKE_BUCKET:?}" "${ATHENA_WORKGROUP:?}" "${ATHENA_DATABASE:?}"
: "${REDSHIFT_WORKGROUP:?}" "${REDSHIFT_DATABASE:?}" "${REDSHIFT_SECRET_ARN:?}" "${SQL_DIR:?}"

# Emit each SQL statement on a single line: strip line comments, split on ';',
# collapse whitespace, drop blanks.
statements() {
  sed 's/--.*$//' "$1" \
    | awk 'BEGIN { RS = ";" } { gsub(/[ \t\r\n]+/, " "); gsub(/^ +| +$/, ""); if (length($0)) print $0 }'
}

wait_athena() {
  local qid="$1" state
  while true; do
    state=$(aws athena get-query-execution --region "$AWS_REGION" \
      --query-execution-id "$qid" --query 'QueryExecution.Status.State' --output text)
    case "$state" in
      SUCCEEDED) return 0 ;;
      FAILED | CANCELLED)
        aws athena get-query-execution --region "$AWS_REGION" --query-execution-id "$qid" \
          --query 'QueryExecution.Status.StateChangeReason' --output text >&2
        echo "Athena statement ${qid} ${state}" >&2
        return 1 ;;
    esac
    sleep 2
  done
}

echo "Seeding Athena tables in ${ATHENA_DATABASE} ..."
while IFS= read -r stmt; do
  if [ -z "$stmt" ]; then continue; fi
  query="${stmt//REPLACE_WITH_DATA_LAKE_BUCKET/$DATA_LAKE_BUCKET}"
  qid=$(aws athena start-query-execution --region "$AWS_REGION" \
    --query-string "$query" \
    --query-execution-context "Database=${ATHENA_DATABASE}" \
    --work-group "$ATHENA_WORKGROUP" --query QueryExecutionId --output text)
  wait_athena "$qid"
  echo "  ok (athena)"
done < <(statements "${SQL_DIR}/athena/create_tables.sql")

wait_redshift() {
  local sid="$1" label="$2" status
  while true; do
    status=$(aws redshift-data describe-statement --region "$AWS_REGION" --id "$sid" --query Status --output text)
    case "$status" in
      FINISHED) return 0 ;;
      FAILED | ABORTED)
        aws redshift-data describe-statement --region "$AWS_REGION" --id "$sid" --query Error --output text >&2
        echo "Redshift ${label} ${status}" >&2
        return 1 ;;
    esac
    sleep 2
  done
}

seed_redshift() {
  local file="$1" label="$2" sid
  echo "Seeding Redshift ${label} ..."
  while IFS= read -r stmt; do
    if [ -z "$stmt" ]; then continue; fi
    sid=$(aws redshift-data execute-statement --region "$AWS_REGION" \
      --workgroup-name "$REDSHIFT_WORKGROUP" --database "$REDSHIFT_DATABASE" \
      --secret-arn "$REDSHIFT_SECRET_ARN" --sql "$stmt" --query Id --output text)
    wait_redshift "$sid" "$label"
  done < <(statements "$file")
  echo "  ok: ${label}"
}

seed_redshift "${SQL_DIR}/redshift/001_schema.sql" "001_schema"
seed_redshift "${SQL_DIR}/redshift/003_dashboard_views.sql" "003_dashboard_views"
echo "Schema seed complete."
