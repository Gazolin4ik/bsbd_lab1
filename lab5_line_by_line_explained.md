# ЛР5 — построчное объяснение кода (простыми словами)

Ниже разобран **весь код ЛР5** из файлов проекта. Формат: **номер строки → строка → что она делает**.

---

## `lab5_task1_partitioning.sql` — секционирование (задание 1)

- **L1** `-- Task 1: create partitioned copy of shipments` — комментарий: начинаем задание 1 (партицирование).
- **L2** `CREATE TABLE IF NOT EXISTS app.shipments_partitioned (` — создаём новую таблицу, если её ещё нет.
- **L3** `LIKE app.shipments` — берём структуру (колонки) как у исходной таблицы `shipments`.
- **L4** `INCLUDING DEFAULTS` — копируем значения “по умолчанию” (DEFAULT) для колонок.
- **L5** `EXCLUDING CONSTRAINTS` — **не копируем ограничения** (PK/FK/CHECK), чтобы не словить конфликты при партицировании.
- **L6** `EXCLUDING INDEXES` — **не копируем индексы**, их создадим отдельно и только где нужно.
- **L7** `)` — закрываем описание таблицы.
- **L8** `PARTITION BY RANGE (created_at);` — включаем секционирование: делим данные по диапазонам даты `created_at`.
- **L9** *(пусто)* — просто разделение блоков.
- **L10** `COMMENT ON TABLE app.shipments_partitioned IS` — добавляем описание к таблице (для понятности в отчёте/pgAdmin).
- **L11** `'Секционированная версия shipments по дате created_at для аналитики';` — текст описания.
- **L12** *(пусто)* — разделение блоков.
- **L13** `-- Task 1: create archive and current partitions` — комментарий: создаём партиции (части таблицы).
- **L14** `CREATE TABLE IF NOT EXISTS app.shipments_p_archive` — создаём архивную партицию, если её нет.
- **L15** `PARTITION OF app.shipments_partitioned` — делаем её частью `shipments_partitioned`.
- **L16** `FOR VALUES FROM (MINVALUE) TO ('2026-01-01'::timestamp);` — архив: всё, что раньше `2026-01-01`.
- **L17** *(пусто)* — разделение блоков.
- **L18** `COMMENT ON TABLE app.shipments_p_archive IS` — описание архивной партиции.
- **L19** `'Архивная партиция shipments (старые периоды)';` — текст описания.
- **L20** *(пусто)* — разделение блоков.
- **L21** `CREATE TABLE IF NOT EXISTS app.shipments_p_current` — создаём “текущую” партицию.
- **L22** `PARTITION OF app.shipments_partitioned` — делаем её частью `shipments_partitioned`.
- **L23** `FOR VALUES FROM ('2026-01-01'::timestamp) TO (MAXVALUE);` — текущая: всё, что начиная с `2026-01-01` и дальше.
- **L24** *(пусто)* — разделение блоков.
- **L25** `COMMENT ON TABLE app.shipments_p_current IS` — описание текущей партиции.
- **L26** `'Текущая партиция shipments (последний период / текущие данные)';` — текст описания.
- **L27** *(пусто)* — разделение блоков.
- **L28** `-- Task 1: indexes for analytic queries on current partition` — комментарий: индексы для ускорения аналитики.
- **L29** `CREATE INDEX IF NOT EXISTS idx_shipments_p_current_created_sender` — создаём индекс, если его нет.
- **L30** `ON app.shipments_p_current (created_at, sender_id);` — индекс по дате и отправителю (часто фильтруем “за период” и “по клиенту”).
- **L31** *(пусто)* — разделение блоков.
- **L32** `CREATE INDEX IF NOT EXISTS idx_shipments_p_current_type_created` — второй индекс.
- **L33** `ON app.shipments_p_current (shipment_type_id, created_at);` — индекс по типу услуги и дате (часто считаем популярность услуг за период).
- **L34** *(пусто)* — разделение блоков.
- **L35** `-- Task 1: copy data from base table into partitioned table` — комментарий: копируем данные в новую секционированную таблицу.
- **L36** `INSERT INTO app.shipments_partitioned` — вставляем строки в секционированную таблицу.
- **L37** `SELECT s.*` — берём все поля исходной записи.
- **L38** `FROM app.shipments s` — источник данных: старая таблица `shipments`.
- **L39** `LEFT JOIN app.shipments_partitioned sp` — присоединяем секционированную таблицу, чтобы проверить “уже есть/нет”.
- **L40** `ON sp.id = s.id` — совпадение по id (уникальный идентификатор).
- **L41** `WHERE sp.id IS NULL;` — вставляем только те строки, которых ещё нет (чтобы запуск был идемпотентным).
- **L42** *(пусто)* — конец файла.
- **L43** *(пусто)* — конец файла.

