# Cost controls runbook

## Detection query

Review the `*-athena-bytes-scanned` alarm and CloudWatch dashboard. In Athena, inspect recent queries:

```sql
SELECT query_execution_id, data_scanned_in_bytes, status
FROM information_schema.query_history
ORDER BY submission_time DESC
LIMIT 50;
```

## Impact

Unbounded Athena scans, retained Glue logs, or Redshift Serverless capacity events can exceed the development budget.

## Safe remediation

Cancel expensive Athena queries, require partition predicates, and investigate dashboard/query users. Keep the Athena workgroup scan cap enabled, leave NAT disabled, and reduce or pause nonessential Redshift/Glue activity. Do not lower retention or destroy data before preserving required evidence.

## Evidence to capture

Capture query execution IDs, bytes scanned, workgroup settings, Redshift capacity events, Glue worker-hours, dashboard screenshots, and the cost period under review.
