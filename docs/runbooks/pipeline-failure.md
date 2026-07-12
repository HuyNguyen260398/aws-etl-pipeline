# Pipeline failure runbook

## Detection query

In CloudWatch Logs Insights, select `/aws/lambda/<validator>` and the two `/aws-glue/jobs/<job>` groups, then run:

```text
fields @timestamp, @message
| filter @message like /ERROR|FAILED|TIMEOUT/
| sort @timestamp desc
| limit 100
```

## Impact

Raw manifests may not reach clean or analytics data. Kinesis records remain in the source stream until retention expires; batch data stays immutable in the raw zone.

## Safe remediation

Confirm the failed run's raw prefix and run ID, correct the upstream data or permission issue, then start only the raw-to-clean job with that same raw prefix. Do not overwrite raw objects or manually delete quarantine records.

On a successful raw-to-clean run, the orchestrator Lambda (`src/lambda/orchestrator/app.py`) fires on the EventBridge Glue Job State Change event and automatically starts `clean-to-analytics` — you do not start it by hand. If clean-to-analytics did not run after a successful raw-to-clean, check the orchestrator Lambda's log group and the EventBridge rule before starting it manually. It skips cleanly when a clean-to-analytics run is already in progress (`ConcurrentRunsExceededException`).

## Evidence to capture

Record the alarm name/state, Glue job run ID, Lambda request ID, raw prefix, quarantine object keys, error excerpts, and the remediation start/end time.
