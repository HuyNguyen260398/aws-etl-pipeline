"""Build analytics-ready fact and dimension Parquet datasets from clean events."""

import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F


def write_parquet(dataframe, path: str) -> None:
    dataframe.write.mode("append").option("compression", "snappy").parquet(path)


def resolve_argument(arguments: list[str], name: str) -> str:
    option = f"--{name}"
    try:
        return arguments[arguments.index(option) + 1]
    except (ValueError, IndexError) as error:
        raise ValueError(f"Missing required Glue argument: {option}") from error


def main() -> None:
    job_name = resolve_argument(sys.argv, "JOB_NAME")
    clean_prefix = resolve_argument(sys.argv, "clean-prefix")
    analytics_prefix = resolve_argument(sys.argv, "analytics-prefix")
    spark_context = SparkContext.getOrCreate()
    glue_context = GlueContext(spark_context)
    spark = glue_context.spark_session
    job = Job(glue_context)
    job.init(job_name, {})

    clean_events = spark.read.parquet(clean_prefix)
    enriched_events = clean_events.withColumn("artist_id", F.sha2(F.col("artist_name"), 256))

    fact_stream = enriched_events.select(
        "event_id", "user_id", "track_id", "artist_id", "played_at", "duration_seconds", "platform", "ingest_date"
    )
    dim_artist = enriched_events.select("artist_id", "artist_name").dropDuplicates(["artist_id"])
    dim_track = enriched_events.select("track_id", "artist_id").dropDuplicates(["track_id"])
    daily_listening_metrics = enriched_events.groupBy("ingest_date", "platform").agg(
        F.countDistinct("event_id").alias("event_count"),
        F.countDistinct("user_id").alias("unique_listener_count"),
        F.sum("duration_seconds").alias("listening_seconds"),
    )

    base_path = analytics_prefix.rstrip("/")
    write_parquet(fact_stream, f"{base_path}/fact_stream/")
    write_parquet(dim_artist, f"{base_path}/dim_artist/")
    write_parquet(dim_track, f"{base_path}/dim_track/")
    write_parquet(daily_listening_metrics, f"{base_path}/daily_listening_metrics/")
    job.commit()


if __name__ == "__main__":
    main()
