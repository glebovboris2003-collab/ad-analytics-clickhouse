CREATE DATABASE IF NOT EXISTS ad_analytics;
USE ad_analytics;

CREATE TABLE IF NOT EXISTS channels
(
    channel_id UInt16,
    channel_name String,
    channel_type String
)
ENGINE = MergeTree()
ORDER BY channel_id;

CREATE TABLE IF NOT EXISTS campaigns
(
    campaign_id UInt32,
    campaign_name String,
    channel_id UInt16,
    start_date Date,
    end_date Date,
    daily_budget Decimal(12, 2),
    target_audience String
)
ENGINE = MergeTree()
ORDER BY campaign_id;

CREATE TABLE IF NOT EXISTS raw_ads_events
(
    event_id UUID,
    event_date Date,
    campaign_id UInt32,
    channel_id UInt16,
    event_type LowCardinality(String),
    cost Decimal(12, 2),
    revenue Decimal(12, 2),
    device LowCardinality(String),
    country LowCardinality(String)
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_date)
ORDER BY (campaign_id, event_date, channel_id, event_id)
TTL event_date + INTERVAL 1 YEAR;

CREATE TABLE IF NOT EXISTS campaign_kpi
(
    campaign_id UInt32,
    event_date Date,
    channel_id UInt16,
    impressions UInt64,
    clicks UInt64,
    conversions UInt64,
    spend Decimal(14, 2),
    revenue Decimal(14, 2),
    ctr Float64,
    cvr Float64,
    cpa Float64,
    roi Float64
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, campaign_id, channel_id)
TTL event_date + INTERVAL 2 YEAR;
