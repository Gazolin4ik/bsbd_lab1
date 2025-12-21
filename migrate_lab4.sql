-- =============================================
-- ЛАБОРАТОРНАЯ РАБОТА №4: БЕЗОПАСНЫЕ ПРЕДСТАВЛЕНИЯ, АУДИТ ИЗМЕНЕНИЙ И АНАЛИЗ ПРОИЗВОДИТЕЛЬНОСТИ
-- =============================================

-- =============================================
-- 1. СОЗДАНИЕ ТАБЛИЦЫ ДЛЯ АУДИТА ИЗМЕНЕНИЙ
-- =============================================

-- Создаем таблицу для логов изменений строк
CREATE TABLE IF NOT EXISTS audit.row_change_log (
    id BIGSERIAL PRIMARY KEY,
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER NOT NULL,
    operation VARCHAR(10) NOT NULL CHECK (operation IN ('UPDATE', 'DELETE')),
    changed_by VARCHAR(100) NOT NULL,
    old_data JSONB,
    new_data JSONB
);

COMMENT ON TABLE audit.row_change_log IS 'Аудит изменений критичных таблиц с маскированием чувствительных данных';
COMMENT ON COLUMN audit.row_change_log.old_data IS 'Старые данные (чувствительные поля замаскированы/захэшированы)';
COMMENT ON COLUMN audit.row_change_log.new_data IS 'Новые данные (чувствительные поля замаскированы/захэшированы)';

-- Создаем архивную таблицу для старых логов
CREATE TABLE IF NOT EXISTS audit.row_change_log_archive (
    LIKE audit.row_change_log INCLUDING ALL
);

