-- Task 2: LTV per client for full history
WITH user_orders AS (
    SELECT
        s.sender_id       AS user_id,
        MIN(s.created_at) AS first_purchase_at,
        MAX(s.created_at) AS last_purchase_at,
        SUM(s.price)      AS ltv
    FROM app.shipments_partitioned s
    GROUP BY s.sender_id
)
SELECT
    u.id,
    u.email AS client_name,
    o.first_purchase_at,
    o.last_purchase_at,
    o.ltv
FROM user_orders o
JOIN app.users u ON u.id = o.user_id
ORDER BY o.ltv DESC;

-- Task 2: AOV and top‑5 clients by average order value
WITH user_aov AS (
    SELECT
        s.sender_id                AS user_id,
        COUNT(*)                   AS orders_count,
        SUM(s.price)               AS total_revenue,
        SUM(s.price) / COUNT(*)::numeric AS aov
    FROM app.shipments_partitioned s
    GROUP BY s.sender_id
)
SELECT
    u.id,
    u.email AS client_name,
    ua.orders_count,
    ua.total_revenue,
    ua.aov
FROM user_aov ua
JOIN app.users u ON u.id = ua.user_id
ORDER BY ua.aov DESC
LIMIT 5;

-- Task 2: ARPU for last month using partitioned table
WITH all_active_users AS (
    SELECT DISTINCT s.sender_id AS user_id
    FROM app.shipments s
),
revenue_last_month AS (
    SELECT
        SUM(s.price) AS revenue_last_month
    FROM app.shipments_partitioned s
    WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'
      AND s.created_at <  date_trunc('month', CURRENT_DATE)
),
active_users_count AS (
    SELECT COUNT(*) AS cnt FROM all_active_users
)
SELECT
    r.revenue_last_month / GREATEST(auc.cnt, 1)::numeric AS arpu,
    r.revenue_last_month AS revenue_last_month,
    auc.cnt             AS active_users_total
FROM revenue_last_month r
CROSS JOIN active_users_count auc;

-- Task 2: ARPPU for last month using partitioned table
WITH paying_users_last_month AS (
    SELECT DISTINCT s.sender_id AS user_id
    FROM app.shipments_partitioned s
    WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'
      AND s.created_at <  date_trunc('month', CURRENT_DATE)
),
revenue_last_month AS (
    SELECT
        SUM(s.price) AS revenue_last_month
    FROM app.shipments_partitioned s
    WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'
      AND s.created_at <  date_trunc('month', CURRENT_DATE)
),
paying_users_count AS (
    SELECT COUNT(*) AS cnt FROM paying_users_last_month
)
SELECT
    r.revenue_last_month / GREATEST(puc.cnt, 1)::numeric AS arppu,
    r.revenue_last_month AS revenue_last_month,
    puc.cnt             AS paying_users
FROM revenue_last_month r
CROSS JOIN paying_users_count puc;

-- Task 2: top‑3 most popular shipment types for last month
WITH shipments_last_month AS (
    SELECT *
    FROM app.shipments_partitioned s
    WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'
      AND s.created_at <  date_trunc('month', CURRENT_DATE)
),
type_stats AS (
    SELECT
        s.shipment_type_id,
        COUNT(*) AS shipments_count
    FROM shipments_last_month s
    GROUP BY s.shipment_type_id
)
SELECT
    t.id,
    t.code,
    t.name,
    ts.shipments_count
FROM type_stats ts
JOIN ref.shipment_types t ON t.id = ts.shipment_type_id
ORDER BY ts.shipments_count DESC
LIMIT 3;

-- Task 2: top‑3 least popular shipment types for last month
WITH shipments_last_month AS (
    SELECT *
    FROM app.shipments_partitioned s
    WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'
      AND s.created_at <  date_trunc('month', CURRENT_DATE)
),
type_stats AS (
    SELECT
        s.shipment_type_id,
        COUNT(*) AS shipments_count
    FROM shipments_last_month s
    GROUP BY s.shipment_type_id
    HAVING COUNT(*) > 0
)
SELECT
    t.id,
    t.code,
    t.name,
    ts.shipments_count
FROM type_stats ts
JOIN ref.shipment_types t ON t.id = ts.shipment_type_id
ORDER BY ts.shipments_count ASC
LIMIT 3;

-- Task 2: EXPLAIN ANALYZE for ARPPU to demonstrate partition pruning
EXPLAIN ANALYZE
WITH paying_users_last_month AS (
    SELECT DISTINCT s.sender_id AS user_id
    FROM app.shipments_partitioned s
    WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'
      AND s.created_at <  date_trunc('month', CURRENT_DATE)
),
revenue_last_month AS (
    SELECT
        SUM(s.price) AS revenue_last_month
    FROM app.shipments_partitioned s
    WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'
      AND s.created_at <  date_trunc('month', CURRENT_DATE)
),
paying_users_count AS (
    SELECT COUNT(*) AS cnt FROM paying_users_last_month
)
SELECT
    r.revenue_last_month / GREATEST(puc.cnt, 1)::numeric AS arppu,
    r.revenue_last_month AS revenue_last_month,
    puc.cnt             AS paying_users
FROM revenue_last_month r
CROSS JOIN paying_users_count puc;

