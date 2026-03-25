BEGIN;

CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS audit;

-- Demo tables aligned to postal domain (shipments tracking + offices + services)
DROP TABLE IF EXISTS app.lab2_shipments_demo;
DROP TABLE IF EXISTS audit.lab2_delete_audit;
DROP TABLE IF EXISTS app.lab6_shipments_demo;
DROP TABLE IF EXISTS audit.lab6_delete_audit;

CREATE TABLE IF NOT EXISTS audit.lab2_delete_audit (
    id BIGSERIAL PRIMARY KEY,
    db_username TEXT NOT NULL,
    deleted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_id BIGINT
);

CREATE TABLE IF NOT EXISTS app.lab2_shipments_demo (
    id BIGSERIAL PRIMARY KEY,
    tracking_number TEXT NOT NULL,
    from_office_id INTEGER NOT NULL REFERENCES app.offices(id),
    to_office_id INTEGER NOT NULL REFERENCES app.offices(id),
    sender_id INTEGER NOT NULL REFERENCES app.users(id),
    recipient_id INTEGER NOT NULL REFERENCES app.users(id),
    shipment_type_id INTEGER NOT NULL REFERENCES ref.shipment_types(id),
    status VARCHAR(20) NOT NULL DEFAULT 'NEW',
    weight DECIMAL(10,2) NOT NULL DEFAULT 0.1,
    declared_value NUMERIC(15,2),
    price_original NUMERIC(10,2) NOT NULL,
    price_final NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL
);

-- Trigger 1: uniqueness check before insert (tracking number)
CREATE OR REPLACE FUNCTION app.trg_lab2_check_unique_tracking()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM app.lab2_shipments_demo s
        WHERE s.tracking_number = NEW.tracking_number
    ) THEN
        RAISE EXCEPTION 'Tracking number "%" already exists. Insert rejected by trigger.', NEW.tracking_number;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lab2_unique_tracking ON app.lab2_shipments_demo;
CREATE TRIGGER trg_lab2_unique_tracking
BEFORE INSERT ON app.lab2_shipments_demo
FOR EACH ROW
EXECUTE FUNCTION app.trg_lab2_check_unique_tracking();

-- Trigger 4: auto-fill timestamps on insert
CREATE OR REPLACE FUNCTION app.trg_lab2_set_timestamps_demo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.created_at IS NULL THEN
        NEW.created_at := CURRENT_TIMESTAMP;
    END IF;
    IF NEW.updated_at IS NULL THEN
        NEW.updated_at := CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lab2_shipments_set_timestamps ON app.lab2_shipments_demo;
CREATE TRIGGER trg_lab2_shipments_set_timestamps
BEFORE INSERT ON app.lab2_shipments_demo
FOR EACH ROW
EXECUTE FUNCTION app.trg_lab2_set_timestamps_demo();

