USE ad_analytics;

-- Повторный запуск заменяет учебные данные в трех исходных таблицах.
-- Витрину пересоберите скриптом 03_build_kpi.sql.
TRUNCATE TABLE channels;
TRUNCATE TABLE campaigns;
TRUNCATE TABLE raw_ads_events;

INSERT INTO channels (channel_id, channel_name, channel_type)
VALUES
    (1, 'Google Ads', 'Search'),
    (2, 'Yandex Direct', 'Search'),
    (3, 'VK Ads', 'Social'),
    (4, 'Telegram Ads', 'Social');

INSERT INTO campaigns
    (campaign_id, campaign_name, channel_id,
     start_date, end_date, daily_budget, target_audience)
VALUES
    (101, 'Осенняя распродажа', 1,
     '2026-10-01', '2026-11-30', 15000, '18-35 лет'),
    (102, 'Новые клиенты', 2,
     '2026-10-10', '2026-12-15', 12000, '25-45 лет'),
    (103, 'Продвижение приложения', 3,
     '2026-10-15', '2026-12-01', 8000, '18-30 лет'),
    (104, 'Повторные покупки', 4,
     '2026-10-20', '2026-11-30', 5000, 'Постоянные клиенты'),
    (105, 'Скидки на электронику', 1,
     '2026-10-25', '2026-12-20', 20000, '25-40 лет'),
    (106, 'Зимняя акция', 4,
     '2026-11-01', '2026-12-31', 7000, '20-45 лет');

-- По 300 событий на кампанию за каждый из 20 дней.
-- Расход отражаем на клике, доход — на конверсии.
INSERT INTO raw_ads_events
    (event_id, event_date, campaign_id, channel_id,
     event_type, cost, revenue, device, country)
SELECT
    generateUUIDv4(),
    event_date,
    campaign_id,
    channel_id,
    event_type,
    if(event_type = 'click',
       toDecimal64(200 + cityHash64(number + 17) % 500, 2),
       toDecimal64(0, 2)) AS cost,
    if(event_type = 'conversion',
       toDecimal64(1200 + cityHash64(number + 29) % 3800, 2),
       toDecimal64(0, 2)) AS revenue,
    arrayElement(['mobile', 'desktop', 'tablet'],
        toUInt32(cityHash64(number + 3) % 3 + 1)) AS device,
    arrayElement(['RU', 'KZ', 'BY', 'UZ'],
        toUInt32(cityHash64(number + 5) % 4 + 1)) AS country
FROM
(
    SELECT
        number,
        toUInt32(101 + number % 6) AS campaign_id,
        addDays(toDate('2026-11-01'),
                toInt32(intDiv(number, 6) % 20)) AS event_date,
        multiIf(
            campaign_id IN (101, 105), 1,
            campaign_id = 102, 2,
            campaign_id = 103, 3,
            4
        ) AS channel_id,
        cityHash64(number + 11) % 1000 AS chance,
        multiIf(
            campaign_id = 101, 6,
            campaign_id = 102, 20,
            campaign_id = 103, 32,
            campaign_id = 104, 46,
            campaign_id = 105, 26,
            12
        ) AS click_limit,
        multiIf(
            campaign_id = 101, 1,
            campaign_id = 102, 3,
            campaign_id = 103, 4,
            campaign_id = 104, 6,
            campaign_id = 105, 3,
            2
        ) AS conversion_limit,
        multiIf(
            chance < click_limit, 'click',
            chance < click_limit + conversion_limit, 'conversion',
            'impression'
        ) AS event_type
    FROM numbers(36000)
);