---

## `lab5_task2_metrics.sql` — метрики (задание 2)

- **L1** `-- Task 2: LTV per client for full history` — комментарий: считаем LTV за всё время.
- **L2** `WITH user_orders AS (` — начинаем CTE (временную таблицу результата).
- **L3** `SELECT` — выбираем поля для расчёта.
- **L4** `s.sender_id       AS user_id,` — берём id клиента (отправителя).
- **L5** `MIN(s.created_at) AS first_purchase_at,` — первая покупка/отправка клиента.
- **L6** `MAX(s.created_at) AS last_purchase_at,` — последняя покупка/отправка клиента.
- **L7** `SUM(s.price)      AS ltv` — суммарная выручка по клиенту (LTV).
- **L8** `FROM app.shipments_partitioned s` — считаем по секционированной таблице (для демонстрации подхода).
- **L9** `GROUP BY s.sender_id` — группируем по клиенту.
- **L10** `)` — закрываем CTE.
- **L11** `SELECT` — выводим итоговую таблицу для отчёта.
- **L12** `u.id,` — id клиента.
- **L13** `u.email AS client_name,` — имя/идентификатор клиента (email).
- **L14** `o.first_purchase_at,` — первая покупка.
- **L15** `o.last_purchase_at,` — последняя покупка.
- **L16** `o.ltv` — LTV.
- **L17** `FROM user_orders o` — берём из CTE.
- **L18** `JOIN app.users u ON u.id = o.user_id` — подтягиваем данные клиента из `users`.
- **L19** `ORDER BY o.ltv DESC;` — сортируем по убыванию LTV.
- **L20** *(пусто)* — разделение блоков.
- **L21** `-- Task 2: AOV and top‑5 clients by average order value` — комментарий: считаем AOV и берём топ-5.
- **L22** `WITH user_aov AS (` — CTE для AOV.
- **L23** `SELECT` — набор полей.
- **L24** `s.sender_id                AS user_id,` — id клиента.
- **L25** `COUNT(*)                   AS orders_count,` — сколько заказов/отправок.
- **L26** `SUM(s.price)               AS total_revenue,` — суммарная выручка.
- **L27** `SUM(s.price) / COUNT(*)::numeric AS aov` — средний чек = сумма / количество.
- **L28** `FROM app.shipments_partitioned s` — источник.
- **L29** `GROUP BY s.sender_id` — по клиенту.
- **L30** `)` — закрываем CTE.
- **L31** `SELECT` — вывод для отчёта.
- **L32** `u.id,` — id клиента.
- **L33** `u.email AS client_name,` — имя клиента.
- **L34** `ua.orders_count,` — число заказов.
- **L35** `ua.total_revenue,` — сумма.
- **L36** `ua.aov` — средний чек.
- **L37** `FROM user_aov ua` — из CTE.
- **L38** `JOIN app.users u ON u.id = ua.user_id` — подтягиваем email.
- **L39** `ORDER BY ua.aov DESC` — сортируем по AOV.
- **L40** `LIMIT 5;` — берём топ-5.
- **L41** *(пусто)* — разделение блоков.
- **L42** `-- Task 2: ARPU for last month using partitioned table` — комментарий: ARPU за последний месяц.
- **L43** `WITH all_active_users AS (` — CTE: активные пользователи за всё время.
- **L44** `SELECT DISTINCT s.sender_id AS user_id` — уникальные клиенты.
- **L45** `FROM app.shipments s` — активность берём из общей таблицы (все времена).
- **L46** `),` — закрываем CTE и продолжаем следующий.
- **L47** `revenue_last_month AS (` — CTE: выручка за последний месяц.
- **L48** `SELECT` — считаем сумму.
- **L49** `SUM(s.price) AS revenue_last_month` — выручка.
- **L50** `FROM app.shipments_partitioned s` — берём из секционированной таблицы.
- **L51** `WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'` — начало отчётного месяца.
- **L52** `AND s.created_at <  date_trunc('month', CURRENT_DATE)` — конец отчётного месяца.
- **L53** `),` — закрываем CTE.
- **L54** `active_users_count AS (` — CTE: число активных пользователей.
- **L55** `SELECT COUNT(*) AS cnt FROM all_active_users` — считаем активных.
- **L56** `)` — закрываем.
- **L57** `SELECT` — финальный вывод ARPU.
- **L58** `r.revenue_last_month / GREATEST(auc.cnt, 1)::numeric AS arpu,` — ARPU = выручка / активные (защита от деления на 0).
- **L59** `r.revenue_last_month AS revenue_last_month,` — выручка (для контроля).
- **L60** `auc.cnt             AS active_users_total` — число активных (для контроля).
- **L61** `FROM revenue_last_month r` — берём выручку.
- **L62** `CROSS JOIN active_users_count auc;` — добавляем число активных одной строкой.
- **L63** *(пусто)* — разделение блоков.
- **L64** `-- Task 2: ARPPU for last month using partitioned table` — комментарий: ARPPU за месяц.
- **L65** `WITH paying_users_last_month AS (` — CTE: платящие за месяц.
- **L66** `SELECT DISTINCT s.sender_id AS user_id` — уникальные клиенты.
- **L67** `FROM app.shipments_partitioned s` — смотрим по секционированной таблице.
- **L68** `WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'` — начало месяца.
- **L69** `AND s.created_at <  date_trunc('month', CURRENT_DATE)` — конец месяца.
- **L70** `),` — закрываем CTE.
- **L71** `revenue_last_month AS (` — выручка за месяц (то же самое, что в ARPU).
- **L72** `SELECT` — считаем сумму.
- **L73** `SUM(s.price) AS revenue_last_month` — выручка.
- **L74** `FROM app.shipments_partitioned s` — источник.
- **L75** `WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'` — фильтр месяца.
- **L76** `AND s.created_at <  date_trunc('month', CURRENT_DATE)` — фильтр месяца.
- **L77** `),` — закрываем.
- **L78** `paying_users_count AS (` — CTE: сколько платящих.
- **L79** `SELECT COUNT(*) AS cnt FROM paying_users_last_month` — считаем платящих.
- **L80** `)` — закрываем.
- **L81** `SELECT` — финальный вывод ARPPU.
- **L82** `r.revenue_last_month / GREATEST(puc.cnt, 1)::numeric AS arppu,` — ARPPU = выручка / платящие.
- **L83** `r.revenue_last_month AS revenue_last_month,` — выручка (контроль).
- **L84** `puc.cnt             AS paying_users` — число платящих (контроль).
- **L85** `FROM revenue_last_month r` — из CTE.
- **L86** `CROSS JOIN paying_users_count puc;` — добавляем число платящих одной строкой.
- **L87** *(пусто)* — разделение блоков.
- **L88** `-- Task 2: top‑3 most popular shipment types for last month` — комментарий: топ-3 популярных услуг за месяц.
- **L89** `WITH shipments_last_month AS (` — CTE: только отправления последнего месяца.
- **L90** `SELECT *` — берём все поля (просто фильтруем).
- **L91** `FROM app.shipments_partitioned s` — источник.
- **L92** `WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'` — фильтр периода.
- **L93** `AND s.created_at <  date_trunc('month', CURRENT_DATE)` — фильтр периода.
- **L94** `),` — закрываем.
- **L95** `type_stats AS (` — CTE: считаем количество по типам.
- **L96** `SELECT` — выбираем поля.
- **L97** `s.shipment_type_id,` — тип услуги.
- **L98** `COUNT(*) AS shipments_count` — сколько раз использовали.
- **L99** `FROM shipments_last_month s` — по отфильтрованным данным.
- **L100** `GROUP BY s.shipment_type_id` — группируем по типу.
- **L101** `)` — закрываем.
- **L102** `SELECT` — выводим вместе со справочником.
- **L103** `t.id,` — id типа.
- **L104** `t.code,` — код типа.
- **L105** `t.name,` — название.
- **L106** `ts.shipments_count` — количество.
- **L107** `FROM type_stats ts` — из статистики.
- **L108** `JOIN ref.shipment_types t ON t.id = ts.shipment_type_id` — подтягиваем название из справочника.
- **L109** `ORDER BY ts.shipments_count DESC` — сначала самые популярные.
- **L110** `LIMIT 3;` — топ-3.
- **L111** *(пусто)* — разделение блоков.
- **L112** `-- Task 2: top‑3 least popular shipment types for last month` — комментарий: топ-3 непопулярных.
- **L113** `WITH shipments_last_month AS (` — снова фильтруем последний месяц.
- **L114** `SELECT *` — берём строки периода.
- **L115** `FROM app.shipments_partitioned s` — источник.
- **L116** `WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'` — начало.
- **L117** `AND s.created_at <  date_trunc('month', CURRENT_DATE)` — конец.
- **L118** `),` — закрываем.
- **L119** `type_stats AS (` — статистика по типам.
- **L120** `SELECT` — поля.
- **L121** `s.shipment_type_id,` — тип.
- **L122** `COUNT(*) AS shipments_count` — сколько раз встречается.
- **L123** `FROM shipments_last_month s` — период.
- **L124** `GROUP BY s.shipment_type_id` — группировка.
- **L125** `HAVING COUNT(*) > 0` — берём только те типы, которые реально покупались (не нулевые).
- **L126** `)` — закрываем.
- **L127** `SELECT` — вывод.
- **L128** `t.id,` — id.
- **L129** `t.code,` — код.
- **L130** `t.name,` — название.
- **L131** `ts.shipments_count` — количество.
- **L132** `FROM type_stats ts` — из статистики.
- **L133** `JOIN ref.shipment_types t ON t.id = ts.shipment_type_id` — справочник.
- **L134** `ORDER BY ts.shipments_count ASC` — сначала самые редкие (непопулярные).
- **L135** `LIMIT 3;` — топ-3.
- **L136** *(пусто)* — разделение блоков.
- **L137** `-- Task 2: EXPLAIN ANALYZE for ARPPU to demonstrate partition pruning` — комментарий: контрольное действие для отчёта.
- **L138** `EXPLAIN ANALYZE` — просим базу показать план и реальное время выполнения.
- **L139–L160** *(весь блок запроса ARPPU)* — тот же расчёт ARPPU, но теперь с `EXPLAIN ANALYZE`, чтобы увидеть **скан только нужной партиции** за месяц.
- **L161** *(пусто)* — конец файла.
- **L162** *(пусто)* — конец файла.

