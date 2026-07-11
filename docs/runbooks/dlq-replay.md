# DLQ replay runbook

## Detection query

Use the `*-dlq-depth` CloudWatch alarm and inspect the queue's `ApproximateNumberOfMessagesVisible` metric. Query the validator log group for the matching `run_id` before replay.

## Impact

One or more raw manifest events were not orchestrated. The raw manifest is still in S3 and can be safely replayed after the cause is fixed.

## Safe remediation

Validate one sampled DLQ message and its S3 manifest key. Fix the underlying validation, IAM, or Glue issue first. Re-submit messages in small batches to the validator Lambda; preserve message bodies and delete them only after a successful Glue job start is recorded.

## Evidence to capture

Capture queue depth before/after, sampled message IDs, manifest keys, Lambda request IDs, Glue job run IDs, and the reason the original delivery failed.
