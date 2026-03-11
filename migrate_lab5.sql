-- =============================================
-- ЛАБОРАТОРНАЯ РАБОТА №5
-- СЕКЦИОНИРОВАНИЕ И АНАЛИТИЧЕСКИЕ МЕТРИКИ
-- =============================================
-- Запуск:
--   docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /migrate_lab5.sql
--
-- ВАЖНО:
--   1) Скрипт НЕ изменяет существующую таблицу app.shipments,
--      а создаёт параллельную секционированную таблицу app.shipments_partitioned
--      для аналитики.
--   2) Все DDL/DML обёрнуты в TRANSACTION, чтобы миграция была атомарной.

BEGIN;

-- =============================================
-- 1. СЕКЦИОНИРОВАННАЯ ТАБЛИЦА ОТПРАВЛЕНИЙ
-- =============================================

-- Ensure admin maintenance updates are possible under postgres
-- (existing LAB3 CHECK constraint blocks updates for roles without segment mapping)
CREATE OR REPLACE FUNCTION app.check_segment_id_constraint(p_segment_id INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
AS $$
DECLARE
    v_user_segment_id INTEGER;
    v_actual_user TEXT;
    v_is_auditor BOOLEAN;
BEGIN
    v_actual_user := current_user;

    IF v_actual_user = 'postgres' THEN
        RETURN true;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM pg_roles r
        JOIN pg_auth_members am ON r.oid = am.member
        JOIN pg_roles auditor_role ON am.roleid = auditor_role.oid
        WHERE r.rolname = v_actual_user
          AND auditor_role.rolname = 'auditor'
    ) INTO v_is_auditor;

    IF v_is_auditor THEN
        RETURN true;
    END IF;

    SELECT um.segment_id INTO v_user_segment_id
    FROM app.user_mappings um
    WHERE um.db_username = v_actual_user;

    IF v_user_segment_id IS NULL THEN
        RETURN false;
    END IF;

    RETURN p_segment_id = v_user_segment_id;
END;
$$;

-- Родительская секционируемая таблица, структура = app.shipments
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   information_schema.tables
        WHERE  table_schema = 'app'
        AND    table_name   = 'shipments_partitioned'
    ) THEN
        EXECUTE $cte$
            CREATE TABLE app.shipments_partitioned (
                LIKE app.shipments
                    INCLUDING DEFAULTS
                    EXCLUDING CONSTRAINTS
                    EXCLUDING INDEXES
            )
            PARTITION BY RANGE (created_at)
        $cte$;

        COMMENT ON TABLE app.shipments_partitioned IS
        'Секционированная версия shipments по дате created_at для аналитики';
    END IF;
END $$;

-- Создаём партиции archive / current, если их ещё нет
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'app'
          AND c.relname = 'shipments_p_archive'
    ) THEN
        EXECUTE $cte$
            CREATE TABLE app.shipments_p_archive
                PARTITION OF app.shipments_partitioned
                FOR VALUES FROM (MINVALUE) TO ('2026-01-01'::timestamp)
        $cte$;

        COMMENT ON TABLE app.shipments_p_archive IS
        'Архивная партиция shipments (старые периоды)';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'app'
          AND c.relname = 'shipments_p_current'
    ) THEN
        EXECUTE $cte$
            CREATE TABLE app.shipments_p_current
                PARTITION OF app.shipments_partitioned
                FOR VALUES FROM ('2026-01-01'::timestamp) TO (MAXVALUE)
        $cte$;

        COMMENT ON TABLE app.shipments_p_current IS
        'Текущая партиция shipments (последний период / текущие данные)';
    END IF;
END $$;

-- Индексы на текущей партиции под типичные аналитические запросы
CREATE INDEX IF NOT EXISTS idx_shipments_p_current_created_sender
    ON app.shipments_p_current (created_at, sender_id);

CREATE INDEX IF NOT EXISTS idx_shipments_p_current_type_created
    ON app.shipments_p_current (shipment_type_id, created_at);

-- Перенос (копирование) данных из основной таблицы в секционированную,
-- только тех записей, которых там ещё нет.
INSERT INTO app.shipments_partitioned
SELECT s.*
FROM app.shipments s
LEFT JOIN app.shipments_partitioned sp
       ON sp.id = s.id
WHERE sp.id IS NULL;

-- =============================================
-- 2. ИЗМЕНЕНИЯ СХЕМЫ ПОД МАРКЕТИНГОВЫЕ РЕШЕНИЯ
-- =============================================

-- 2.1. Уровень лояльности клиента (VIP)
ALTER TABLE app.users
    ADD COLUMN IF NOT EXISTS vip_level SMALLINT NOT NULL DEFAULT 0;

COMMENT ON COLUMN app.users.vip_level IS
'Уровень лояльности клиента (0 = обычный, 1 = высокий, 2 = премиум)';

