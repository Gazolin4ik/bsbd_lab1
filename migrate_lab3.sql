-- Миграция для применения изменений ЛР3 к существующей базе данных
-- Выполнить: docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /migrate_lab3.sql

-- Создаем таблицу segments если её нет
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

-- Добавляем segment_id в user_mappings если его нет
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'app' AND table_name = 'user_mappings' AND column_name = 'segment_id'
    ) THEN
        ALTER TABLE app.user_mappings ADD COLUMN segment_id INTEGER REFERENCES ref.segments(id);
        COMMENT ON COLUMN app.user_mappings.segment_id IS 'Сегмент изоляции пользователя (кэш для избежания рекурсии в RLS)';
    END IF;
END $$;

-- Обновляем segment_id для user_mappings
UPDATE app.user_mappings um
SET segment_id = e.segment_id
FROM app.employees e
WHERE um.employee_id = e.id AND (um.segment_id IS NULL OR um.segment_id != e.segment_id);

-- Удаляем старые записи и вставляем заново
DELETE FROM app.user_mappings;

INSERT INTO app.user_mappings (db_username, employee_id, segment_id) 
SELECT 
    'anna_ivanova'::VARCHAR,
    1,
    COALESCE((SELECT segment_id FROM app.employees WHERE id = 1), 1)
UNION ALL
SELECT 
    'petr_smirnov'::VARCHAR,
    2,
    COALESCE((SELECT segment_id FROM app.employees WHERE id = 2), 1)
UNION ALL
SELECT 
    'maria_petrova'::VARCHAR,
    3,
    COALESCE((SELECT segment_id FROM app.employees WHERE id = 3), 1);

-- Делаем segment_id обязательным
ALTER TABLE app.user_mappings ALTER COLUMN segment_id SET NOT NULL;

-- Права
GRANT SELECT ON ref.segments TO PUBLIC;
GRANT EXECUTE ON FUNCTION app.get_session_segment_id() TO PUBLIC;
GRANT USAGE ON SCHEMA app TO office_manager, office_operator;
GRANT USAGE ON SCHEMA ref TO office_manager, office_operator;

-- Проверяем результат
SELECT um.db_username, um.segment_id, seg.code 
FROM app.user_mappings um 
LEFT JOIN ref.segments seg ON um.segment_id = seg.id;

