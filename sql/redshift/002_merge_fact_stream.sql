BEGIN;

TRUNCATE TABLE analytics.stg_fact_stream;

COPY analytics.stg_fact_stream
FROM 's3://REPLACE_WITH_DATA_LAKE_BUCKET/analytics/fact_stream/'
IAM_ROLE 'REPLACE_WITH_REDSHIFT_ROLE_ARN'
FORMAT AS PARQUET;

MERGE INTO analytics.fact_stream
USING analytics.stg_fact_stream source_record
    ON analytics.fact_stream.event_id = source_record.event_id
WHEN MATCHED THEN
    UPDATE SET
        user_id = source_record.user_id,
        track_id = source_record.track_id,
        artist_id = source_record.artist_id,
        played_at = source_record.played_at,
        duration_seconds = source_record.duration_seconds,
        platform = source_record.platform,
        ingest_date = source_record.ingest_date
WHEN NOT MATCHED THEN INSERT (
    event_id,
    user_id,
    track_id,
    artist_id,
    played_at,
    duration_seconds,
    platform,
    ingest_date
) VALUES (
    source_record.event_id,
    source_record.user_id,
    source_record.track_id,
    source_record.artist_id,
    source_record.played_at,
    source_record.duration_seconds,
    source_record.platform,
    source_record.ingest_date
);

COMMIT;
