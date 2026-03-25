\echo '=========================================='
\echo 'LAB2: INDEX BENCHMARK DATA PREP'
\echo '=========================================='

CREATE TABLE IF NOT EXISTS app.lab2_events (
    id BIGSERIAL PRIMARY KEY,
    event_key TEXT NOT NULL,
    event_ts TIMESTAMP NOT NULL,
    user_id INTEGER NOT NULL,
    shipment_id INTEGER,
    status TEXT NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    description TEXT NOT NULL,
    tags TEXT[] NOT NULL,
    payload JSONB NOT NULL,
    location POINT NOT NULL
);

DO $$
DECLARE
    v_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM app.lab2_events;

    -- Чтобы результаты "до/после" были воспроизводимыми после правок генерации данных,
    -- каждый запуск обновляем датасет.
    TRUNCATE TABLE app.lab2_events;

    INSERT INTO app.lab2_events (
        event_key, event_ts, user_id, shipment_id, status, amount,
        description, tags, payload, location
    )
    SELECT
        'EVT-' || gs::text,
        CURRENT_TIMESTAMP - ((200000 - gs) || ' seconds')::interval,
        1 + (random() * 9999)::int,
        CASE WHEN random() < 0.9 THEN 1 + (random() * 5000)::int ELSE NULL END,
        (ARRAY['new','processing','done','error','cancelled'])[1 + (random() * 4)::int],
        ROUND((random() * 10000)::numeric, 2),
        md5(gs::text || '-event-description'),
        ARRAY[
            (ARRAY['promo','fragile','bulk','intl','return'])[1 + (random() * 4)::int],
            (ARRAY['day','night','manual','auto'])[1 + (random() * 3)::int]
        ],
        jsonb_build_object(
            -- делаем условие payload @> '{"channel":"mobile"}' селективным
            'channel',
            CASE
                WHEN random() < 0.05 THEN 'mobile'
                WHEN random() < 0.50 THEN 'web'
                ELSE 'api'
            END,
            'priority', 1 + (random() * 2)::int,
            'risk', ROUND((random() * 100)::numeric, 2)
        ),
        point(random() * 1000, random() * 1000)
    FROM generate_series(1, 200000) gs;
END;
$$;

ANALYZE app.lab2_events;

\echo ''
\echo '=========================================='
\echo 'LAB2: BTREE INDEX (user_id, event_ts)'
\echo '=========================================='

DROP INDEX IF EXISTS app.idx_lab2_events_btree_user_ts;
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM app.lab2_events
WHERE user_id = 500
  AND event_ts >= CURRENT_TIMESTAMP - INTERVAL '30 days';

CREATE INDEX idx_lab2_events_btree_user_ts
ON app.lab2_events USING BTREE (user_id, event_ts);

ANALYZE app.lab2_events;
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM app.lab2_events
WHERE user_id = 500
  AND event_ts >= CURRENT_TIMESTAMP - INTERVAL '30 days';

\echo ''
\echo '=========================================='
\echo 'LAB2: HASH INDEX (event_key equality)'
\echo '=========================================='

DROP INDEX IF EXISTS app.idx_lab2_events_hash_event_key;
EXPLAIN ANALYZE
SELECT *
FROM app.lab2_events
WHERE event_key = 'EVT-150000';

CREATE INDEX idx_lab2_events_hash_event_key
ON app.lab2_events USING HASH (event_key);

ANALYZE app.lab2_events;
EXPLAIN ANALYZE
SELECT *
FROM app.lab2_events
WHERE event_key = 'EVT-150000';

\echo ''
\echo '=========================================='
\echo 'LAB2: BRIN INDEX (event_ts range)'
\echo '=========================================='

DROP INDEX IF EXISTS app.idx_lab2_events_brin_event_ts;
DROP INDEX IF EXISTS app.idx_lab2_events_btree_user_ts;
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM app.lab2_events
WHERE event_ts >= CURRENT_TIMESTAMP - INTERVAL '6 hours';

CREATE INDEX idx_lab2_events_brin_event_ts
ON app.lab2_events USING BRIN (event_ts) WITH (pages_per_range = 8);

ANALYZE app.lab2_events;
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM app.lab2_events
WHERE event_ts >= CURRENT_TIMESTAMP - INTERVAL '6 hours';

\echo ''
\echo '=========================================='
\echo 'LAB2: GIN INDEX (JSONB payload)'
\echo '=========================================='

DROP INDEX IF EXISTS app.idx_lab2_events_gin_payload;
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM app.lab2_events
WHERE payload @> '{"channel":"mobile"}'::jsonb;

CREATE INDEX idx_lab2_events_gin_payload
ON app.lab2_events USING GIN (payload jsonb_path_ops);

ANALYZE app.lab2_events;
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM app.lab2_events
WHERE payload @> '{"channel":"mobile"}'::jsonb;

\echo ''
\echo '=========================================='
\echo 'LAB2: GIST INDEX (POINT nearest-neighbor)'
\echo '=========================================='

DROP INDEX IF EXISTS app.idx_lab2_events_gist_location;
DROP INDEX IF EXISTS app.idx_lab2_events_spgist_location;
EXPLAIN ANALYZE
SELECT id, location
FROM app.lab2_events
ORDER BY location <-> point(500, 500)
LIMIT 10;

CREATE INDEX idx_lab2_events_gist_location
ON app.lab2_events USING GIST (location);

ANALYZE app.lab2_events;
EXPLAIN ANALYZE
SELECT id, location
FROM app.lab2_events
ORDER BY location <-> point(500, 500)
LIMIT 10;

\echo ''
\echo '=========================================='
\echo 'LAB2: SP-GIST INDEX (POINT nearest-neighbor)'
\echo '=========================================='

DROP INDEX IF EXISTS app.idx_lab2_events_spgist_location;
DROP INDEX IF EXISTS app.idx_lab2_events_gist_location;
EXPLAIN ANALYZE
SELECT id, location
FROM app.lab2_events
ORDER BY location <-> point(250, 250)
LIMIT 10;

CREATE INDEX idx_lab2_events_spgist_location
ON app.lab2_events USING SPGIST (location);

ANALYZE app.lab2_events;
EXPLAIN ANALYZE
SELECT id, location
FROM app.lab2_events
ORDER BY location <-> point(250, 250)
LIMIT 10;
