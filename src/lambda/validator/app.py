import os
import re
import uuid
from urllib.parse import unquote_plus


MANIFEST_PATTERN = re.compile(r"^raw/source=[^/]+/ingest_date=(\d{4}-\d{2}-\d{2})/manifest\.json$")


def validate_manifest(record: dict) -> dict:
    key = unquote_plus(record["key"])
    match = MANIFEST_PATTERN.fullmatch(key)
    if not match:
        raise ValueError("S3 object must be a raw partition manifest")

    return {
        "bucket": record["bucket"],
        "raw_prefix": key.removesuffix("manifest.json"),
        "ingest_date": match.group(1),
    }


def lambda_handler(event: dict, _context: object) -> dict:
    import boto3

    glue = boto3.client("glue")
    started = []
    for record in event.get("Records", []):
        manifest = validate_manifest({
            "bucket": record["s3"]["bucket"]["name"],
            "key": record["s3"]["object"]["key"],
        })
        run_id = str(uuid.uuid4())
        response = glue.start_job_run(
            JobName=os.environ["GLUE_JOB_NAME"],
            Arguments={
                "--raw-prefix": manifest["raw_prefix"],
                "--ingest-date": manifest["ingest_date"],
                "--run-id": run_id,
            },
        )
        started.append({"run_id": run_id, "glue_job_run_id": response["JobRunId"]})
    return {"started": started}
