CREATE OR REPLACE VIEW analytics.vw_dashboard_events AS
SELECT
    event_id,
    user_id,
    track_id,
    artist_id,
    played_at,
    duration_seconds,
    platform,
    ingest_date,
    CASE WHEN duration_seconds < 30 THEN 1 ELSE 0 END AS is_skip
FROM analytics.fact_stream;

CREATE OR REPLACE VIEW analytics.vw_daily_listening_minutes AS
SELECT
    CAST(played_at AS DATE) AS listening_date,
    SUM(duration_seconds) / 60.0 AS listening_minutes
FROM analytics.vw_dashboard_events
GROUP BY CAST(played_at AS DATE);

CREATE OR REPLACE VIEW analytics.vw_top_artists AS
SELECT
    artist.artist_name,
    COUNT(*) AS event_count,
    SUM(dashboard_event.duration_seconds) / 60.0 AS listening_minutes
FROM analytics.vw_dashboard_events AS dashboard_event
INNER JOIN analytics.dim_artist AS artist
    ON dashboard_event.artist_id = artist.artist_id
GROUP BY artist.artist_name;

CREATE OR REPLACE VIEW analytics.vw_platform_distribution AS
SELECT
    platform,
    COUNT(*) AS event_count,
    SUM(duration_seconds) / 60.0 AS listening_minutes
FROM analytics.vw_dashboard_events
GROUP BY platform;

CREATE OR REPLACE VIEW analytics.vw_skip_rate AS
SELECT
    CAST(played_at AS DATE) AS listening_date,
    AVG(CAST(is_skip AS DECIMAL(10, 4))) AS skip_rate
FROM analytics.vw_dashboard_events
GROUP BY CAST(played_at AS DATE);
