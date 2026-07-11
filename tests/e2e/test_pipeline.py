"""Deployed acceptance tests for the Music Streaming ETL pipeline."""

import json
import os
import time
import uuid
from datetime import datetime, timezone
from typing import Iterator

import boto3
import pytest


pytestmark = pytest.mark.integration

REQUIRED_ENVIRONMENT = (
    "AWS_REGION",
    "DATA_LAKE_BUCKET",
    "ATHENA_WORKGROUP",
    "REDSHIFT_WORKGROUP",
    "TEST_ROLE_ARN",
    "KINESIS_STREAM_NAME",
    "GLUE_RAW_TO_CLEAN_JOB_NAME",
    "REDSHIFT_SECRET_ARN",
)


def required_environment() -> dict[str, str]:
    missing = [name for name in REQUIRED_ENVIRONMENT if not os.environ.get(name)]
    if missing:
        pytest.skip(f"integration environment is not configured: {', '.join(missing)}")
    return {name: os.environ[name] for name in REQUIRED_ENVIRONMENT}


@pytest.fixture(scope="module")
def aws() -> dict[str, object]:
    configuration = required_environment()
    session = boto3.session.Session(region_name=configuration["AWS_REGION"])
    return {
        "configuration": configuration,
        "s3": session.client("s3"),
        "kinesis": session.client("kinesis"),
        "glue": session.client("glue"),
        "athena": session.client("athena"),
        "redshift_data": session.client("redshift-data"),
        "sts": session.client("sts"),
    }


def event(event_id: str, ingest_date: str) -> dict[str, object]:
    return {
        "event_id": event_id,
        "user_id": "acceptance-user",
        "track_id": "acceptance-track",
        "artist_name": "Acceptance Artist",
        "played_at": f"{ingest_date}T12:00:00Z",
        "duration_seconds": 180,
        "platform": "web",
        "ingest_date": ingest_date,
    }


def wait_for_glue_run(
    glue,
    job_name: str,
    run_id: str | None = None,
    raw_prefix: str | None = None,
    started_after: datetime | None = None,
    timeout_seconds: int = 900,
) -> None:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        response = glue.get_job_runs(JobName=job_name, MaxResults=25)
        for job_run in response["JobRuns"]:
            arguments = job_run["Arguments"]
            if run_id and arguments.get("--run-id") != run_id:
                continue
            if raw_prefix and arguments.get("--raw-prefix") != raw_prefix:
                continue
            if started_after and job_run["StartedOn"] < started_after:
                continue
            state = job_run["JobRunState"]
            if state == "SUCCEEDED":
                return
            if state in {"FAILED", "TIMEOUT", "STOPPED", "ERROR"}:
                raise AssertionError(f"Glue run {job_run['Id']} ended in {state}: {job_run.get('ErrorMessage', '')}")
        time.sleep(15)
    raise TimeoutError(f"Glue job {job_name} did not complete for the acceptance event")


def wait_for_objects(s3, bucket: str, prefix: str, timeout_seconds: int = 300) -> list[dict]:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
        objects = response.get("Contents", [])
        if any(item["Key"].endswith(".parquet") for item in objects):
            return objects
        time.sleep(10)
    raise TimeoutError(f"No Parquet objects appeared under s3://{bucket}/{prefix}")


def wait_for_any_object(s3, bucket: str, prefix: str, timeout_seconds: int = 300) -> list[dict]:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        objects = s3.list_objects_v2(Bucket=bucket, Prefix=prefix).get("Contents", [])
        if objects:
            return objects
        time.sleep(10)
    raise TimeoutError(f"No objects appeared under s3://{bucket}/{prefix}")


def wait_for_athena_query(athena, workgroup: str, query: str, database: str) -> list[list[dict]]:
    execution_id = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={"Database": database},
        WorkGroup=workgroup,
    )["QueryExecutionId"]
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        status = athena.get_query_execution(QueryExecutionId=execution_id)["QueryExecution"]["Status"]
        state = status["State"]
        if state == "SUCCEEDED":
            return athena.get_query_results(QueryExecutionId=execution_id)["ResultSet"]["Rows"]
        if state in {"FAILED", "CANCELLED"}:
            raise AssertionError(status.get("StateChangeReason", state))
        time.sleep(5)
    raise TimeoutError(f"Athena query {execution_id} did not complete")


def wait_for_redshift_statement(redshift_data, configuration: dict[str, str], sql: str) -> list[list[dict]]:
    statement_id = redshift_data.execute_statement(
        WorkgroupName=configuration["REDSHIFT_WORKGROUP"],
        Database="music_analytics",
        SecretArn=configuration["REDSHIFT_SECRET_ARN"],
        Sql=sql,
    )["Id"]
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        status = redshift_data.describe_statement(Id=statement_id)
        if status["Status"] == "FINISHED":
            return redshift_data.get_statement_result(Id=statement_id).get("Records", [])
        if status["Status"] in {"FAILED", "ABORTED"}:
            raise AssertionError(status.get("Error", status["Status"]))
        time.sleep(5)
    raise TimeoutError(f"Redshift statement {statement_id} did not complete")