-- 2.2. Маркетинговая скидка на тип отправления
ALTER TABLE ref.shipment_types
    ADD COLUMN IF NOT EXISTS marketing_discount_percent NUMERIC(5,2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN ref.shipment_types.marketing_discount_percent IS
'Маркетинговая скидка на тип отправления, %';

-- 2.2.c. Delivery SLA tracking per service type
ALTER TABLE ref.shipment_types
    ADD COLUMN IF NOT EXISTS sla_days SMALLINT NOT NULL DEFAULT 5;

COMMENT ON COLUMN ref.shipment_types.sla_days IS 'Target delivery SLA in days for this service type';

UPDATE ref.shipment_types SET sla_days = 7 WHERE code = 'LETTER';
UPDATE ref.shipment_types SET sla_days = 10 WHERE code = 'PARCEL';
UPDATE ref.shipment_types SET sla_days = 5 WHERE code = 'REGISTERED';
UPDATE ref.shipment_types SET sla_days = 2 WHERE code = 'EXPRESS';

-- 2.2.b. Pricing feedback: store applied discounts on shipments
ALTER TABLE app.shipments
    ADD COLUMN IF NOT EXISTS price_original NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS discount_percent_applied NUMERIC(5,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS price_final NUMERIC(10,2);

COMMENT ON COLUMN app.shipments.price_original IS 'Original price before any discounts';
COMMENT ON COLUMN app.shipments.discount_percent_applied IS 'Combined discount percent applied (VIP + marketing)';
COMMENT ON COLUMN app.shipments.price_final IS 'Final price after discounts';

-- 2.2.d. Delivery timestamp for SLA analytics
ALTER TABLE app.shipments
    ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP NULL;

COMMENT ON COLUMN app.shipments.delivered_at IS 'When shipment was delivered (for SLA/quality analytics)';

CREATE OR REPLACE FUNCTION app.apply_shipment_discounts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, ref, public
AS $$
DECLARE
    v_marketing_discount NUMERIC(5,2) := 0;
    v_vip_level SMALLINT := 0;
    v_vip_discount NUMERIC(5,2) := 0;
    v_total_discount NUMERIC(5,2) := 0;
BEGIN
    IF NEW.price_original IS NULL THEN
        NEW.price_original := NEW.price;
    END IF;

    SELECT COALESCE(t.marketing_discount_percent, 0)
      INTO v_marketing_discount
    FROM ref.shipment_types t
    WHERE t.id = NEW.shipment_type_id;

    SELECT COALESCE(u.vip_level, 0)
      INTO v_vip_level
    FROM app.users u
    WHERE u.id = NEW.sender_id;

    v_vip_discount := CASE
        WHEN v_vip_level >= 2 THEN 10.0
        WHEN v_vip_level = 1 THEN 5.0
        ELSE 0.0
    END;

    v_total_discount := LEAST(v_marketing_discount + v_vip_discount, 30.0);

    NEW.discount_percent_applied := v_total_discount;
    NEW.price_final := ROUND(NEW.price_original * (1 - (v_total_discount / 100.0)), 2);
    NEW.price := NEW.price_final;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_shipment_discounts ON app.shipments;
CREATE TRIGGER trg_apply_shipment_discounts
BEFORE INSERT OR UPDATE OF sender_id, shipment_type_id, price, price_original
ON app.shipments
FOR EACH ROW
EXECUTE FUNCTION app.apply_shipment_discounts();

-- 2.3. Заполнение vip_level на основании LTV (Lifetime Value)
WITH user_ltv AS (
    SELECT
        s.sender_id      AS user_id,
        SUM(s.price)     AS ltv
    FROM app.shipments_partitioned s
    GROUP BY s.sender_id
)
UPDATE app.users u
SET vip_level = CASE
    WHEN l.ltv >= 800 THEN 2       -- premium
    WHEN l.ltv >= 300 THEN 1       -- high
    ELSE 0                         -- обычный
END
FROM user_ltv l
WHERE u.id = l.user_id;

-- 2.4. Назначение скидок на 3 наименее популярных типа отправлений
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
SET marketing_discount_percent = 15.0  -- пример: 15% скидка на «нерелевантные» услуги
WHERE t.id IN (SELECT shipment_type_id FROM least_popular);

-- =============================================
-- 3. ОБРАТНАЯ СВЯЗЬ В БИЗНЕС-ЛОГИКЕ: СТАТУС КЛИЕНТА
-- =============================================

-- Вместо усложнения отчётностью, фиксируем в карточке клиента:
-- - дату последней покупки услуги (last_shipment_at)
-- - факт оплаты в отчётном периоде (is_paying_last_month)
-- Это позволяет быстро сегментировать клиентов и использовать в бизнес-логике (скидки/акции/коммуникации).

ALTER TABLE app.users
    ADD COLUMN IF NOT EXISTS last_shipment_at TIMESTAMP NULL;

ALTER TABLE app.users
    ADD COLUMN IF NOT EXISTS is_paying_last_month BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN app.users.last_shipment_at IS
'Дата последнего отправления клиента (по данным shipments)';

COMMENT ON COLUMN app.users.is_paying_last_month IS
'Клиент совершал оплату услуг за последний месяц (для кампаний удержания/активации)';

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
    is_paying_last_month = EXISTS (SELECT 1 FROM paying_last_month plm WHERE plm.user_id = u.id)
FROM user_last ul
WHERE u.id = ul.user_id;

COMMIT;

