# Music streaming event contract

`src/contracts/music_event.schema.json` defines version **1.0.0** of the immutable streaming-event payload. Producers publish one JSON object per Kinesis record; raw records are retained unchanged, while Glue validates them before writing canonical Parquet to the clean zone.

## Required fields

| Field | Type | Rule |
|---|---|---|
| `event_id` | UUID string | Stable, globally unique event key. |
| `user_id` | string | Non-empty source user identifier. |
| `track_id` | string | Non-empty source track identifier. |
| `artist_name` | string | Non-empty artist name. |
| `played_at` | RFC 3339 timestamp | UTC event timestamp. |
| `duration_seconds` | integer | Positive playback duration. |
| `platform` | string | One of `android`, `ios`, `web`, or `desktop`. |
| `ingest_date` | ISO date | UTC partition date derived from ingestion. |

The contract rejects omitted fields, nulls, unknown fields, empty identifiers, non-positive durations, and unsupported platforms. Breaking changes require a new major schema version and a new `$id`.

## Local development data

`data/sample/music_streaming_habits.csv` is a small, synthetic fixture for local contract tests. It is not the Kaggle dataset and must remain safe to commit.

To download the Kaggle snapshot, set credentials only in your shell and choose a Git-ignored destination:

```bash
export KAGGLE_USERNAME="..."
export KAGGLE_KEY="..."
scripts/download_dataset.sh data/downloads/kaggle
```

The downloader uses the dataset slug `uditjain13/music-streaming-habits-2026`; downloaded files must not be committed.

## Deterministic stream events

Generate ten local records without AWS access:

```bash
python scripts/generate_stream_events.py --seed 2026 --count 10 --dry-run
```

To publish, remove `--dry-run` and set `KINESIS_STREAM_NAME`. The generator creates its Kinesis client with the AWS SDK default credential chain, so it accepts standard AWS profile, environment, workload, or assumed-role credentials and never reads credentials from source files.
