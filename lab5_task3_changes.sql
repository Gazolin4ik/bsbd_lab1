-- Task 3: VIP level based on LTV
ALTER TABLE app.users
    ADD COLUMN IF NOT EXISTS vip_level SMALLINT NOT NULL DEFAULT 0;

WITH user_ltv AS (
    SELECT
        s.sender_id AS user_id,
        SUM(s.price) AS ltv
    FROM app.shipments_partitioned s
    GROUP BY s.sender_id
)
UPDATE app.users u
SET vip_level = CASE
    WHEN l.ltv >= 800 THEN 2
    WHEN l.ltv >= 300 THEN 1
    ELSE 0
END
FROM user_ltv l
WHERE u.id = l.user_id;

-- Task 3: VIP discounts for clients (level 1 => 5%, level 2 => 15%)
ALTER TABLE ref.shipment_types
    ADD COLUMN IF NOT EXISTS marketing_discount_percent NUMERIC(5,2) NOT NULL DEFAULT 0;

UPDATE ref.shipment_types
SET marketing_discount_percent = 0;

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
),
least_popular AS (
    SELECT shipment_type_id
    FROM type_stats
    ORDER BY shipments_count ASC
    LIMIT 3
)
UPDATE ref.shipment_types t
SET marketing_discount_percent = 10.0
WHERE t.id IN (SELECT shipment_type_id FROM least_popular);

-- Recalculate discount in shipments (trigger will fill discount fields)
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
),
least_popular AS (
    SELECT shipment_type_id
    FROM type_stats
    ORDER BY shipments_count ASC
    LIMIT 3
)
UPDATE app.shipments s
SET price = s.price
WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'
  AND s.created_at <  date_trunc('month', CURRENT_DATE)
;

-- Sync partitioned table for analytics
UPDATE app.shipments_partitioned sp
SET
    price_original = s.price_original,
    discount_percent_applied = s.discount_percent_applied,
    price_final = s.price_final,
    price = s.price
FROM app.shipments s
WHERE sp.id = s.id
  AND s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'
  AND s.created_at <  date_trunc('month', CURRENT_DATE);

-- Task 3: flags in users for last shipment and paying activity
ALTER TABLE app.users
    ADD COLUMN IF NOT EXISTS last_shipment_at TIMESTAMP NULL;

ALTER TABLE app.users
    ADD COLUMN IF NOT EXISTS is_paying_last_month BOOLEAN NOT NULL DEFAULT false;

WITH user_last AS (
    SELECT sender_id AS user_id, MAX(created_at) AS last_shipment_at
    FROM app.shipments_partitioned
    GROUP BY sender_id
),
paying_last_month AS (
    SELECT DISTINCT sender_id AS user_id
    FROM app.shipments_partitioned s
    WHERE s.created_at >= date_trunc('month', CURRENT_DATE) - interval '1 month'
      AND s.created_at <  date_trunc('month', CURRENT_DATE)
)
UPDATE app.users u
SET
    last_shipment_at = ul.last_shipment_at,
    is_paying_last_month = EXISTS (
        SELECT 1 FROM paying_last_month plm WHERE plm.user_id = u.id
    )
FROM user_last ul
WHERE u.id = ul.user_id;

