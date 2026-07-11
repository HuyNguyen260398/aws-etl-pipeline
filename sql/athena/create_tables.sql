CREATE EXTERNAL TABLE IF NOT EXISTS music_analytics.fact_stream (
    event_id string,
    user_id string,
    track_id string,
    artist_id string,
    played_at timestamp,
    duration_seconds int,
    platform string
)
PARTITIONED BY (ingest_date date)
STORED AS PARQUET
LOCATION 's3://REPLACE_WITH_DATA_LAKE_BUCKET/analytics/fact_stream/'
TBLPROPERTIES ('parquet.compression' = 'SNAPPY');

CREATE EXTERNAL TABLE IF NOT EXISTS music_analytics.dim_artist (
    artist_id string,
    artist_name string
)
STORED AS PARQUET
LOCATION 's3://REPLACE_WITH_DATA_LAKE_BUCKET/analytics/dim_artist/'
TBLPROPERTIES ('parquet.compression' = 'SNAPPY');

CREATE EXTERNAL TABLE IF NOT EXISTS music_analytics.dim_track (
    track_id string,
    artist_id string
)
STORED AS PARQUET
LOCATION 's3://REPLACE_WITH_DATA_LAKE_BUCKET/analytics/dim_track/'
TBLPROPERTIES ('parquet.compression' = 'SNAPPY');

CREATE EXTERNAL TABLE IF NOT EXISTS music_analytics.daily_listening_metrics (
    platform string,
    event_count bigint,
    unique_listener_count bigint,
    listening_seconds bigint
)
PARTITIONED BY (ingest_date date)
STORED AS PARQUET
LOCATION 's3://REPLACE_WITH_DATA_LAKE_BUCKET/analytics/daily_listening_metrics/'
TBLPROPERTIES ('parquet.compression' = 'SNAPPY');
