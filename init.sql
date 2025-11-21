-- =============================================
-- 1. НАСТРОЙКА ЧАСОВОГО ПОЯСА
-- =============================================

-- Устанавливаем часовой пояс для базы данных
-- Asia/Krasnoyarsk = UTC+7
ALTER DATABASE bsbd_lab1 SET timezone = 'Asia/Krasnoyarsk';

-- Устанавливаем часовой пояс для сессии
SET timezone = 'Asia/Krasnoyarsk';

-- =============================================
-- 2. ОТЗЫВ ПРАВ PUBLIC
-- =============================================

REVOKE ALL ON DATABASE bsbd_lab1 FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- =============================================
-- 3. СОЗДАНИЕ СХЕМ
-- =============================================

CREATE SCHEMA app;
CREATE SCHEMA ref;
CREATE SCHEMA audit;
CREATE SCHEMA stg;

REVOKE ALL ON SCHEMA app, ref, audit, stg FROM PUBLIC;

-- =============================================
-- 4. СОЗДАНИЕ РОЛЕЙ
-- =============================================

-- Групповые роли
CREATE ROLE app_reader NOLOGIN;
CREATE ROLE app_writer NOLOGIN;
CREATE ROLE auditor NOLOGIN;

-- Роли разделения обязанностей
CREATE ROLE ddl_admin NOLOGIN;
CREATE ROLE dml_admin NOLOGIN;
CREATE ROLE security_admin NOLOGIN;

-- Логин-роли приложения
CREATE ROLE office_manager NOLOGIN;
CREATE ROLE office_operator NOLOGIN;
CREATE ROLE audit_viewer NOLOGIN;

-- =============================================
-- 5. СОЗДАНИЕ ПОЛЬЗОВАТЕЛЕЙ
-- =============================================

-- Удаляем если существуют
DROP ROLE IF EXISTS "anna_ivanova";
DROP ROLE IF EXISTS "petr_smirnov";
DROP ROLE IF EXISTS "maria_petrova";

-- Создаем логин-пользователей (латинскими буквами чтобы избежать проблем)
CREATE ROLE anna_ivanova LOGIN PASSWORD 'anna123';
CREATE ROLE petr_smirnov LOGIN PASSWORD 'petr123';
CREATE ROLE maria_petrova LOGIN PASSWORD 'maria123';

-- Назначаем роли
GRANT office_manager TO anna_ivanova;
GRANT office_operator TO petr_smirnov;
GRANT office_operator TO maria_petrova;
GRANT audit_viewer TO anna_ivanova, petr_smirnov, maria_petrova;

-- Права на подключение
GRANT CONNECT ON DATABASE bsbd_lab1 TO anna_ivanova, petr_smirnov, maria_petrova;

-- =============================================
-- 6. СОЗДАНИЕ ТАБЛИЦ
-- =============================================

-- Справочник типов отделений
CREATE TABLE ref.office_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

COMMENT ON TABLE ref.office_types IS 'Типы почтовых отделений';

-- Справочник должностей
CREATE TABLE ref.positions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    access_level INTEGER NOT NULL CHECK (access_level BETWEEN 1 AND 3)
);

COMMENT ON TABLE ref.positions IS 'Должности сотрудников';

-- Справочник типов отправлений
CREATE TABLE ref.shipment_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    max_weight DECIMAL(10,2),
    base_price DECIMAL(10,2)
);

COMMENT ON TABLE ref.shipment_types IS 'Типы почтовых отправлений';

