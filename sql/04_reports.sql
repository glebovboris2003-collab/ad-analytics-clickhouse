USE ad_analytics;

-- 1. Топ-5 кампаний по ROI за последние семь дней в наборе данных.
SELECT
    c.campaign_id,
    c.campaign_name,
    k.total_spend,
    k.total_revenue,
    if(k.total_spend = 0, 0,
       round((toFloat64(k.total_revenue) - toFloat64(k.total_spend)) * 100 /
             greatest(toFloat64(k.total_spend), 1.0), 2)) AS roi
FROM
(
    SELECT campaign_id,
           sum(spend) AS total_spend,
           sum(revenue) AS total_revenue
    FROM campaign_kpi
    WHERE event_date >=
        (SELECT addDays(max(event_date), -6) FROM campaign_kpi)
    GROUP BY campaign_id
) AS k
INNER JOIN campaigns AS c ON k.campaign_id = c.campaign_id
ORDER BY roi DESC
LIMIT 5;

-- 2. Каналы с минимальным CPA. Нет конверсий — CPA неопределен.
SELECT
    ch.channel_name,
    k.total_conversions,
    k.total_spend,
    round(toFloat64(k.total_spend) / k.total_conversions, 2) AS cpa
FROM
(
    SELECT channel_id,
           sum(conversions) AS total_conversions,
           sum(spend) AS total_spend
    FROM campaign_kpi
    GROUP BY channel_id
    HAVING sum(conversions) > 0
) AS k
INNER JOIN channels AS ch ON k.channel_id = ch.channel_id
ORDER BY cpa ASC
LIMIT 5;

-- 3. Кампании с CTR ниже 1%.
SELECT
    c.campaign_id,
    c.campaign_name,
    k.total_impressions,
    k.total_clicks,
    round(k.total_clicks * 100.0 / k.total_impressions, 2) AS ctr
FROM
(
    SELECT campaign_id,
           sum(impressions) AS total_impressions,
           sum(clicks) AS total_clicks
    FROM campaign_kpi
    GROUP BY campaign_id
) AS k
INNER JOIN campaigns AS c ON k.campaign_id = c.campaign_id
WHERE k.total_impressions > 0
  AND k.total_clicks * 100.0 / k.total_impressions < 1
ORDER BY ctr ASC;

-- 4. Ежедневные расходы, доходы и разница для кампании 101.
SELECT
    event_date,
    sum(spend) AS daily_spend,
    sum(revenue) AS daily_revenue,
    sum(revenue) - sum(spend) AS daily_profit
FROM campaign_kpi
WHERE campaign_id = 101
GROUP BY event_date
ORDER BY event_date;

-- 5. Расходы против дневного бюджета за последнюю дату набора.
SELECT
    k.event_date,
    c.campaign_name,
    c.daily_budget,
    sum(k.spend) AS actual_spend,
    round(toFloat64(sum(k.spend)) - toFloat64(c.daily_budget), 2)
        AS budget_difference,
    if(c.daily_budget = 0, 0,
       round(toFloat64(sum(k.spend)) * 100.0 /
             greatest(toFloat64(c.daily_budget), 1.0), 2))
        AS budget_used_pct
FROM campaign_kpi AS k
INNER JOIN campaigns AS c ON k.campaign_id = c.campaign_id
WHERE k.event_date = (SELECT max(event_date) FROM campaign_kpi)
GROUP BY k.event_date, c.campaign_id, c.campaign_name, c.daily_budget
ORDER BY budget_used_pct DESC;
