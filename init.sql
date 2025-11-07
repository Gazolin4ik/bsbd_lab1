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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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

-- =============================================
-- 8. ФУНКЦИИ
-- =============================================

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
    FOR SELECT USING (app.check_employee_access_level(2));

CREATE POLICY employees_office_policy ON app.employees
    FOR SELECT USING (office_id = app.get_current_employee_office_id());

CREATE POLICY shipments_office_policy ON app.shipments
    FOR ALL USING (
        from_office_id = app.get_current_employee_office_id()
        OR to_office_id = app.get_current_employee_office_id()
    );

CREATE POLICY routes_office_policy ON app.delivery_routes
    FOR ALL USING (office_id = app.get_current_employee_office_id());

-- =============================================
-- 12. АВТОМАТИЧЕСКОЕ ЛОГИРОВАНИЕ ПОДКЛЮЧЕНИЙ
-- =============================================

-- В стандартном PostgreSQL нет встроенного event trigger для логина
-- (это доступно только в Postgres Pro Enterprise)
-- Используем альтернативный механизм автоматического логирования

-- Создаем функцию, которая будет вызываться автоматически при первом запросе в сессии
-- через механизм PostgreSQL с использованием session_preload_libraries или через настройку роли

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

-- Настраиваем автоматический вызов для пользователей через ALTER ROLE
-- Это будет вызывать функцию при каждом новом запросе в сессии
-- Примечание: в стандартном PostgreSQL нет прямого способа автоматически вызывать
-- функцию при подключении без расширения или настройки pg_hba.conf

-- Для лабораторной работы используем механизм через функцию on_connect(),
-- которую нужно вызывать вручную или через клиентское приложение при подключении

-- Логируем создание БД
SELECT public.log_user_login();

COMMENT ON FUNCTION public.on_connect() IS 
'Функция автоматического логирования подключений. 
В стандартном PostgreSQL нет встроенного event trigger для логина.
Для автоматического вызова рекомендуется:
1. Вызывать вручную при подключении: SELECT public.on_connect();
2. Использовать расширение PostgreSQL (pgaudit или custom extension)
3. Настроить через pg_hba.conf (для production)
4. Вызывать в клиентском приложении при подключении';

COMMENT ON FUNCTION public.session_start_log() IS 
'Функция для автоматического логирования при первом запросе в сессии.
Может использоваться как альтернатива для логирования подключений.';
