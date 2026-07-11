"""Local PySpark tests for Glue data-quality helpers."""

from pathlib import Path
import sys

import pytest
from pyspark.sql import SparkSession


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY_ROOT / "src"))

from glue.lib.quality import (  # noqa: E402
    deduplicate_events,
    quarantine_invalid_records,
    validate_required_columns,
)


@pytest.fixture(scope="session")
def spark() -> SparkSession:
    session = (
        SparkSession.builder.master("local[1]")
        .appName("music-streaming-quality-tests")
        .config("spark.ui.enabled", "false")
        .getOrCreate()
    )
    yield session
    session.stop()


@pytest.fixture
def events(spark: SparkSession):
    return spark.createDataFrame(
        [
            ("event-1", "user-1", "track-1", "Artist One"),
            ("event-1", "user-1", "track-1", "Artist One"),
            ("event-2", None, "track-2", "Artist Two"),
        ],
        ["event_id", "user_id", "track_id", "artist_name"],
    )


def test_deduplicate_events_keeps_one_record_per_event_id(events) -> None:
    assert deduplicate_events(events).count() == 2


def test_validation_and_quarantine_write_null_required_records(events, tmp_path, spark: SparkSession) -> None:
    valid_records, invalid_records = validate_required_columns(events, ["event_id", "user_id", "track_id"])

    assert valid_records.count() == 2
    assert invalid_records.count() == 1

    quarantine_path = tmp_path / "quarantine"
    quarantine_invalid_records(invalid_records, str(quarantine_path))

    persisted_records = spark.read.parquet(str(quarantine_path))
    assert persisted_records.select("event_id").first()[0] == "event-2"
    assert persisted_records.select("user_id").first()[0] is None
