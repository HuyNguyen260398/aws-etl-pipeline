"""Validate a supplied raw S3 prefix and write canonical clean Parquet."""

from datetime import datetime, timezone
from typing import Sequence

from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import DataFrame
from pyspark.sql import functions as F

from glue.lib.quality import deduplicate_events, quarantine_invalid_records, validate_required_columns


REQUIRED_COLUMNS: Sequence[str] = (
    "event_id",
    "user_id",
    "track_id",
    "artist_name",
    "played_at",
    "duration_seconds",
    "platform",
    "ingest_date",
)


def ensure_required_columns(dataframe: DataFrame) -> DataFrame:
    """Add null placeholders so records missing a field can be quarantined."""
    for column in REQUIRED_COLUMNS:
        if column not in dataframe.columns:
            dataframe = dataframe.withColumn(column, F.lit(None).cast("string"))
    return dataframe


def normalize_timestamps(dataframe: DataFrame) -> DataFrame:
    """Normalize event timestamps to UTC and reject unparseable values."""
    return dataframe.withColumn("played_at", F.to_utc_timestamp(F.to_timestamp("played_at"), "UTC"))


def resolve_argument(arguments: Sequence[str], name: str) -> str:
    """Read a Glue job argument while preserving the Lambda's hyphenated names."""
    option = f"--{name}"
    try:
        return arguments[arguments.index(option) + 1]
    except (ValueError, IndexError) as error:
        raise ValueError(f"Missing required Glue argument: {option}") from error


def main() -> None:
    import sys

    arguments = sys.argv
    job_name = resolve_argument(arguments, "JOB_NAME")
    raw_prefix = resolve_argument(arguments, "raw-prefix")
    data_lake_bucket = resolve_argument(arguments, "data-lake-bucket")
    clean_prefix = resolve_argument(arguments, "clean-prefix")
    quarantine_prefix = resolve_argument(arguments, "quarantine-prefix")
    run_id = resolve_argument(arguments, "run-id")
    ingest_date = resolve_argument(arguments, "ingest-date")
    spark_context = SparkContext.getOrCreate()
    glue_context = GlueContext(spark_context)
    spark = glue_context.spark_session
    job = Job(glue_context)
    job.init(job_name, {})

    raw_path = raw_prefix if raw_prefix.startswith("s3://") else f"s3://{data_lake_bucket}/{raw_prefix.lstrip('/')}"
    raw_records = spark.read.json(raw_path)
    normalized_records = normalize_timestamps(ensure_required_columns(raw_records))
    required_valid_records, invalid_records = validate_required_columns(normalized_records, REQUIRED_COLUMNS)
    timestamp_invalid_records = required_valid_records.filter(F.col("played_at").isNull())
    valid_records = required_valid_records.filter(F.col("played_at").isNotNull())
    invalid_records = invalid_records.unionByName(timestamp_invalid_records)

    quarantine_records = invalid_records.withColumn("run_id", F.lit(run_id)).withColumn(
        "quarantined_at", F.lit(datetime.now(timezone.utc).isoformat())
    )
    quarantine_invalid_records(quarantine_records, quarantine_prefix)

    clean_records = deduplicate_events(valid_records).withColumn("ingest_date", F.lit(ingest_date))
    (
        clean_records.write.mode("append")
        .option("compression", "snappy")
        .partitionBy("ingest_date")
        .parquet(clean_prefix)
    )
    job.commit()


if __name__ == "__main__":
    main()
