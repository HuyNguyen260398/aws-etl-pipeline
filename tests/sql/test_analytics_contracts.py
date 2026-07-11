"""Contract tests for analytics SQL and the local music-event fixture."""

import csv
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SAMPLE_PATH = REPOSITORY_ROOT / "data/sample/music_streaming_habits.csv"
ATHENA_SQL_PATH = REPOSITORY_ROOT / "sql/athena/create_tables.sql"
REDSHIFT_SCHEMA_PATH = REPOSITORY_ROOT / "sql/redshift/001_schema.sql"
REDSHIFT_MERGE_PATH = REPOSITORY_ROOT / "sql/redshift/002_merge_fact_stream.sql"


def test_sample_event_ids_are_unique() -> None:
    with SAMPLE_PATH.open(newline="", encoding="utf-8") as sample_file:
        event_ids = [record["event_id"] for record in csv.DictReader(sample_file)]

    assert event_ids
    assert len(event_ids) == len(set(event_ids))


def test_daily_metrics_models_expose_contract_columns() -> None:
    athena_sql = ATHENA_SQL_PATH.read_text(encoding="utf-8").lower()
    redshift_sql = REDSHIFT_SCHEMA_PATH.read_text(encoding="utf-8").lower()

    for column in ("ingest_date", "platform", "event_count", "unique_listener_count", "listening_seconds"):
        assert column in athena_sql
        assert column in redshift_sql


def test_redshift_merge_is_transactional_and_idempotent() -> None:
    merge_sql = REDSHIFT_MERGE_PATH.read_text(encoding="utf-8").lower()

    assert "begin;" in merge_sql
    assert "copy analytics.stg_fact_stream" in merge_sql
    assert "merge into analytics.fact_stream" in merge_sql
    assert "on target_record.event_id = source_record.event_id" in merge_sql
    assert "commit;" in merge_sql
