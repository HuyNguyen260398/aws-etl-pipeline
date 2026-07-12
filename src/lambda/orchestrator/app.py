"""Start the clean-to-analytics Glue job when raw-to-clean succeeds.

Invoked by EventBridge on a Glue Job State Change (raw-to-clean SUCCEEDED).
Standalone Glue conditional triggers do not fire for jobs started outside a
workflow, so this event-driven Lambda performs the chaining instead.
"""

import os


def lambda_handler(event: dict, _context: object) -> dict:
    import boto3

    glue = boto3.client("glue")
    job_name = os.environ["GLUE_JOB_NAME"]
    try:
        response = glue.start_job_run(JobName=job_name)
        return {"started": response["JobRunId"]}
    except glue.exceptions.ConcurrentRunsExceededException:
        # A clean-to-analytics run is already processing the clean zone.
        return {"skipped": "clean-to-analytics already running"}
