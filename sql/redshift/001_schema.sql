CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.dim_artist (
    artist_id varchar(64) NOT NULL,
    artist_name varchar(512) NOT NULL,
    PRIMARY KEY (artist_id)
)
DISTSTYLE AUTO;

CREATE TABLE IF NOT EXISTS analytics.dim_track (
    track_id varchar(128) NOT NULL,
    artist_id varchar(64) NOT NULL,
    PRIMARY KEY (track_id)
)
DISTSTYLE AUTO;

CREATE TABLE IF NOT EXISTS analytics.fact_stream (
    event_id varchar(36) NOT NULL,
    user_id varchar(128) NOT NULL,
    track_id varchar(128) NOT NULL,
    artist_id varchar(64) NOT NULL,
    played_at timestamp NOT NULL,
    duration_seconds integer NOT NULL,
    platform varchar(32) NOT NULL,
    ingest_date date NOT NULL,
    PRIMARY KEY (event_id)
)
DISTSTYLE AUTO
SORTKEY (ingest_date, played_at);

CREATE TABLE IF NOT EXISTS analytics.daily_listening_metrics (
    ingest_date date NOT NULL,
    platform varchar(32) NOT NULL,
    event_count bigint NOT NULL,
    unique_listener_count bigint NOT NULL,
    listening_seconds bigint NOT NULL,
    PRIMARY KEY (ingest_date, platform)
)
DISTSTYLE AUTO
SORTKEY (ingest_date);

CREATE TABLE IF NOT EXISTS analytics.stg_fact_stream (
    event_id varchar(36) NOT NULL,
    user_id varchar(128) NOT NULL,
    track_id varchar(128) NOT NULL,
    artist_id varchar(64) NOT NULL,
    played_at timestamp NOT NULL,
    duration_seconds integer NOT NULL,
    platform varchar(32) NOT NULL,
    ingest_date date NOT NULL
)
DISTSTYLE AUTO;
