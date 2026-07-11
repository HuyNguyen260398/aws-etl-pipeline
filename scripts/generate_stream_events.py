#!/usr/bin/env python3
"""Generate deterministic Music Streaming Habits events for Kinesis."""

import argparse
import json
import os
import random
import sys
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Iterable


PLATFORMS = ("android", "ios", "web", "desktop")
ARTISTS = ("The Sample Artists", "Signal & Sound", "Northern Echo", "Late Night Loops")
EVENT_NAMESPACE = uuid.UUID("872c34cb-07a8-461e-a446-7594c7f2fb22")


def generate_events(seed: int, count: int) -> Iterable[dict[str, Any]]:
    """Yield `count` seeded events conforming to music-event contract v1.0.0."""
    randomizer = random.Random(seed)
    start = datetime(2026, 1, 1, tzinfo=timezone.utc)
    for index in range(count):
        played_at = start + timedelta(
            days=randomizer.randrange(365),
            seconds=randomizer.randrange(86_400),
        )
        artist = randomizer.choice(ARTISTS)
        yield {
            "event_id": str(uuid.uuid5(EVENT_NAMESPACE, f"{seed}:{index}")),
            "user_id": f"user-{randomizer.randrange(1, 10_001):05d}",
            "track_id": f"track-{randomizer.randrange(1, 100_001):06d}",
            "artist_name": artist,
            "played_at": played_at.isoformat().replace("+00:00", "Z"),
            "duration_seconds": randomizer.randrange(30, 601),
            "platform": randomizer.choice(PLATFORMS),
            "ingest_date": played_at.date().isoformat(),
        }


def publish_events(events: Iterable[dict[str, Any]], stream_name: str) -> None:
    """Publish events with the AWS SDK default credential chain."""
    import boto3

    client = boto3.client("kinesis")
    records = [
        {
            "Data": json.dumps(event, separators=(",", ":")).encode("utf-8"),
            "PartitionKey": event["user_id"],
        }
        for event in events
    ]
    for offset in range(0, len(records), 500):
        response = client.put_records(StreamName=stream_name, Records=records[offset : offset + 500])
        if response["FailedRecordCount"]:
            raise RuntimeError(f"Kinesis rejected {response['FailedRecordCount']} records")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, required=True, help="Seed for deterministic event generation")
    parser.add_argument("--count", type=int, required=True, help="Number of events to create")
    parser.add_argument("--dry-run", action="store_true", help="Print JSON records instead of publishing")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.count < 1:
        print("--count must be at least 1", file=sys.stderr)
        return 2

    events = list(generate_events(args.seed, args.count))
    if args.dry_run:
        for event in events:
            print(json.dumps(event, separators=(",", ":")))
        return 0

    stream_name = os.environ.get("KINESIS_STREAM_NAME")
    if not stream_name:
        print("KINESIS_STREAM_NAME must be set to publish events.", file=sys.stderr)
        return 1
    publish_events(events, stream_name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
