"""Contract tests for Music Streaming Habits events."""

import csv
import json
from pathlib import Path

import jsonschema
import pytest


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = REPOSITORY_ROOT / "src/contracts/music_event.schema.json"
SAMPLE_PATH = REPOSITORY_ROOT / "data/sample/music_streaming_habits.csv"


@pytest.fixture(scope="module")
def schema() -> dict:
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def valid_event() -> dict:
    with SAMPLE_PATH.open(newline="", encoding="utf-8") as sample_file:
        event = next(csv.DictReader(sample_file))
    event["duration_seconds"] = int(event["duration_seconds"])
    return event


def test_sample_event_conforms_to_versioned_contract(schema: dict, valid_event: dict) -> None:
    jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker()).validate(valid_event)


def test_contract_rejects_event_without_event_id(schema: dict, valid_event: dict) -> None:
    invalid_event = valid_event.copy()
    invalid_event.pop("event_id")

    with pytest.raises(jsonschema.ValidationError, match="event_id"):
        jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker()).validate(invalid_event)
