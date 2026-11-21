USE ad_analytics;

SELECT 'channels' AS table_name, count() AS rows_count FROM channels
UNION ALL
SELECT 'campaigns', count() FROM campaigns
UNION ALL
SELECT 'raw_ads_events', count() FROM raw_ads_events
UNION ALL
SELECT 'campaign_kpi', count() FROM campaign_kpi;

SELECT event_type, count() AS events_count
FROM raw_ads_events
GROUP BY event_type
ORDER BY event_type;

SELECT
    uniqExact(campaign_id) AS campaign_count,
    uniqExact(device) AS device_count,
    uniqExact(country) AS country_count,
    min(event_date) AS start_date,
    max(event_date) AS end_date
FROM raw_ads_events;

-- Сравнение общего числа исходных событий с агрегатами витрины.
SELECT
    (SELECT count() FROM raw_ads_events) AS source_events,
    (SELECT sum(impressions + clicks + conversions)
     FROM campaign_kpi) AS mart_events,
    source_events = mart_events AS counts_match;

-- Сравнение расходов и доходов между исходными событиями и витриной.
SELECT
    (SELECT sum(cost) FROM raw_ads_events) AS raw_spend,
    (SELECT sum(spend) FROM campaign_kpi) AS mart_spend,
    (SELECT sum(revenue) FROM raw_ads_events) AS raw_revenue,
    (SELECT sum(revenue) FROM campaign_kpi) AS mart_revenue;

-- Дубликаты ключа дневной витрины: результат должен быть пустым.
SELECT
    campaign_id, event_date, channel_id, count() AS rows_count
FROM campaign_kpi
GROUP BY campaign_id, event_date, channel_id
HAVING count() > 1;

-- Наличие пустых знаменателей для проверки граничных случаев.
SELECT
    countIf(impressions = 0) AS zero_impressions,
    countIf(clicks = 0) AS zero_clicks,
    countIf(conversions = 0) AS zero_conversions,
    countIf(spend = 0) AS zero_spend
FROM campaign_kpi;
