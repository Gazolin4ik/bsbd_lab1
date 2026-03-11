-- Task 1: create partitioned copy of shipments
CREATE TABLE IF NOT EXISTS app.shipments_partitioned (
    LIKE app.shipments
        INCLUDING DEFAULTS
        EXCLUDING CONSTRAINTS
        EXCLUDING INDEXES
)
PARTITION BY RANGE (created_at);

COMMENT ON TABLE app.shipments_partitioned IS
'Секционированная версия shipments по дате created_at для аналитики';

-- Task 1: create archive and current partitions
CREATE TABLE IF NOT EXISTS app.shipments_p_archive
    PARTITION OF app.shipments_partitioned
    FOR VALUES FROM (MINVALUE) TO ('2026-01-01'::timestamp);

COMMENT ON TABLE app.shipments_p_archive IS
'Архивная партиция shipments (старые периоды)';

CREATE TABLE IF NOT EXISTS app.shipments_p_current
    PARTITION OF app.shipments_partitioned
    FOR VALUES FROM ('2026-01-01'::timestamp) TO (MAXVALUE);

COMMENT ON TABLE app.shipments_p_current IS
'Текущая партиция shipments (последний период / текущие данные)';

-- Task 1: indexes for analytic queries on current partition
CREATE INDEX IF NOT EXISTS idx_shipments_p_current_created_sender
    ON app.shipments_p_current (created_at, sender_id);

CREATE INDEX IF NOT EXISTS idx_shipments_p_current_type_created
    ON app.shipments_p_current (shipment_type_id, created_at);

-- Task 1: copy data from base table into partitioned table
INSERT INTO app.shipments_partitioned
SELECT s.*
FROM app.shipments s
LEFT JOIN app.shipments_partitioned sp
       ON sp.id = s.id
WHERE sp.id IS NULL;

