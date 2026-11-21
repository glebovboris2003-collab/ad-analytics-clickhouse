USE ad_analytics;

-- Полная пересборка витрины вместо повторной вставки тех же агрегатов.
TRUNCATE TABLE campaign_kpi;

INSERT INTO campaign_kpi
SELECT
    campaign_id,
    event_date,
    channel_id,
    impressions,
    clicks,
    conversions,
    spend,
    revenue,
    if(impressions = 0, 0,
       round(clicks * 100.0 / greatest(impressions, 1), 2)) AS ctr,
    if(clicks = 0, 0,
       round(conversions * 100.0 / greatest(clicks, 1), 2)) AS cvr,
    if(conversions = 0, 0,
       round(toFloat64(spend) / greatest(conversions, 1), 2)) AS cpa,
    if(spend = 0, 0,
       round((toFloat64(revenue) - toFloat64(spend)) * 100.0 /
             greatest(toFloat64(spend), 1.0), 2)) AS roi
FROM
(
    SELECT
        campaign_id,
        event_date,
        channel_id,
        countIf(event_type = 'impression') AS impressions,
        countIf(event_type = 'click') AS clicks,
        countIf(event_type = 'conversion') AS conversions,
        sum(cost) AS spend,
        sum(revenue) AS revenue
    FROM raw_ads_events
    GROUP BY campaign_id, event_date, channel_id
);
