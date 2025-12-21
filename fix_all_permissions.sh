#!/bin/bash
# Скрипт для выдачи всех прав для ЛР3

docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 <<'EOF'
-- Выдаем права на схемы
GRANT USAGE ON SCHEMA ref TO PUBLIC;
GRANT USAGE ON SCHEMA app TO PUBLIC;
GRANT USAGE ON SCHEMA ref TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login, postgres;
GRANT USAGE ON SCHEMA app TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login, postgres;

-- Выдаем права на таблицы
GRANT SELECT ON ref.segments TO PUBLIC;
GRANT SELECT ON app.user_mappings TO PUBLIC;
GRANT SELECT ON ref.segments TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login, postgres;
GRANT SELECT ON app.user_mappings TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login, postgres;

-- Выдаем права на таблицы с RLS
GRANT SELECT, INSERT, UPDATE, DELETE ON app.offices TO anna_ivanova, petr_smirnov, maria_petrova, postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.employees TO anna_ivanova, petr_smirnov, maria_petrova, postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.users TO anna_ivanova, petr_smirnov, maria_petrova, postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.shipments TO anna_ivanova, petr_smirnov, maria_petrova, postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.delivery_routes TO anna_ivanova, petr_smirnov, maria_petrova, postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.shipment_operations TO anna_ivanova, petr_smirnov, maria_petrova, postgres;

-- Выдаем права на функции
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login, postgres;

-- Проверяем права
SELECT 
    'anna_ivanova' as user_name,
    has_schema_privilege('anna_ivanova', 'ref', 'USAGE') as ref_usage,
    has_schema_privilege('anna_ivanova', 'app', 'USAGE') as app_usage,
    has_table_privilege('anna_ivanova', 'ref.segments', 'SELECT') as segments_select,
    has_table_privilege('anna_ivanova', 'app.shipments', 'SELECT') as shipments_select
UNION ALL
SELECT 
    'postgres',
    has_schema_privilege('postgres', 'ref', 'USAGE'),
    has_schema_privilege('postgres', 'app', 'USAGE'),
    has_table_privilege('postgres', 'ref.segments', 'SELECT'),
    has_table_privilege('postgres', 'app.shipments', 'SELECT');
EOF

