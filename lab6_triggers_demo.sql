\echo '=========================================='
\echo 'LAB2 TRIGGER #1: UNIQUE TRACKING NUMBER (BEFORE INSERT)'
\echo '=========================================='

DO $$
BEGIN
    BEGIN
        INSERT INTO app.lab2_shipments_demo (
            tracking_number, from_office_id, to_office_id,
            sender_id, recipient_id, shipment_type_id,
            status, weight, declared_value,
            price_original, price_final,
            created_at, updated_at
        )
        VALUES (
            'LAB2-DEMO-TRK-UNIQ', 1, 2,
            1, 2, (SELECT id FROM ref.shipment_types WHERE code = 'ECONOMY'),
            'NEW', 0.5, NULL,
            (SELECT base_price FROM ref.shipment_types WHERE code = 'ECONOMY'),
            (SELECT base_price FROM ref.shipment_types WHERE code = 'ECONOMY'),
            NULL, NULL
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected error: %', SQLERRM;
    END;
END;
$$;

\echo ''
\echo '=========================================='
\echo 'LAB2 TRIGGER #2: PROPAGATE SERVICE BASE_PRICE TO NEW SHIPMENTS'
\echo '=========================================='

\echo 'Before update (demo shipments NEW + ECONOMY):'
SELECT
    s.id,
    s.tracking_number,
    t.code,
    s.status,
    s.price_original,
    s.price_final,
    s.updated_at
FROM app.lab2_shipments_demo s
JOIN ref.shipment_types t ON t.id = s.shipment_type_id
WHERE t.code = 'ECONOMY'
ORDER BY s.id;

-- Update base_price; trigger updates price_original/price_final for NEW demo shipments
UPDATE ref.shipment_types
SET base_price = base_price + 15
WHERE code = 'ECONOMY';

\echo 'After update (demo shipments NEW + ECONOMY):'
SELECT
    s.id,
    s.tracking_number,
    t.code,
    s.status,
    s.price_original,
    s.price_final,
    s.updated_at
FROM app.lab2_shipments_demo s
JOIN ref.shipment_types t ON t.id = s.shipment_type_id
WHERE t.code = 'ECONOMY'
ORDER BY s.id;

-- Restore base_price change to keep dataset stable between runs
UPDATE ref.shipment_types
SET base_price = base_price - 15
WHERE code = 'ECONOMY';

\echo ''
\echo '=========================================='
\echo 'LAB2 TRIGGER #3: SUSPICIOUS DELETE BLOCKING'
\echo '=========================================='

-- Seed 6 NEW demo shipments for deletion test
DELETE FROM app.lab2_shipments_demo
WHERE tracking_number LIKE 'LAB2-DEMO-TRK-DEL-%';

INSERT INTO app.lab2_shipments_demo (
    tracking_number, from_office_id, to_office_id,
    sender_id, recipient_id, shipment_type_id,
    status, weight, declared_value,
    price_original, price_final,
    created_at, updated_at
)
SELECT
    'LAB2-DEMO-TRK-DEL-' || gs::text,
    1, 2,
    1, 2,
    st.id,
    'NEW',
    0.5,
    NULL,
    st.base_price,
    st.base_price,
    NULL, NULL
FROM generate_series(1, 6) gs
CROSS JOIN LATERAL (SELECT id, base_price FROM ref.shipment_types WHERE code = 'ECONOMY' LIMIT 1) st;

DO $$
BEGIN
    BEGIN
        DELETE FROM app.lab2_shipments_demo
        WHERE id IN (
            SELECT id
            FROM app.lab2_shipments_demo
            ORDER BY id DESC
            LIMIT 6
        );
        RAISE NOTICE 'Delete unexpectedly succeeded';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected blocking error: %', SQLERRM;
    END;
END;
$$;

\echo ''
\echo 'Remaining NEW demo shipments for ECONOMY:'
SELECT COUNT(*)
FROM app.lab2_shipments_demo s
JOIN ref.shipment_types t ON t.id = s.shipment_type_id
WHERE t.code = 'ECONOMY'
  AND s.status = 'NEW';

\echo ''
\echo '=========================================='
\echo 'LAB2 TRIGGER #4: AUTO TIMESTAMP FILL ON INSERT'
\echo '=========================================='

DELETE FROM app.lab2_shipments_demo
WHERE tracking_number = 'LAB2-DEMO-TRK-TS';

INSERT INTO app.lab2_shipments_demo (
    tracking_number, from_office_id, to_office_id,
    sender_id, recipient_id, shipment_type_id,
    status, weight, declared_value,
    price_original, price_final,
    created_at, updated_at
)
SELECT
    'LAB2-DEMO-TRK-TS',
    1, 2,
    1, 2,
    st.id,
    'NEW',
    0.5,
    NULL,
    st.base_price,
    st.base_price,
    NULL, NULL
FROM ref.shipment_types st
WHERE st.code = 'ECONOMY'
LIMIT 1;

SELECT id, tracking_number, created_at, updated_at
FROM app.lab2_shipments_demo
WHERE tracking_number = 'LAB2-DEMO-TRK-TS';

\echo ''
\echo '=========================================='
\echo 'LAB2 TRIGGER #5: PASSWORD CHANGE PROTECTION'
\echo '=========================================='

DO $$
BEGIN
    BEGIN
        UPDATE app.employee_credentials
        SET password_hash = 'blocked_change_hash'
        WHERE login = 'anna_ivanova';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected blocked password change: %', SQLERRM;
    END;
END;
$$;

UPDATE app.password_change_permissions
SET can_change = true,
    granted_at = CURRENT_TIMESTAMP
WHERE db_username = current_user;

UPDATE app.employee_credentials
SET password_hash = 'allowed_change_hash'
WHERE login = 'anna_ivanova';

SELECT login, password_hash, updated_at
FROM app.employee_credentials
WHERE login = 'anna_ivanova';