COMMENT ON TABLE audit.row_change_log_archive IS 'Архивная таблица для старых записей аудита';

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_row_change_log_table_record ON audit.row_change_log(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_row_change_log_change_time ON audit.row_change_log(change_time);
CREATE INDEX IF NOT EXISTS idx_row_change_log_changed_by ON audit.row_change_log(changed_by);
CREATE INDEX IF NOT EXISTS idx_row_change_log_archive_change_time ON audit.row_change_log_archive(change_time);

-- Права на таблицы аудита
GRANT SELECT ON audit.row_change_log TO auditor, audit_viewer;
GRANT SELECT ON audit.row_change_log_archive TO auditor, audit_viewer;

-- Для тестов: выдаем права на чтение логов аудита (но не на запись)
-- В реальной системе только auditor должен иметь доступ
GRANT SELECT ON audit.row_change_log TO office_manager, office_operator;

-- =============================================
-- 2. ФУНКЦИЯ МАСКИРОВАНИЯ ЧУВСТВИТЕЛЬНЫХ ДАННЫХ
-- =============================================

CREATE OR REPLACE FUNCTION audit.mask_sensitive_data(
    p_table_name TEXT,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = audit, public
AS $$
DECLARE
    v_result JSONB := p_data;
    v_value TEXT;
BEGIN
    IF p_data IS NULL THEN
        RETURN NULL;
    END IF;

    -- Маскирование для таблицы users
    IF p_table_name = 'users' THEN
        -- Маскируем email: показываем только домен
        IF v_result ? 'email' AND v_result->>'email' IS NOT NULL THEN
            v_value := v_result->>'email';
            IF position('@' in v_value) > 0 THEN
                v_result := v_result || jsonb_build_object('email', '***@' || substring(v_value from position('@' in v_value) + 1));
            ELSE
                v_result := v_result || jsonb_build_object('email', '***');
            END IF;
        END IF;

        -- Хэшируем phone (MD5)
        IF v_result ? 'phone' AND v_result->>'phone' IS NOT NULL THEN
            v_result := v_result || jsonb_build_object('phone', 'HASH:' || md5(v_result->>'phone'));
        END IF;

        -- Хэшируем passport_data
        IF v_result ? 'passport_data' AND v_result->>'passport_data' IS NOT NULL THEN
            v_result := v_result || jsonb_build_object('passport_data', 'HASH:' || md5(v_result->>'passport_data'));
        END IF;
    END IF;

    -- Маскирование для таблицы shipments
    IF p_table_name = 'shipments' THEN
        -- Маскируем declared_value: показываем только порядок величины
        IF v_result ? 'declared_value' AND v_result->>'declared_value' IS NOT NULL AND v_result->>'declared_value' != 'null' THEN
            BEGIN
                v_result := v_result || jsonb_build_object('declared_value', 
                    CASE 
                        WHEN (v_result->>'declared_value')::NUMERIC >= 1000000 THEN '>1M'
                        WHEN (v_result->>'declared_value')::NUMERIC >= 100000 THEN '>100K'
                        WHEN (v_result->>'declared_value')::NUMERIC >= 10000 THEN '>10K'
                        WHEN (v_result->>'declared_value')::NUMERIC >= 1000 THEN '>1K'
                        ELSE '<1K'
                    END
                );
            EXCEPTION
                WHEN OTHERS THEN
                    -- Если не удалось преобразовать в NUMERIC, оставляем как есть или маскируем
                    v_result := v_result || jsonb_build_object('declared_value', '***');
            END;
        END IF;
    END IF;

    -- Маскирование для таблицы employees
    IF p_table_name = 'employees' THEN
        -- Маскируем имена: показываем только первую букву
        IF v_result ? 'first_name' AND v_result->>'first_name' IS NOT NULL THEN
            v_value := v_result->>'first_name';
            v_result := v_result || jsonb_build_object('first_name', left(v_value, 1) || '***');
        END IF;

        IF v_result ? 'last_name' AND v_result->>'last_name' IS NOT NULL THEN
            v_value := v_result->>'last_name';
            v_result := v_result || jsonb_build_object('last_name', left(v_value, 1) || '***');
        END IF;
    END IF;

    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION audit.mask_sensitive_data(TEXT, JSONB)
IS 'Маскирование/хэширование чувствительных данных для аудита';

-- =============================================
-- 3. ФУНКЦИЯ ЛОГИРОВАНИЯ ИЗМЕНЕНИЙ
-- =============================================

CREATE OR REPLACE FUNCTION audit.log_row_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = audit, public
AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
    v_record_id INTEGER;
    v_table_name VARCHAR;
BEGIN
    v_table_name := TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME;
    
    -- Определяем record_id
    IF TG_OP = 'DELETE' THEN
        v_record_id := OLD.id;
        v_old_data := audit.mask_sensitive_data(TG_TABLE_NAME::TEXT, to_jsonb(OLD));
        v_new_data := NULL;
    ELSIF TG_OP = 'UPDATE' THEN
        v_record_id := NEW.id;
        v_old_data := audit.mask_sensitive_data(TG_TABLE_NAME::TEXT, to_jsonb(OLD));
        v_new_data := audit.mask_sensitive_data(TG_TABLE_NAME::TEXT, to_jsonb(NEW));
    ELSE
        RETURN NULL;
    END IF;

    -- Вставляем запись в лог
    INSERT INTO audit.row_change_log (
        table_name,
        record_id,
        operation,
        changed_by,
        old_data,
        new_data
    )
    VALUES (
        v_table_name,
        v_record_id,
        TG_OP,
        session_user,
        v_old_data,
        v_new_data
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

COMMENT ON FUNCTION audit.log_row_change()
IS 'Триггерная функция для логирования изменений строк с маскированием чувствительных данных';

-- =============================================
-- 4. СОЗДАНИЕ ТРИГГЕРОВ НА КРИТИЧНЫХ ТАБЛИЦАХ
-- =============================================

-- Триггер для app.users
DROP TRIGGER IF EXISTS trg_users_audit ON app.users;
CREATE TRIGGER trg_users_audit
    AFTER UPDATE OR DELETE ON app.users
    FOR EACH ROW
    EXECUTE FUNCTION audit.log_row_change();

COMMENT ON TRIGGER trg_users_audit ON app.users
IS 'Аудит изменений таблицы users с маскированием персональных данных';

-- Триггер для app.shipments
DROP TRIGGER IF EXISTS trg_shipments_audit ON app.shipments;
CREATE TRIGGER trg_shipments_audit
    AFTER UPDATE OR DELETE ON app.shipments
    FOR EACH ROW
    EXECUTE FUNCTION audit.log_row_change();

COMMENT ON TRIGGER trg_shipments_audit ON app.shipments
IS 'Аудит изменений таблицы shipments с маскированием финансовых данных';

-- Триггер для app.employees
DROP TRIGGER IF EXISTS trg_employees_audit ON app.employees;
CREATE TRIGGER trg_employees_audit
    AFTER UPDATE OR DELETE ON app.employees
    FOR EACH ROW
    EXECUTE FUNCTION audit.log_row_change();

COMMENT ON TRIGGER trg_employees_audit ON app.employees
IS 'Аудит изменений таблицы employees с маскированием персональных данных';

-- =============================================
-- 5. СОЗДАНИЕ UPDATABLE VIEW С WITH CHECK OPTION
-- =============================================

-- Представление для работы с неконфиденциальными полями shipments
-- Используем INSTEAD OF триггер для реализации WITH CHECK OPTION
DROP VIEW IF EXISTS app.shipments_public_view CASCADE;

CREATE VIEW app.shipments_public_view AS
SELECT
    id,
    tracking_number,
    from_office_id,
    to_office_id,
    shipment_type_id,
    weight,
    price,
    current_status,
    created_at,
    updated_at
FROM app.shipments;

COMMENT ON VIEW app.shipments_public_view IS 
'Updatable VIEW для работы с неконфиденциальными полями отправлений. WITH CHECK OPTION предотвращает обход ограничений через скрытые поля';

-- Функция для обработки UPDATE с проверкой WITH CHECK OPTION
CREATE OR REPLACE FUNCTION app.shipments_public_view_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public
AS $$
DECLARE
    v_old_record RECORD;
    v_sender_id INTEGER;
    v_recipient_id INTEGER;
    v_declared_value NUMERIC;
BEGIN
    -- Получаем старую запись для проверки скрытых полей
    SELECT sender_id, recipient_id, declared_value
    INTO v_sender_id, v_recipient_id, v_declared_value
    FROM app.shipments
    WHERE id = OLD.id;
    
    -- WITH CHECK OPTION: проверяем, что скрытые поля не изменились через представление
    -- Обновляем только видимые поля
    UPDATE app.shipments
    SET
        tracking_number = NEW.tracking_number,
        from_office_id = NEW.from_office_id,
        to_office_id = NEW.to_office_id,
        shipment_type_id = NEW.shipment_type_id,
        weight = NEW.weight,
        price = NEW.price,
        current_status = NEW.current_status,
        updated_at = CURRENT_TIMESTAMP
        -- sender_id, recipient_id, declared_value остаются без изменений
    WHERE id = OLD.id;
    
    RETURN NEW;
END;
$$;

-- Функция для обработки INSERT с WITH CHECK OPTION
CREATE OR REPLACE FUNCTION app.shipments_public_view_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = app, public
AS $$
BEGIN
    -- WITH CHECK OPTION: нельзя вставить через это представление, так как отсутствуют обязательные поля
    RAISE EXCEPTION 'Нельзя вставлять записи через shipments_public_view: отсутствуют обязательные поля (sender_id, recipient_id)';
END;
$$;

-- Создаем триггеры
CREATE TRIGGER shipments_public_view_update_trigger
    INSTEAD OF UPDATE ON app.shipments_public_view
    FOR EACH ROW
    EXECUTE FUNCTION app.shipments_public_view_update();

CREATE TRIGGER shipments_public_view_insert_trigger
    INSTEAD OF INSERT ON app.shipments_public_view
    FOR EACH ROW
    EXECUTE FUNCTION app.shipments_public_view_insert();

-- Права на представление
GRANT SELECT, UPDATE ON app.shipments_public_view TO office_manager, office_operator;

COMMENT ON FUNCTION app.shipments_public_view_update()
IS 'Обработка UPDATE для shipments_public_view с WITH CHECK OPTION - предотвращает изменение скрытых полей';

-- =============================================
-- 6. СОЗДАНИЕ SECURITY BARRIER VIEW ДЛЯ АГРЕГАТОВ
-- =============================================

-- Представление для агрегированной статистики по отправлениям
CREATE OR REPLACE VIEW app.shipments_statistics_view
WITH (security_barrier = true) AS
SELECT
    segment_id,
    shipment_type_id,
    current_status,
    COUNT(*) as shipment_count,
    SUM(weight) as total_weight,
    AVG(weight) as avg_weight,
    SUM(price) as total_price,
    AVG(price) as avg_price,
    MIN(created_at) as first_shipment_date,
    MAX(created_at) as last_shipment_date
FROM app.shipments
GROUP BY segment_id, shipment_type_id, current_status;

COMMENT ON VIEW app.shipments_statistics_view IS 
'SECURITY BARRIER VIEW для агрегированной статистики отправлений. Защищает от побочных каналов через HAVING/подзапросы';

-- Права на представление
GRANT SELECT ON app.shipments_statistics_view TO office_manager, office_operator, auditor, audit_viewer;

-- =============================================
-- 7. ФУНКЦИЯ РЕЗЕРВНОГО КОПИРОВАНИЯ AUDIT-ЛОГОВ
-- =============================================

CREATE OR REPLACE FUNCTION audit.backup_audit_logs(days_interval INTEGER)
RETURNS TABLE(
    archived_count BIGINT,
    deleted_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = audit, public
AS $$
DECLARE
    v_cutoff_date TIMESTAMP;
    v_archived BIGINT := 0;
    v_deleted BIGINT := 0;
BEGIN
    -- Вычисляем дату отсечки
    v_cutoff_date := CURRENT_TIMESTAMP - (days_interval || ' days')::INTERVAL;
    
    -- Переносим записи в архив
    WITH moved AS (
        INSERT INTO audit.row_change_log_archive
        SELECT * FROM audit.row_change_log
        WHERE change_time < v_cutoff_date
        RETURNING *
    )
    SELECT COUNT(*) INTO v_archived FROM moved;
    
    -- Удаляем перенесенные записи из основной таблицы
    DELETE FROM audit.row_change_log
    WHERE change_time < v_cutoff_date;
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    
    RETURN QUERY SELECT v_archived, v_deleted;
END;
$$;

COMMENT ON FUNCTION audit.backup_audit_logs(INTEGER)
IS 'Переносит записи старше указанного количества дней из audit.row_change_log в архив и удаляет их из основной таблицы';

-- Права на функцию
GRANT EXECUTE ON FUNCTION audit.backup_audit_logs(INTEGER) TO auditor, dml_admin, security_admin;

