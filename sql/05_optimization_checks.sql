USE ad_analytics;

-- Описание таблиц: ключ сортировки, партиции, TTL.
SHOW CREATE TABLE raw_ads_events;
SHOW CREATE TABLE campaign_kpi;

-- Активные части и объем данных.
SELECT
    table, partition,
    count() AS parts_count,
    sum(rows) AS rows_count,
    formatReadableSize(sum(bytes_on_disk)) AS size
FROM system.parts
WHERE database = 'ad_analytics' AND active
GROUP BY table, partition
ORDER BY table, partition;

-- Идущие в данный момент фоновые слияния.
SELECT database, table, elapsed, progress, num_parts
FROM system.merges
WHERE database = 'ad_analytics';

SYSTEM FLUSH LOGS;

-- Время выполнения запросов к витрине.
SELECT
    event_time, query_duration_ms, read_rows, result_rows,
    formatReadableSize(memory_usage) AS memory
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query LIKE '%campaign_kpi%'
ORDER BY event_time DESC
LIMIT 10;
