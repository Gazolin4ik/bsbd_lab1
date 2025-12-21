-- Скрипт для исправления прав доступа для ЛР3
-- Выполнить: docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /fix_permissions_lab3.sql

-- Выдаем права на схемы
GRANT USAGE ON SCHEMA ref TO PUBLIC;
GRANT USAGE ON SCHEMA app TO PUBLIC;
GRANT USAGE ON SCHEMA ref TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
GRANT USAGE ON SCHEMA app TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;

-- Выдаем права на таблицы
GRANT SELECT ON ref.segments TO PUBLIC;
GRANT SELECT ON app.user_mappings TO PUBLIC;
GRANT SELECT ON ref.segments TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
GRANT SELECT ON app.user_mappings TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;

-- Выдаем права на функции
GRANT EXECUTE ON FUNCTION app.get_session_segment_id() TO PUBLIC;
GRANT EXECUTE ON FUNCTION app.get_user_segment_id() TO PUBLIC;
GRANT EXECUTE ON FUNCTION app.set_session_ctx(INTEGER, INTEGER) TO PUBLIC;
GRANT EXECUTE ON FUNCTION app.get_session_segment_id() TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
GRANT EXECUTE ON FUNCTION app.get_user_segment_id() TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
GRANT EXECUTE ON FUNCTION app.set_session_ctx(INTEGER, INTEGER) TO anna_ivanova, petr_smirnov, maria_petrova;

-- Выдаем права на таблицы с RLS
GRANT SELECT, INSERT, UPDATE, DELETE ON app.offices TO anna_ivanova, petr_smirnov, maria_petrova;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.employees TO anna_ivanova, petr_smirnov, maria_petrova;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.users TO anna_ivanova, petr_smirnov, maria_petrova;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.shipments TO anna_ivanova, petr_smirnov, maria_petrova;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.delivery_routes TO anna_ivanova, petr_smirnov, maria_petrova;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.shipment_operations TO anna_ivanova, petr_smirnov, maria_petrova;

-- Проверяем права
SELECT has_schema_privilege('anna_ivanova', 'ref', 'USAGE') as has_ref;
SELECT has_schema_privilege('anna_ivanova', 'app', 'USAGE') as has_app;
SELECT has_table_privilege('anna_ivanova', 'ref.segments', 'SELECT') as has_select_segments;
SELECT has_table_privilege('anna_ivanova', 'app.user_mappings', 'SELECT') as has_select_user_mappings;

