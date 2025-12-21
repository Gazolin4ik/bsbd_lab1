-- Полная миграция для ЛР3: создание всех объектов и выдача прав
-- Выполнить: docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /complete_lab3_migration.sql

-- 1. Создаем таблицу segments
CREATE TABLE IF NOT EXISTS ref.segments (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE ref.segments IS 'Справочник сегментов для построчной изоляции данных (филиалы/отделения)';

-- Заполняем segments
INSERT INTO ref.segments (code, name, description) VALUES
('MOSCOW', 'Москва', 'Сегмент московских отделений'),
('SPB', 'Санкт-Петербург', 'Сегмент петербургских отделений'),
('NOVOSIBIRSK', 'Новосибирск', 'Сегмент новосибирских отделений')
ON CONFLICT (code) DO NOTHING;

-- 2. Создаем таблицу user_mappings если её нет
CREATE TABLE IF NOT EXISTS app.user_mappings (
    id SERIAL PRIMARY KEY,
    db_username VARCHAR(100) NOT NULL UNIQUE,
    employee_id INTEGER,
    segment_id INTEGER REFERENCES ref.segments(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE app.user_mappings IS 'Соответствие пользователей БД и сотрудников';

-- Заполняем user_mappings
INSERT INTO app.user_mappings (db_username, segment_id) 
VALUES 
    ('anna_ivanova', 1),
    ('petr_smirnov', 1),
    ('maria_petrova', 1)
ON CONFLICT (db_username) DO UPDATE SET segment_id = EXCLUDED.segment_id;

-- 3. Добавляем segment_id в таблицы если его нет
ALTER TABLE app.offices ADD COLUMN IF NOT EXISTS segment_id INTEGER REFERENCES ref.segments(id);
ALTER TABLE app.employees ADD COLUMN IF NOT EXISTS segment_id INTEGER REFERENCES ref.segments(id);
ALTER TABLE app.users ADD COLUMN IF NOT EXISTS segment_id INTEGER REFERENCES ref.segments(id);
ALTER TABLE app.shipments ADD COLUMN IF NOT EXISTS segment_id INTEGER REFERENCES ref.segments(id);
ALTER TABLE app.delivery_routes ADD COLUMN IF NOT EXISTS segment_id INTEGER REFERENCES ref.segments(id);
ALTER TABLE app.shipment_operations ADD COLUMN IF NOT EXISTS segment_id INTEGER REFERENCES ref.segments(id);

-- Обновляем segment_id для существующих записей
UPDATE app.offices SET segment_id = 1 WHERE segment_id IS NULL;
UPDATE app.employees e SET segment_id = o.segment_id FROM app.offices o WHERE e.office_id = o.id AND e.segment_id IS NULL;
UPDATE app.users SET segment_id = 1 WHERE segment_id IS NULL;
UPDATE app.shipments s SET segment_id = o.segment_id FROM app.offices o WHERE s.from_office_id = o.id AND s.segment_id IS NULL;
UPDATE app.delivery_routes dr SET segment_id = o.segment_id FROM app.offices o WHERE dr.office_id = o.id AND dr.segment_id IS NULL;
UPDATE app.shipment_operations so SET segment_id = e.segment_id FROM app.employees e WHERE so.employee_id = e.id AND so.segment_id IS NULL;

-- Делаем segment_id обязательным
DO $$
BEGIN
    ALTER TABLE app.offices ALTER COLUMN segment_id SET NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$
BEGIN
    ALTER TABLE app.employees ALTER COLUMN segment_id SET NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$
BEGIN
    ALTER TABLE app.users ALTER COLUMN segment_id SET NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$
BEGIN
    ALTER TABLE app.shipments ALTER COLUMN segment_id SET NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$
BEGIN
    ALTER TABLE app.delivery_routes ALTER COLUMN segment_id SET NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$
BEGIN
    ALTER TABLE app.shipment_operations ALTER COLUMN segment_id SET NOT NULL;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 4. Создаем функции
CREATE OR REPLACE FUNCTION app.get_session_segment_id()
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = app, public
AS $$
DECLARE
    v_segment_id INTEGER;
    v_guc_value TEXT;
BEGIN
    BEGIN
        v_guc_value := current_setting('app.segment_id', true);
        IF v_guc_value IS NOT NULL AND v_guc_value != '' THEN
            v_segment_id := v_guc_value::INTEGER;
            RETURN v_segment_id;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;
    
    SELECT um.segment_id INTO v_segment_id
    FROM app.user_mappings um
    WHERE um.db_username = current_user;
    
    RETURN v_segment_id;
END;
$$;

CREATE OR REPLACE FUNCTION app.get_user_segment_id()
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
    SELECT um.segment_id 
    FROM app.user_mappings um 
    WHERE um.db_username = current_user
    LIMIT 1;
$$;

-- 5. Выдаем права на схемы
GRANT USAGE ON SCHEMA ref TO PUBLIC;
GRANT USAGE ON SCHEMA app TO PUBLIC;
GRANT USAGE ON SCHEMA ref TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
GRANT USAGE ON SCHEMA app TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;

-- 6. Выдаем права на таблицы
GRANT SELECT ON ref.segments TO PUBLIC;
GRANT SELECT ON app.user_mappings TO PUBLIC;
GRANT SELECT ON ref.segments TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
GRANT SELECT ON app.user_mappings TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;

-- 7. Выдаем права на функции
GRANT EXECUTE ON FUNCTION app.get_session_segment_id() TO PUBLIC;
GRANT EXECUTE ON FUNCTION app.get_user_segment_id() TO PUBLIC;
GRANT EXECUTE ON FUNCTION app.get_session_segment_id() TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
GRANT EXECUTE ON FUNCTION app.get_user_segment_id() TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;

-- 8. Выдаем права на таблицы с RLS
GRANT SELECT, INSERT, UPDATE, DELETE ON app.offices TO anna_ivanova, petr_smirnov, maria_petrova;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.employees TO anna_ivanova, petr_smirnov, maria_petrova;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.users TO anna_ivanova, petr_smirnov, maria_petrova;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.shipments TO anna_ivanova, petr_smirnov, maria_petrova;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.delivery_routes TO anna_ivanova, petr_smirnov, maria_petrova;
GRANT SELECT, INSERT, UPDATE, DELETE ON app.shipment_operations TO anna_ivanova, petr_smirnov, maria_petrova;

-- 9. Создаем политики RLS для всех таблиц (если их еще нет)
-- offices
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'app' AND tablename = 'offices' AND policyname = 'offices_select_policy') THEN
        CREATE POLICY offices_select_policy ON app.offices
            FOR SELECT USING (
                pg_has_role(current_user, 'auditor', 'USAGE')
                OR segment_id = (SELECT um.segment_id FROM app.user_mappings um WHERE um.db_username = current_user)
            );
    END IF;
END $$;

-- Проверяем результат
SELECT 'segments' as object, COUNT(*) as count FROM ref.segments
UNION ALL
SELECT 'user_mappings', COUNT(*) FROM app.user_mappings
UNION ALL
SELECT 'functions', COUNT(*) FROM pg_proc WHERE proname IN ('get_session_segment_id', 'get_user_segment_id') AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'app');