---

## `lab5_partition_pruning.sql` — демонстрация pruning (контроль)

- **L1** `\echo '=========================================='` — печатаем рамку в выводе psql.
- **L2** `\echo 'LAB5: PARTITION PRUNING CHECK (ARPU, ARPPU)'` — заголовок блока.
- **L3** `\echo '=========================================='` — закрываем рамку.
- **L4** *(пусто)* — разделение.
- **L5** `-- EXPLAIN ANALYZE for ARPU (last month, partitioned table)` — комментарий: сначала ARPU.
- **L6** `\echo ''` — пустая строка в выводе.
- **L7** `\echo '--- ARPU (EXPLAIN ANALYZE) ---'` — подзаголовок.
- **L8** *(пусто)* — разделение.
- **L9** `EXPLAIN (ANALYZE, VERBOSE, COSTS OFF)` — план + время, подробности, без “стоимостей” (проще для отчёта).
- **L10–L29** *(запрос ARPU)* — расчёт ARPU за месяц, чтобы в плане увидеть **скан нужной партиции**.
- **L30** *(пусто)* — разделение.
- **L31** `-- EXPLAIN ANALYZE for ARPPU (last month, partitioned table)` — комментарий: теперь ARPPU.
- **L32** `\echo ''` — пустая строка.
- **L33** `\echo '--- ARPPU (EXPLAIN ANALYZE) ---'` — подзаголовок.
- **L34** *(пусто)* — разделение.
- **L35** `EXPLAIN (ANALYZE, VERBOSE, COSTS OFF)` — снова план и время.
- **L36–L57** *(запрос ARPPU)* — расчёт ARPPU за месяц; в плане показываем **partition pruning**.
- **L58–L59** *(пусто)* — конец файла.