@pytest.mark.parametrize("delivery", ["batch", "kinesis"])
def test_valid_events_are_accepted(aws: dict[str, object], delivery: str) -> None:
    configuration = aws["configuration"]
    ingest_date = datetime.now(timezone.utc).date().isoformat()
    event_id = str(uuid.uuid4())
    payload = event(event_id, ingest_date)

    if delivery == "batch":
        raw_prefix = f"raw/source=acceptance/ingest_date={ingest_date}/"
        started_after = datetime.now(timezone.utc)
        aws["s3"].put_object(
            Bucket=configuration["DATA_LAKE_BUCKET"],
            Key=f"{raw_prefix}events.json",
            Body=json.dumps(payload).encode("utf-8"),
            ContentType="application/json",
        )
        aws["s3"].put_object(
            Bucket=configuration["DATA_LAKE_BUCKET"],
            Key=f"{raw_prefix}manifest.json",
            Body=json.dumps({"source": "acceptance", "ingest_date": ingest_date}).encode("utf-8"),
            ContentType="application/json",
        )
        wait_for_glue_run(
            aws["glue"],
            configuration["GLUE_RAW_TO_CLEAN_JOB_NAME"],
            raw_prefix=raw_prefix,
            started_after=started_after,
        )
    else:
        aws["kinesis"].put_record(
            StreamName=configuration["KINESIS_STREAM_NAME"],
            Data=json.dumps(payload).encode("utf-8"),
            PartitionKey=payload["user_id"],
        )
        raw_prefix = f"raw/source=kinesis/ingest_date={ingest_date}/"
        wait_for_any_object(aws["s3"], configuration["DATA_LAKE_BUCKET"], raw_prefix)
        run_id = str(uuid.uuid4())
        aws["glue"].start_job_run(
            JobName=configuration["GLUE_RAW_TO_CLEAN_JOB_NAME"],
            Arguments={
                "--raw-prefix": raw_prefix,
                "--data-lake-bucket": configuration["DATA_LAKE_BUCKET"],
                "--run-id": run_id,
                "--ingest-date": ingest_date,
            },
        )
        wait_for_glue_run(aws["glue"], configuration["GLUE_RAW_TO_CLEAN_JOB_NAME"], run_id=run_id)


def test_clean_and_analytics_parquet_exist(aws: dict[str, object]) -> None:
    configuration = aws["configuration"]
    wait_for_objects(aws["s3"], configuration["DATA_LAKE_BUCKET"], "clean/")
    wait_for_objects(aws["s3"], configuration["DATA_LAKE_BUCKET"], "analytics/")


def test_athena_and_redshift_expose_merged_event(aws: dict[str, object]) -> None:
    configuration = aws["configuration"]
    athena_rows = wait_for_athena_query(
        aws["athena"],
        configuration["ATHENA_WORKGROUP"],
        "SELECT COUNT(*) AS event_count FROM music_analytics.fact_stream",
        "music_analytics",
    )
    assert int(athena_rows[1]["Data"][0]["VarCharValue"]) >= 1

    redshift_rows = wait_for_redshift_statement(
        aws["redshift_data"],
        configuration,
        "SELECT COUNT(*) FROM analytics.fact_stream",
    )
    assert int(redshift_rows[0][0]["longValue"]) >= 1


def test_invalid_record_is_quarantined(aws: dict[str, object]) -> None:
    configuration = aws["configuration"]
    ingest_date = datetime.now(timezone.utc).date().isoformat()
    raw_prefix = f"raw/source=acceptance-invalid/ingest_date={ingest_date}/"
    started_after = datetime.now(timezone.utc)
    invalid_event = event(str(uuid.uuid4()), ingest_date)
    invalid_event.pop("event_id")
    aws["s3"].put_object(
        Bucket=configuration["DATA_LAKE_BUCKET"],
        Key=f"{raw_prefix}invalid.json",
        Body=json.dumps(invalid_event).encode("utf-8"),
        ContentType="application/json",
    )
    aws["s3"].put_object(
        Bucket=configuration["DATA_LAKE_BUCKET"],
        Key=f"{raw_prefix}manifest.json",
        Body=json.dumps({"source": "acceptance-invalid", "ingest_date": ingest_date}).encode("utf-8"),
        ContentType="application/json",
    )
    wait_for_glue_run(
        aws["glue"],
        configuration["GLUE_RAW_TO_CLEAN_JOB_NAME"],
        raw_prefix=raw_prefix,
        started_after=started_after,
    )
    wait_for_objects(aws["s3"], configuration["DATA_LAKE_BUCKET"], "quarantine/")


def test_analytics_reader_cannot_query_raw(aws: dict[str, object]) -> None:
    configuration = aws["configuration"]
    credentials = aws["sts"].assume_role(RoleArn=configuration["TEST_ROLE_ARN"], RoleSessionName="music-etl-acceptance")["Credentials"]
    reader_athena = boto3.client(
        "athena",
        region_name=configuration["AWS_REGION"],
        aws_access_key_id=credentials["AccessKeyId"],
        aws_secret_access_key=credentials["SecretAccessKey"],
        aws_session_token=credentials["SessionToken"],
    )
    with pytest.raises(AssertionError):
        wait_for_athena_query(
            reader_athena,
            configuration["ATHENA_WORKGROUP"],
            "SELECT COUNT(*) FROM music_raw.events",
            "music_raw",
        )