-- Таблица отделений
CREATE TABLE app.offices (
    id SERIAL PRIMARY KEY,
    office_number VARCHAR(20) NOT NULL UNIQUE,
    address TEXT NOT NULL,
    office_type_id INTEGER NOT NULL REFERENCES ref.office_types(id),
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE app.offices IS 'Почтовые отделения';

-- Таблица пользователей
CREATE TABLE app.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    passport_data VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE app.users IS 'Пользователи (отправители и получатели)';

-- Таблица сотрудников
CREATE TABLE app.employees (
    id SERIAL PRIMARY KEY,
    office_id INTEGER NOT NULL REFERENCES app.offices(id),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    position_id INTEGER NOT NULL REFERENCES ref.positions(id),
    hire_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE app.employees IS 'Сотрудники почтовых отделений';

-- Таблица отправлений
CREATE TABLE app.shipments (
    id SERIAL PRIMARY KEY,
    tracking_number VARCHAR(50) NOT NULL UNIQUE,
    from_office_id INTEGER NOT NULL REFERENCES app.offices(id),
    to_office_id INTEGER NOT NULL REFERENCES app.offices(id),
    sender_id INTEGER NOT NULL REFERENCES app.users(id),
    recipient_id INTEGER NOT NULL REFERENCES app.users(id),
    shipment_type_id INTEGER NOT NULL REFERENCES ref.shipment_types(id),
    weight DECIMAL(10,2) NOT NULL CHECK (weight > 0),
    declared_value DECIMAL(15,2),
    price DECIMAL(10,2) NOT NULL,
    current_status VARCHAR(50) DEFAULT 'created',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_shipments_declared_vs_price CHECK (
        declared_value IS NULL OR declared_value >= price
    )
);

COMMENT ON TABLE app.shipments IS 'Почтовые отправления';

-- Таблица маршрутов доставки
CREATE TABLE app.delivery_routes (
    id SERIAL PRIMARY KEY,
    shipment_id INTEGER NOT NULL REFERENCES app.shipments(id),
    office_id INTEGER NOT NULL REFERENCES app.offices(id),
    sequence_order INTEGER NOT NULL,
    planned_arrival TIMESTAMP,
    actual_arrival TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE app.delivery_routes IS 'Маршруты доставки отправлений';

-- Таблица операций
CREATE TABLE app.shipment_operations (
    id SERIAL PRIMARY KEY,
    shipment_id INTEGER NOT NULL REFERENCES app.shipments(id),
    employee_id INTEGER NOT NULL REFERENCES app.employees(id),
    operation_type VARCHAR(50) NOT NULL,
    operation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    location VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE app.shipment_operations IS 'Операции с отправлениями';

-- Таблица для сопоставления пользователей
CREATE TABLE app.user_mappings (
    id SERIAL PRIMARY KEY,
    db_username VARCHAR(100) NOT NULL UNIQUE,
    employee_id INTEGER NOT NULL REFERENCES app.employees(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE app.user_mappings IS 'Соответствие пользователей БД и сотрудников';

-- Таблица аудита подключений
CREATE TABLE audit.login_log (
    id SERIAL PRIMARY KEY,
    login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(100) NOT NULL,
    client_ip INET,
    success BOOLEAN NOT NULL,
    error_message TEXT
);

COMMENT ON TABLE audit.login_log IS 'Лог подключений пользователей';

-- Таблица аудита изменений
CREATE TABLE audit.data_changes (
    id SERIAL PRIMARY KEY,
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER,
    operation VARCHAR(10) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(100) NOT NULL
);

COMMENT ON TABLE audit.data_changes IS 'Аудит изменений данных';

-- Журнал вызовов SECURITY DEFINER функций
CREATE TABLE audit.function_calls (
    id BIGSERIAL PRIMARY KEY,
    call_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    function_name TEXT NOT NULL,
    caller_role TEXT NOT NULL,
    input_params JSONB,
    success BOOLEAN NOT NULL,
    error_message TEXT
);

COMMENT ON TABLE audit.function_calls IS 'Журнал вызовов SECURITY DEFINER функций';

-- =============================================
-- 7. ИНДЕКСЫ
-- =============================================

CREATE INDEX idx_shipments_tracking ON app.shipments(tracking_number);
CREATE INDEX idx_shipments_status ON app.shipments(current_status);
CREATE INDEX idx_shipments_sender ON app.shipments(sender_id);
CREATE INDEX idx_shipments_recipient ON app.shipments(recipient_id);
CREATE INDEX idx_routes_shipment ON app.delivery_routes(shipment_id);
CREATE INDEX idx_operations_shipment ON app.shipment_operations(shipment_id);
CREATE INDEX idx_employees_office ON app.employees(office_id);
CREATE INDEX idx_users_email ON app.users(email);
CREATE INDEX idx_users_phone ON app.users(phone);
CREATE INDEX idx_function_calls_name ON audit.function_calls(function_name);
CREATE INDEX idx_function_calls_caller ON audit.function_calls(caller_role);

-- =============================================
-- 8. ТРИГГЕРЫ КОНТРОЛЯ БИЗНЕС-ПРАВИЛ
-- =============================================

CREATE OR REPLACE FUNCTION app.enforce_shipment_weight_limit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = app, public
AS $$
DECLARE
    v_max_weight NUMERIC;
BEGIN
    SELECT max_weight INTO v_max_weight
    FROM ref.shipment_types
    WHERE id = NEW.shipment_type_id;

    IF v_max_weight IS NOT NULL AND NEW.weight > v_max_weight THEN
        RAISE EXCEPTION USING MESSAGE = format(
            'Вес %s превышает лимит %s для типа %s',
            NEW.weight::TEXT, v_max_weight::TEXT, NEW.shipment_type_id::TEXT
        );
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.enforce_shipment_weight_limit()
IS 'Проверка веса отправления относительно лимита типа (CHECK vs Trigger сравнение)';

CREATE TRIGGER trg_shipments_weight_limit
BEFORE INSERT OR UPDATE OF weight, shipment_type_id
ON app.shipments
FOR EACH ROW
EXECUTE FUNCTION app.enforce_shipment_weight_limit();

-- =============================================
-- 8. ФУНКЦИИ
-- =============================================

-- Унифицированное логирование SECURITY DEFINER функций
CREATE OR REPLACE FUNCTION audit.log_function_call(
    p_function_name TEXT,
    p_input_params JSONB,
    p_success BOOLEAN,
    p_error_message TEXT DEFAULT NULL,
    p_caller_role TEXT DEFAULT NULL
)
RETURNS void
SECURITY DEFINER
SET search_path = audit, public
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO audit.function_calls (function_name, caller_role, input_params, success, error_message)
    VALUES (
        p_function_name,
        COALESCE(p_caller_role, session_user),
        p_input_params,
        p_success,
        p_error_message
    );
END;
$$;

COMMENT ON FUNCTION audit.log_function_call(TEXT, JSONB, BOOLEAN, TEXT, TEXT)
IS 'Фиксация вызовов SECURITY DEFINER функций с указанием вызывающей роли и входных параметров';

-- Функция получения ID сотрудника
CREATE OR REPLACE FUNCTION app.get_current_employee_id()
RETURNS INTEGER
SECURITY DEFINER
SET search_path = app, public
LANGUAGE plpgsql
AS $$
DECLARE
    emp_id INTEGER;
BEGIN
    SELECT um.employee_id INTO emp_id 
    FROM app.user_mappings um
    WHERE um.db_username = current_user;
    
    RETURN emp_id;
END;
$$;

-- Функция получения office_id сотрудника
CREATE OR REPLACE FUNCTION app.get_current_employee_office_id()
RETURNS INTEGER
SECURITY DEFINER
SET search_path = app, public
LANGUAGE plpgsql
AS $$
DECLARE
    office_id INTEGER;
BEGIN
    SELECT e.office_id INTO office_id 
    FROM app.employees e
    JOIN app.user_mappings um ON e.id = um.employee_id
    WHERE um.db_username = current_user;
    
    RETURN office_id;
END;
$$;

-- Функция проверки уровня доступа
CREATE OR REPLACE FUNCTION app.check_employee_access_level(min_level INTEGER)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = app, public
LANGUAGE plpgsql
AS $$
DECLARE
    has_access BOOLEAN;
    current_emp_id INTEGER;
BEGIN
    current_emp_id := app.get_current_employee_id();
    
    SELECT EXISTS (
        SELECT 1 
        FROM app.employees e 
        JOIN ref.positions p ON e.position_id = p.id 
        WHERE p.access_level >= min_level
        AND e.id = current_emp_id
    ) INTO has_access;
    
    RETURN has_access;
END;
$$;

-- Функция логирования подключений
CREATE OR REPLACE FUNCTION audit.log_connection()
RETURNS void
SECURITY DEFINER
SET search_path = audit, public
LANGUAGE plpgsql
AS $$
DECLARE
    actual_username TEXT;
BEGIN
    -- Используем session_user для получения реального пользователя сессии
    -- session_user показывает пользователя, который подключился к БД
    -- current_user в SECURITY DEFINER функции всегда возвращает владельца функции
    actual_username := session_user;
    
    -- Используем CURRENT_TIMESTAMP который учитывает установленный timezone
    INSERT INTO audit.login_log (username, client_ip, success, login_time)
    VALUES (actual_username, inet_client_addr(), true, CURRENT_TIMESTAMP);
EXCEPTION
    WHEN others THEN
        INSERT INTO audit.login_log (username, client_ip, success, error_message, login_time)
        VALUES (actual_username, inet_client_addr(), false, SQLERRM, CURRENT_TIMESTAMP);
END;
$$;

-- Функция для вызова логирования
CREATE OR REPLACE FUNCTION public.log_user_login()
RETURNS void
SECURITY DEFINER
SET search_path = audit, public
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM audit.log_connection();
END;
$$;

-- Функция автоматического логирования при подключении
-- В стандартном PostgreSQL нет встроенного event trigger для логина
-- Эта функция предназначена для вызова при подключении пользователя
CREATE OR REPLACE FUNCTION public.on_connect()
RETURNS void
SECURITY DEFINER
SET search_path = audit, public
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM audit.log_connection();
END;
$$;

COMMENT ON FUNCTION public.log_user_login() IS 'Ручное логирование подключения пользователя';
COMMENT ON FUNCTION public.on_connect() IS 
'Функция для автоматического логирования при подключении.
В стандартном PostgreSQL нет встроенного event trigger для логина.
Для автоматического вызова необходимо:
1. Вызывать вручную: SELECT public.on_connect();
2. Использовать расширение PostgreSQL (pgaudit)
3. Настроить через pg_hba.conf
4. Вызывать в клиентском приложении при подключении';

-- =============================================
-- 9. ЗАПОЛНЕНИЕ ДАННЫМИ
-- =============================================

-- Справочники
INSERT INTO ref.office_types (code, name, description) VALUES
('HEAD', 'Главное отделение', 'Центральное отделение города'),
('DIST', 'Районное отделение', 'Отделение в районе города'),
('VILL', 'Сельское отделение', 'Отделение в сельской местности');

INSERT INTO ref.positions (code, name, access_level) VALUES
('DIR', 'Директор', 3),
('OPM', 'Оператор', 1),
('COURIER', 'Курьер', 2),
('MANAGER', 'Менеджер', 2);

INSERT INTO ref.shipment_types (code, name, max_weight, base_price) VALUES
('LETTER', 'Письмо', 0.1, 50.00),
('PARCEL', 'Посылка', 20.0, 200.00),
('REGISTERED', 'Заказное письмо', 0.1, 100.00),
('EXPRESS', 'Экспресс-отправление', 5.0, 500.00);

-- Отделения
INSERT INTO app.offices (office_number, address, office_type_id, phone) VALUES
('MOS001', 'г. Москва, ул. Тверская, д. 1', 1, '+7-495-111-11-11'),
('MOS002', 'г. Москва, ул. Арбат, д. 25', 2, '+7-495-222-22-22'),
('SPB001', 'г. Санкт-Петербург, Невский пр., д. 10', 1, '+7-812-333-33-33'),
('NOV001', 'г. Новосибирск, ул. Ленина, д. 5', 1, '+7-383-444-44-44');

-- Пользователи
INSERT INTO app.users (email, phone, passport_data) VALUES
('ivanov@mail.ru', '+7-911-111-11-11', 'encrypted_1'),
('petrov@gmail.com', '+7-922-222-22-22', 'encrypted_2'),
('sidorov@yandex.ru', '+7-933-333-33-33', 'encrypted_3'),
('smirnova@mail.ru', '+7-944-444-44-44', 'encrypted_4'),
('kuznetsov@gmail.com', '+7-955-555-55-55', 'encrypted_5');

-- Сотрудники
INSERT INTO app.employees (office_id, first_name, last_name, position_id, hire_date) VALUES
(1, 'Анна', 'Иванова', 4, '2020-01-15'),  -- MANAGER
(1, 'Петр', 'Смирнов', 2, '2021-03-20'),   -- OPERATOR
(2, 'Мария', 'Петрова', 2, '2022-05-10'),  -- OPERATOR
(3, 'Алексей', 'Козлов', 3, '2021-07-15'), -- COURIER
(4, 'Ольга', 'Новикова', 1, '2020-11-30'); -- DIRECTOR

-- Отправления
INSERT INTO app.shipments (tracking_number, from_office_id, to_office_id, sender_id, recipient_id, shipment_type_id, weight, declared_value, price) VALUES
('TRK001', 1, 3, 1, 2, 1, 0.05, NULL, 50.00),
('TRK002', 2, 4, 2, 3, 2, 2.5, 5000.00, 200.00),
('TRK003', 3, 1, 3, 1, 3, 0.08, 1000.00, 100.00),
('TRK004', 1, 2, 4, 5, 4, 1.2, 15000.00, 500.00);

-- Маршруты
INSERT INTO app.delivery_routes (shipment_id, office_id, sequence_order, planned_arrival, status) VALUES
(1, 1, 1, '2024-01-15 10:00:00', 'completed'),
(1, 2, 2, '2024-01-16 12:00:00', 'pending'),
(1, 3, 3, '2024-01-17 14:00:00', 'pending'),
(2, 2, 1, '2024-01-15 11:00:00', 'completed'),
(2, 4, 2, '2024-01-18 16:00:00', 'pending');

-- Операции
INSERT INTO app.shipment_operations (shipment_id, employee_id, operation_type, location, notes) VALUES
(1, 2, 'прием', 'MOS001', 'Отправление принято'),
(1, 2, 'сортировка', 'MOS001', 'Отправление отсортировано'),
(2, 3, 'прием', 'MOS002', 'Посылка принята'),
(3, 4, 'прием', 'SPB001', 'Заказное письмо принято');

-- Соответствия пользователей
INSERT INTO app.user_mappings (db_username, employee_id) VALUES
('anna_ivanova', 1),
('petr_smirnov', 2),
('maria_petrova', 3);

-- =============================================
-- 10. НАСТРОЙКА ПРАВ ДОСТУПА
-- =============================================

-- Назначаем права для групповых ролей
GRANT app_reader TO office_operator;
GRANT app_writer TO office_manager;
GRANT auditor TO audit_viewer;

-- Права для app_reader
GRANT USAGE ON SCHEMA app TO app_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_reader;

-- Права для app_writer  
GRANT USAGE ON SCHEMA app TO app_writer;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA app TO app_writer;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA app TO app_writer;

-- Права для auditor
GRANT USAGE ON SCHEMA audit TO auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO auditor;

-- Права для ddl_admin
GRANT CREATE ON SCHEMA public TO ddl_admin;
GRANT CREATE ON SCHEMA app TO ddl_admin;
GRANT CREATE ON SCHEMA ref TO ddl_admin;
GRANT CREATE ON SCHEMA audit TO ddl_admin;

-- Права для dml_admin
GRANT USAGE ON SCHEMA app TO dml_admin;
GRANT USAGE ON SCHEMA ref TO dml_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO dml_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ref TO dml_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA app TO dml_admin;

-- Права для security_admin
ALTER ROLE security_admin CREATEROLE;

-- Права на схемы
GRANT USAGE ON SCHEMA app TO office_manager, office_operator;
GRANT USAGE ON SCHEMA ref TO office_manager, office_operator;
GRANT USAGE ON SCHEMA audit TO audit_viewer;

-- Права на таблицы app
GRANT SELECT ON ALL TABLES IN SCHEMA app TO office_operator;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA app TO office_manager;

-- Права на таблицы ref
GRANT SELECT ON ALL TABLES IN SCHEMA ref TO office_operator, office_manager;

-- Права на таблицы audit
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO audit_viewer;

-- Права на последовательности
GRANT USAGE ON ALL SEQUENCES IN SCHEMA app TO office_manager;

-- DEFAULT PRIVILEGES
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT ON TABLES TO office_operator;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT, INSERT, UPDATE ON TABLES TO office_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA ref GRANT SELECT ON TABLES TO office_operator, office_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT SELECT ON TABLES TO audit_viewer;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT USAGE ON SEQUENCES TO office_manager;

-- Права на функции
GRANT EXECUTE ON FUNCTION public.log_user_login() TO office_manager, office_operator, audit_viewer;
GRANT EXECUTE ON FUNCTION public.on_connect() TO office_manager, office_operator, audit_viewer;
-- Настройка автоматического логирования подключений
-- Для каждого пользователя устанавливаем автоматический вызов функции при подключении
-- Используем ALTER ROLE для установки функции, которая будет вызываться при подключении
ALTER ROLE anna_ivanova SET search_path = app, public;
ALTER ROLE petr_smirnov SET search_path = app, public;
ALTER ROLE maria_petrova SET search_path = app, public;

-- =============================================
-- 11. ROW LEVEL SECURITY
-- =============================================

-- Включаем RLS
ALTER TABLE app.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.delivery_routes ENABLE ROW LEVEL SECURITY;

-- FORCE RLS
ALTER TABLE app.users FORCE ROW LEVEL SECURITY;
ALTER TABLE app.employees FORCE ROW LEVEL SECURITY;
ALTER TABLE app.shipments FORCE ROW LEVEL SECURITY;
ALTER TABLE app.delivery_routes FORCE ROW LEVEL SECURITY;

-- Политики RLS
CREATE POLICY users_select_policy ON app.users
    FOR SELECT USING (
        current_user <> session_user
        OR app.check_employee_access_level(2)
    );

CREATE POLICY employees_office_policy ON app.employees
    FOR SELECT USING (
        current_user <> session_user
        OR office_id = app.get_current_employee_office_id()
    );

CREATE POLICY shipments_office_policy ON app.shipments
    FOR ALL USING (
        current_user <> session_user
        OR from_office_id = app.get_current_employee_office_id()
        OR to_office_id = app.get_current_employee_office_id()
    );

CREATE POLICY routes_office_policy ON app.delivery_routes
    FOR ALL USING (
        current_user <> session_user
        OR office_id = app.get_current_employee_office_id()
    );

-- =============================================
-- 12. АВТОМАТИЧЕСКОЕ ЛОГИРОВАНИЕ ПОДКЛЮЧЕНИЙ
-- =============================================

-- Функция для автоматического логирования при первом запросе в сессии
CREATE OR REPLACE FUNCTION public.session_start_log()
RETURNS void
SECURITY DEFINER
SET search_path = audit, public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Логируем подключение только если еще не логировали в этой сессии
    -- Используем временную таблицу для отслеживания
    IF NOT EXISTS (
        SELECT 1 FROM pg_temp.session_logged 
        WHERE session_id = pg_backend_pid()
    ) THEN
        PERFORM audit.log_connection();
        -- Создаем временную таблицу для отслеживания
        CREATE TEMP TABLE IF NOT EXISTS session_logged (
            session_id INTEGER PRIMARY KEY,
            logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ON COMMIT DROP;
        INSERT INTO pg_temp.session_logged (session_id) VALUES (pg_backend_pid());
    END IF;
END;
$$;

-- Настраиваем автоматический вызов функции при первом запросе в сессии
-- через настройку роли (будет вызываться при каждом новом запросе)
-- Для каждого пользователя устанавливаем функцию, которая будет вызываться автоматически

-- Альтернативный подход: используем функцию-обертку для автоматического логирования
CREATE OR REPLACE FUNCTION public.auto_log_on_query()
RETURNS void
SECURITY DEFINER
SET search_path = audit, public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Логируем подключение при первом запросе в сессии
    PERFORM public.session_start_log();
END;
$$;

-- =============================================
-- SECURITY DEFINER ФУНКЦИИ ДЛЯ ЛР2
-- =============================================

CREATE OR REPLACE FUNCTION app.secure_create_shipment(
    p_tracking_number TEXT,
    p_from_office_id INTEGER,
    p_to_office_id INTEGER,
    p_sender_id INTEGER,
    p_recipient_id INTEGER,
    p_shipment_type_id INTEGER,
    p_weight NUMERIC,
    p_declared_value NUMERIC,
    p_price NUMERIC
)
RETURNS INTEGER
SECURITY DEFINER
SET search_path = app, public
LANGUAGE plpgsql
AS $$
DECLARE
    v_shipment_id INTEGER;
    v_max_weight NUMERIC;
    v_input JSONB := jsonb_strip_nulls(
        jsonb_build_object(
            'tracking_number', p_tracking_number,
            'from_office_id', p_from_office_id,
            'to_office_id', p_to_office_id,
            'shipment_type_id', p_shipment_type_id,
            'weight', p_weight,
            'price', p_price
        )
    );
BEGIN
    BEGIN
        IF p_tracking_number IS NULL OR length(trim(p_tracking_number)) < 5 THEN
            RAISE EXCEPTION USING MESSAGE = 'Номер отслеживания должен содержать минимум 5 символов';
        END IF;

        IF p_from_office_id = p_to_office_id THEN
            RAISE EXCEPTION USING MESSAGE = 'Отправляющее и получающее отделения должны различаться';
        END IF;

        IF p_weight IS NULL OR p_weight <= 0 THEN
            RAISE EXCEPTION USING MESSAGE = 'Вес отправления должен быть больше нуля';
        END IF;

        IF p_price IS NULL OR p_price <= 0 THEN
            RAISE EXCEPTION USING MESSAGE = 'Стоимость услуги должна быть больше нуля';
        END IF;

        IF p_declared_value IS NOT NULL AND p_declared_value < p_price THEN
            RAISE EXCEPTION USING MESSAGE = 'Объявленная стоимость не может быть меньше фактической стоимости услуги';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM app.offices WHERE id = p_from_office_id) THEN
            RAISE EXCEPTION USING MESSAGE = format('Отделение-отправитель %s не найдено', p_from_office_id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM app.offices WHERE id = p_to_office_id) THEN
            RAISE EXCEPTION USING MESSAGE = format('Отделение-получатель %s не найдено', p_to_office_id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM app.users WHERE id = p_sender_id) THEN
            RAISE EXCEPTION USING MESSAGE = format('Отправитель %s не найден', p_sender_id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM app.users WHERE id = p_recipient_id) THEN
            RAISE EXCEPTION USING MESSAGE = format('Получатель %s не найден', p_recipient_id);
        END IF;

        SELECT max_weight INTO v_max_weight
        FROM ref.shipment_types
        WHERE id = p_shipment_type_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING MESSAGE = format('Тип отправления %s не найден', p_shipment_type_id);
        END IF;

        IF v_max_weight IS NOT NULL AND p_weight > v_max_weight THEN
            RAISE EXCEPTION USING MESSAGE = format(
                'Вес %s превышает допустимый предел %s для типа %s',
                p_weight::TEXT, v_max_weight::TEXT, p_shipment_type_id::TEXT
            );
        END IF;

        INSERT INTO app.shipments (
            tracking_number,
            from_office_id,
            to_office_id,
            sender_id,
            recipient_id,
            shipment_type_id,
            weight,
            declared_value,
            price
        )
        VALUES (
            p_tracking_number,
            p_from_office_id,
            p_to_office_id,
            p_sender_id,
            p_recipient_id,
            p_shipment_type_id,
            p_weight,
            p_declared_value,
            p_price
        )
        RETURNING id INTO v_shipment_id;

        PERFORM audit.log_function_call(
            'app.secure_create_shipment',
            v_input,
            true,
            NULL,
            session_user
        );

        RETURN v_shipment_id;
    EXCEPTION
        WHEN OTHERS THEN
            PERFORM audit.log_function_call(
                'app.secure_create_shipment',
                v_input,
                false,
                SQLERRM,
                session_user
            );
            RAISE;
    END;
END;
$$;

COMMENT ON FUNCTION app.secure_create_shipment(
    TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, NUMERIC, NUMERIC, NUMERIC
) IS 'Создание отправления с повышенными привилегиями и валидацией входных данных';

CREATE OR REPLACE FUNCTION app.secure_update_shipment_status(
    p_tracking_number TEXT,
    p_new_status TEXT,
    p_comment TEXT DEFAULT NULL
)
RETURNS VOID
SECURITY DEFINER
SET search_path = app, public
LANGUAGE plpgsql
AS $$
DECLARE
    v_allowed_statuses CONSTANT TEXT[] := ARRAY[
        'created', 'accepted', 'in_transit', 'arrived', 'delivered', 'cancelled', 'returned'
    ];
    v_input JSONB := jsonb_strip_nulls(
        jsonb_build_object(
            'tracking_number', p_tracking_number,
            'new_status', p_new_status
        )
    );
BEGIN
    BEGIN
        IF p_new_status IS NULL OR NOT (p_new_status = ANY (v_allowed_statuses)) THEN
            RAISE EXCEPTION USING MESSAGE = format('Недопустимый статус отправления: %s', p_new_status);
        END IF;

        UPDATE app.shipments
        SET current_status = p_new_status,
            updated_at = CURRENT_TIMESTAMP
        WHERE tracking_number = p_tracking_number;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING MESSAGE = format('Отправление %s не найдено', p_tracking_number);
        END IF;

        PERFORM audit.log_function_call(
            'app.secure_update_shipment_status',
            v_input,
            true,
            NULL,
            session_user
        );
    EXCEPTION
        WHEN OTHERS THEN
            PERFORM audit.log_function_call(
                'app.secure_update_shipment_status',
                v_input,
                false,
                SQLERRM,
                session_user
            );
            RAISE;
    END;
END;
$$;

COMMENT ON FUNCTION app.secure_update_shipment_status(TEXT, TEXT, TEXT)
IS 'Безопасное обновление статуса отправления с журналированием';

CREATE OR REPLACE FUNCTION app.secure_adjust_declared_value(
    p_tracking_number TEXT,
    p_new_declared_value NUMERIC
)
RETURNS VOID
SECURITY DEFINER
SET search_path = app, public
LANGUAGE plpgsql
AS $$
DECLARE
    v_price NUMERIC;
    v_input JSONB := jsonb_strip_nulls(
        jsonb_build_object(
            'tracking_number', p_tracking_number,
            'new_declared_value', p_new_declared_value
        )
    );
BEGIN
    BEGIN
        IF p_new_declared_value IS NULL OR p_new_declared_value <= 0 THEN
            RAISE EXCEPTION USING MESSAGE = 'Объявленная стоимость должна быть положительным числом';
        END IF;

        SELECT price INTO v_price
        FROM app.shipments
        WHERE tracking_number = p_tracking_number
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING MESSAGE = format('Отправление %s не найдено', p_tracking_number);
        END IF;

        IF p_new_declared_value < v_price THEN
            RAISE EXCEPTION USING MESSAGE = 'Объявленная стоимость не может быть меньше фактической стоимости услуги';
        END IF;

        UPDATE app.shipments
        SET declared_value = p_new_declared_value,
            updated_at = CURRENT_TIMESTAMP
        WHERE tracking_number = p_tracking_number;

        PERFORM audit.log_function_call(
            'app.secure_adjust_declared_value',
            v_input,
            true,
            NULL,
            session_user
        );
    EXCEPTION
        WHEN OTHERS THEN
            PERFORM audit.log_function_call(
                'app.secure_adjust_declared_value',
                v_input,
                false,
                SQLERRM,
                session_user
            );
            RAISE;
    END;
END;
$$;

COMMENT ON FUNCTION app.secure_adjust_declared_value(TEXT, NUMERIC)
IS 'Контролируемое изменение объявленной стоимости отправления';

REVOKE ALL ON FUNCTION app.secure_create_shipment(
    TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, NUMERIC, NUMERIC, NUMERIC
) FROM PUBLIC;
REVOKE ALL ON FUNCTION app.secure_update_shipment_status(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION app.secure_adjust_declared_value(TEXT, NUMERIC) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION app.secure_create_shipment(
    TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, NUMERIC, NUMERIC, NUMERIC
) TO office_operator, office_manager, dml_admin;
GRANT EXECUTE ON FUNCTION app.secure_update_shipment_status(TEXT, TEXT, TEXT)
    TO office_manager, dml_admin;
GRANT EXECUTE ON FUNCTION app.secure_adjust_declared_value(TEXT, NUMERIC)
    TO office_manager, dml_admin;
GRANT SELECT ON audit.function_calls TO auditor, audit_viewer;

-- Логируем создание БД
SELECT public.log_user_login();