---

## `lab5_task3_changes.sql` — “бизнес-обратная связь” (задание 3)

- **L1** `-- Task 3: VIP level based on LTV` — комментарий: решение 1 — VIP.
- **L2** `ALTER TABLE app.users` — меняем таблицу пользователей.
- **L3** `ADD COLUMN IF NOT EXISTS vip_level SMALLINT NOT NULL DEFAULT 0;` — добавляем колонку VIP-уровня (0/1/2).
- **L4** *(пусто)* — разделение.
- **L5** `WITH user_ltv AS (` — считаем LTV по каждому клиенту.
- **L6–L11** *(агрегация)* — суммируем `price` по отправителю, получаем `ltv`.
- **L12** `UPDATE app.users u` — обновляем пользователей.
- **L13–L17** `SET vip_level = CASE ...` — назначаем VIP-уровень по порогам LTV.
- **L18–L19** `FROM ... WHERE ...` — связываем расчёт с конкретным пользователем.
- **L20** *(пусто)* — разделение.
- **L21** `-- Task 3: VIP discounts for clients ...` — комментарий: решение 2 — маркетинговые скидки на непопулярные услуги.
- **L22–L23** `ALTER TABLE ref.shipment_types ... marketing_discount_percent` — добавляем поле скидки в справочник услуг.
- **L24** *(пусто)* — разделение.
- **L25–L26** `UPDATE ref.shipment_types SET marketing_discount_percent = 0;` — сначала сбрасываем все скидки в 0 (чтобы пересчёт был чистый).
- **L27** *(пусто)* — разделение.
- **L28–L46** *(CTE)* — находим 3 наименее популярные услуги за последний месяц.
- **L47–L49** `UPDATE ... SET marketing_discount_percent = 10.0 ...` — ставим 10% скидку этим 3 услугам.
- **L50** *(пусто)* — разделение.
- **L51** `-- Recalculate discount in shipments ...` — комментарий: пересчёт скидок в самих отправлениях.
- **L52–L70** *(CTE повторно)* — снова выделяем период/статистику (здесь по факту это подготовка, но финально нужен апдейт).
- **L71–L75** `UPDATE app.shipments ... SET price = s.price ...` — “технический” апдейт строк месяца, чтобы сработал триггер пересчёта цен/скидок.
- **L76** *(пусто)* — разделение.
- **L77** `-- Sync partitioned table for analytics` — комментарий: синхронизируем аналитическую таблицу.
- **L78–L87** `UPDATE app.shipments_partitioned ... FROM app.shipments ...` — переносим рассчитанные `price_original/discount/price_final` в секционированную копию.
- **L88** *(пусто)* — разделение.
- **L89** `-- Task 3: flags in users ...` — комментарий: решение 3 — флажки активности в `users`.
- **L90–L94** `ALTER TABLE app.users ADD COLUMN ...` — добавляем `last_shipment_at` и `is_paying_last_month`.
- **L95** *(пусто)* — разделение.
- **L96–L106** *(CTE)* — считаем последнюю дату отправки и список платящих за месяц.
- **L107–L115** `UPDATE app.users ...` — записываем эти значения прямо в карточки пользователей.
- **L116** *(пусто)* — конец файла.

