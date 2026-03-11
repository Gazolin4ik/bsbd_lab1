\echo '=========================================='
\echo 'LAB5: PARTITION PRUNING CHECK (ARPU, ARPPU)'
\echo '=========================================='

-- EXPLAIN ANALYZE for ARPU (last month, partitioned table)
\echo ''
\echo '--- ARPU (EXPLAIN ANALYZE) ---'

EXPLAIN (ANALYZE, VERBOSE, COSTS OFF)
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

-- EXPLAIN ANALYZE for ARPPU (last month, partitioned table)
\echo ''
\echo '--- ARPPU (EXPLAIN ANALYZE) ---'

EXPLAIN (ANALYZE, VERBOSE, COSTS OFF)
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