-- Keep updated_at current on updates (helps in trigger #2 demo)
CREATE OR REPLACE FUNCTION app.trg_lab2_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lab2_shipments_touch_updated ON app.lab2_shipments_demo;
CREATE TRIGGER trg_lab2_shipments_touch_updated
BEFORE UPDATE ON app.lab2_shipments_demo
FOR EACH ROW
EXECUTE FUNCTION app.trg_lab2_touch_updated_at();

-- Trigger 2: propagate service base_price updates to related demo shipments
-- (key record: ref.shipment_types.base_price)
CREATE OR REPLACE FUNCTION app.trg_lab2_propagate_service_price()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.base_price IS DISTINCT FROM OLD.base_price THEN
        UPDATE app.lab2_shipments_demo s
        SET price_original = NEW.base_price,
            price_final = NEW.base_price
        WHERE s.shipment_type_id = NEW.id
          AND s.status = 'NEW';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lab2_propagate_service_price ON ref.shipment_types;
CREATE TRIGGER trg_lab2_propagate_service_price
AFTER UPDATE OF base_price ON ref.shipment_types
FOR EACH ROW
EXECUTE FUNCTION app.trg_lab2_propagate_service_price();

-- Trigger 3: block suspicious mass deletes
CREATE OR REPLACE FUNCTION app.trg_lab2_block_mass_delete_demo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_recent_deletes INTEGER;
BEGIN
    INSERT INTO audit.lab2_delete_audit (db_username, deleted_at, order_id)
    VALUES (current_user, CURRENT_TIMESTAMP, OLD.id);

    SELECT COUNT(*)
    INTO v_recent_deletes
    FROM audit.lab2_delete_audit a
    WHERE a.db_username = current_user
      AND a.deleted_at >= CURRENT_TIMESTAMP - INTERVAL '1 minute';

    IF v_recent_deletes > 5 THEN
        RAISE EXCEPTION 'Suspicious delete activity detected (% deletes in 1 minute). Operation blocked.', v_recent_deletes;
    END IF;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_lab2_block_mass_delete_demo ON app.lab2_shipments_demo;
CREATE TRIGGER trg_lab2_block_mass_delete_demo
BEFORE DELETE ON app.lab2_shipments_demo
FOR EACH ROW
EXECUTE FUNCTION app.trg_lab2_block_mass_delete_demo();

-- Trigger 5: password change protection for employees
CREATE TABLE IF NOT EXISTS app.employee_credentials (
    id SERIAL PRIMARY KEY,
    login VARCHAR(100) NOT NULL,
    password_hash TEXT NOT NULL,
    employee_id INTEGER REFERENCES app.employees(id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS app.password_change_permissions (
    db_username TEXT PRIMARY KEY,
    can_change BOOLEAN NOT NULL DEFAULT false,
    granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION app.trg_lab2_protect_password_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_allowed BOOLEAN;
BEGIN
    IF NEW.password_hash IS DISTINCT FROM OLD.password_hash THEN
        SELECT p.can_change
        INTO v_allowed
        FROM app.password_change_permissions p
        WHERE p.db_username = current_user;

        IF COALESCE(v_allowed, false) = false THEN
            RAISE EXCEPTION
                'Password change is blocked for user "%". Grant permission in app.password_change_permissions first.',
                current_user;
        END IF;

        UPDATE app.password_change_permissions
        SET can_change = false,
            granted_at = CURRENT_TIMESTAMP
        WHERE db_username = current_user;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lab2_protect_password_update ON app.employee_credentials;
CREATE TRIGGER trg_lab2_protect_password_update
BEFORE UPDATE OF password_hash ON app.employee_credentials
FOR EACH ROW
EXECUTE FUNCTION app.trg_lab2_protect_password_update();

-- Seed data for trigger demos
INSERT INTO app.lab2_shipments_demo (
    tracking_number, from_office_id, to_office_id, sender_id, recipient_id,
    shipment_type_id, status, weight, declared_value, price_original, price_final,
    created_at, updated_at
)
SELECT
    'LAB2-DEMO-TRK-UNIQ',
    1, 2,
    1, 2,
    st.id,
    'NEW',
    0.5,
    NULL,
    st.base_price,
    st.base_price,
    NULL,
    NULL
FROM ref.shipment_types st
WHERE st.code = 'ECONOMY'
;

INSERT INTO app.employee_credentials (login, password_hash, employee_id)
VALUES
    ('anna_ivanova', 'hash_v1_anna', 1),
    ('petr_smirnov', 'hash_v1_petr', 2),
    ('maria_petrova', 'hash_v1_maria', 3)
ON CONFLICT DO NOTHING;

INSERT INTO app.password_change_permissions (db_username, can_change)
VALUES
    (current_user, false)
ON CONFLICT (db_username) DO UPDATE
SET can_change = EXCLUDED.can_change,
    granted_at = CURRENT_TIMESTAMP;

COMMIT;
