"""Reusable data-quality helpers for Glue Spark jobs."""

from collections.abc import Sequence

from pyspark.sql import DataFrame
from pyspark.sql import functions as F


def validate_required_columns(dataframe: DataFrame, columns: Sequence[str]) -> tuple[DataFrame, DataFrame]:
    """Split records into rows with all required values and rejected rows."""
    missing_columns = sorted(set(columns) - set(dataframe.columns))
    if missing_columns:
        raise ValueError(f"Dataframe is missing required columns: {', '.join(missing_columns)}")

    invalid_condition = F.lit(False)
    for column in columns:
        invalid_condition = invalid_condition | F.col(column).isNull() | (F.trim(F.col(column)) == "")

    return dataframe.filter(~invalid_condition), dataframe.filter(invalid_condition)


def quarantine_invalid_records(dataframe: DataFrame, path: str) -> None:
    """Append invalid records to a durable Parquet quarantine location."""
    dataframe.write.mode("append").parquet(path)


def deduplicate_events(dataframe: DataFrame, key: str = "event_id") -> DataFrame:
    """Keep the first record for each event key."""
    if key not in dataframe.columns:
        raise ValueError(f"Dataframe is missing deduplication key: {key}")
    return dataframe.dropDuplicates([key])
