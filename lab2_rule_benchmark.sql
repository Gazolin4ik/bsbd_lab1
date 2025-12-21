-- CHECK vs Trigger benchmark for shipment business rule
\echo '== Сравнение CHECK и триггера для контроля веса отправления =='
SET search_path = stg, public;

DROP TABLE IF EXISTS stg.check_rule CASCADE;
DROP TABLE IF EXISTS stg.trigger_rule CASCADE;
DROP FUNCTION IF EXISTS stg.enforce_weight CASCADE;

CREATE TABLE stg.check_rule (
    id SERIAL PRIMARY KEY,
    shipment_type_id INTEGER NOT NULL,
    weight NUMERIC NOT NULL,
    declared_value NUMERIC NOT NULL,
    price NUMERIC NOT NULL,
    CONSTRAINT chk_declared_vs_price CHECK (declared_value >= price)
);

CREATE TABLE stg.trigger_rule (
    id SERIAL PRIMARY KEY,
    shipment_type_id INTEGER NOT NULL,
    weight NUMERIC NOT NULL,
    declared_value NUMERIC NOT NULL,
    price NUMERIC NOT NULL
);

CREATE OR REPLACE FUNCTION stg.enforce_weight()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = stg, app, ref, public
AS $$
DECLARE
    v_max_weight NUMERIC;
BEGIN
    SELECT max_weight INTO v_max_weight
    FROM ref.shipment_types
    WHERE id = NEW.shipment_type_id;

    IF v_max_weight IS NOT NULL AND NEW.weight > v_max_weight THEN
        RAISE EXCEPTION 'Вес % превышает лимит % для типа %', NEW.weight, v_max_weight, NEW.shipment_type_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_trigger_rule_weight
BEFORE INSERT OR UPDATE OF weight, shipment_type_id
ON stg.trigger_rule
FOR EACH ROW
EXECUTE FUNCTION stg.enforce_weight();

DO $$
DECLARE
    v_start TIMESTAMP;
BEGIN
    v_start := clock_timestamp();
    INSERT INTO stg.check_rule (shipment_type_id, weight, declared_value, price)
    SELECT st.id,
           GREATEST(0.01, COALESCE(st.max_weight, 10) * (0.1 + random() * 0.9)),
           500 + random()*500,
           100 + random()*200
    FROM ref.shipment_types st, generate_series(1, 250000);
    RAISE NOTICE 'CHECK constraint insert duration: %', clock_timestamp() - v_start;

    v_start := clock_timestamp();
    INSERT INTO stg.trigger_rule (shipment_type_id, weight, declared_value, price)
    SELECT st.id,
           GREATEST(0.01, COALESCE(st.max_weight, 10) * (0.1 + random() * 0.9)),
           500 + random()*500,
           100 + random()*200
    FROM ref.shipment_types st, generate_series(1, 250000);
    RAISE NOTICE 'Trigger validation insert duration: %', clock_timestamp() - v_start;
END;
$$;

SELECT 
    (SELECT COUNT(*) FROM stg.check_rule) AS check_rows,
    (SELECT COUNT(*) FROM stg.trigger_rule) AS trigger_rows;