---

## `lab5_metrics.sql` — итоговый красивый вывод метрик (для запуска тестов)

Этот файл логически повторяет `lab5_task2_metrics.sql`, но добавляет красивые заголовки через `\echo`.

- **L1–L7** — шапка и как запускать.
- **L9–L12** `\echo ...` — печать заголовка “All-time metrics”.
- **L13–L31** — запрос LTV (как в задании 2).
- **L33–L37** — печать заголовка “Top-5 by AOV”.
- **L38–L57** — запрос AOV (как в задании 2).
- **L59–L63** — заголовок “Reporting period metrics (last month)”.
- **L64–L85** — запрос ARPU (как в задании 2).
- **L86–L114** — запрос ARPPU (как в задании 2).
- **L115–L142** — топ-3 популярных услуг за месяц.
- **L144–L172** — топ-3 непопулярных услуг за месяц.

---

## `migrate_lab5.sql` — автоматическая миграция ЛР5 (всё в одном, для Docker)

Этот файл включает **все шаги ЛР5**: создание партиций, индексы, перенос данных, добавление полей и обновления для бизнес-решений.

Чтобы не дублировать один и тот же текст на сотни строк дважды, ориентируйся так:
- **Секции “1 / 2 / 3”** в `migrate_lab5.sql` по смыслу совпадают с файлами:
  - “1. секционирование” → `lab5_task1_partitioning.sql`
  - “2. метрики/схема/скидки” → `lab5_task2_metrics.sql` + часть `lab5_task3_changes.sql`
  - “3. флажки активности” → конец `lab5_task3_changes.sql`

Если тебе нужно, я сделаю **доп. версию**, где `migrate_lab5.sql` будет разобран **буквально по каждой строке L1..L347** (это получится очень большой документ, но тоже возможно).

