# Аналитика рекламных кампаний на ClickHouse

Учебный проект: загружаем рекламные события, собираем дневную витрину и считаем эффективность кампаний. Источник данных - SQL-генератор, внешнего API нет.

**Стек:** ClickHouse 26.10, Docker, SQL. Разрабатывалось и проверялось на Windows (PowerShell 5.1) и ClickHouse 26.10.4.207.

## Что внутри

- 4 рекламных канала и 6 кампаний с разными бюджетами и целевыми аудиториями;
- 36 000 синтетических событий за **1–20 ноября 2026 г.**;
- витрина `campaign_kpi` по кампании, дню и каналу - 120 строк;
- пять запросов для маркетолога: ROI, CPA, низкий CTR, динамика расходов и доходов, отклонения от бюджета;
- проверка данных, партиций, TTL и времени выполнения запросов.

```text
ad-analytics-clickhouse/
├── sql/
│   ├── 01_create_tables.sql          # Схема, движки и TTL
│   ├── 02_insert_data.sql            # Справочники и события
│   ├── 03_build_kpi.sql              # Наполнение витрины
│   ├── 04_reports.sql                # Пять бизнес-запросов
│   ├── 05_optimization_checks.sql    # system.parts, merges, query_log
│   └── 06_validation.sql             # Контроль корректности
├── docs/
│   └── report.md                     # Решения и результаты
├── compose.yaml                      # Отдельный ClickHouse для проекта
├── .env.example                      # Пример локальных настроек
├── .gitignore
└── README.md
```

## Быстрый запуск в PowerShell

Нужны Docker Desktop и Docker Compose. Команды выполняются **в корне проекта**. Для нового развёртывания предусмотрен отдельный контейнер `ad-analytics-ch`, чтобы не мешать другим базам на компьютере. Порты на хосте - `18123` и `19000`.

1. Создать локальный конфигурационный файл:

   ```powershell
   Copy-Item .env.example .env
   notepad .env
   ```

   Заменить `change_this_password` своим локальным паролем. `.env` исключён из Git.

2. Запустить ClickHouse:

   ```powershell
   docker compose up -d
   ```

3. Скопировать SQL-файлы в контейнер и выполнить их по порядку:

   ```powershell
   $Container = 'ad-analytics-ch'
   $Password = Read-Host 'Пароль ClickHouse из .env'
   $SqlFiles = Get-ChildItem .\sql\*.sql | Sort-Object Name

   foreach ($File in $SqlFiles) {
       docker cp $File.FullName "${Container}:/tmp/$($File.Name)"
       if ($LASTEXITCODE -ne 0) { throw "Не удалось скопировать $($File.Name)" }

       docker exec $Container clickhouse-client "--password=$Password" "--queries-file=/tmp/$($File.Name)"
       if ($LASTEXITCODE -ne 0) { throw "Ошибка при запуске $($File.Name)" }
   }
   ```

   Если контейнер только запустился и подключение отклоняется, проверьте его статус (`docker compose ps`) и повторите шаг 3 после запуска сервера.

4. Для ручной проверки можно подключиться к SQL-консоли:

   ```powershell
   docker exec -it ad-analytics-ch clickhouse-client "--password=$Password" --database=ad_analytics
   ```

   ```sql
   SELECT count() FROM raw_ads_events; -- 36000
   SELECT count() FROM campaign_kpi;   -- 120
   ```

**Уже есть контейнер `clickhouse-server`?** Запускать Compose необязательно. Задайте `$Container = 'clickhouse-server'` в шаге 3, используйте его пароль и запускайте файлы в этом контейнере. На уже заполненной базе достаточно `04_reports.sql`, `05_optimization_checks.sql` и `06_validation.sql` - файлы 02 и 03 очищают учебные таблицы перед пересборкой.

Остановить отдельный контейнер: `docker compose down`. Данные сохраняются в Docker volume; `docker compose down -v` удалит **и** данные.

## Модель данных

| Таблица | Назначение | Ключ сортировки |
| --- | --- | --- |
| `channels` | Справочник рекламных каналов | `channel_id` |
| `campaigns` | Кампании, даты, бюджет и аудитория | `campaign_id` |
| `raw_ads_events` | Исходные показы, клики и конверсии | `campaign_id, event_date, channel_id, event_id` |
| `campaign_kpi` | Дневные агрегаты и KPI | `event_date, campaign_id, channel_id` |

Сырые события и витрина разбиваются на месячные партиции. Для них настроены TTL в 1 год и 2 года соответственно. Поля `event_type`, `device`, `country` используют `LowCardinality(String)`; денежные суммы - `Decimal`.

```text
channels ── campaigns
   │           │
   └─────┬─────┘
         │
   raw_ads_events
         │ GROUP BY (campaign_id, event_date, channel_id)
         ▼
     campaign_kpi ── отчёты
```

## Расчёт KPI

| Метрика | Логика |
| --- | --- |
| Impressions / Clicks / Conversions | Количество событий соответствующего типа |
| Spend | Сумма `cost` на кликах |
| Revenue | Сумма `revenue` на конверсиях |
| CTR | `clicks / impressions * 100` |
| CVR | `conversions / clicks * 100` |
| CPA | `spend / conversions` |
| ROI | `(revenue - spend) / spend * 100` |

При нулевом знаменателе в учебной витрине записывается `0`. Для сводных отчётов KPI пересчитываются из **сумм**, а не суммированием дневных процентов.

## Полученные результаты

После полной загрузки: **35 019 показов, 871 клик и 110 конверсий**. Общие расходы - **389 526 ₽**, доходы - **356 113 ₽**.

По итогам всего периода максимальный ROI у кампании 101 «Осенняя распродажа» (42,87%), а по последним семи дням в наборе данных - у кампании 103 «Продвижение приложения» (44,14%). У кампании 104 «Повторные покупки» 20 ноября расходы превысили дневной бюджет на 2 370 ₽.

Все 6 SQL-файлов были проверены на действующей базе; затем база воспроизведена с нуля в отдельном временном контейнере. Подробности, ограничения и замеры производительности - в [отчёте](docs/report.md).

## Ограничения

- Данные синтетические: события не связаны с конкретными пользователями; CVR - отношение агрегированных конверсий к кликам, а не персональная воронка.
- Отчёт за «последние 7 дней» считает период от **максимальной даты в таблице**, поскольку набор статический.
- `MergeTree` не гарантирует уникальность ключей: для повторной загрузки в учебных скриптах используется `TRUNCATE`.
- Наполнение витрины пакетное (`INSERT ... SELECT`), без `Materialized View`.
- Локальные SQL-проверки и повторное развёртывание подтверждены. Отдельная автопроверка учебной платформы не запускалась.
