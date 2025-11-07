-- Полные тесты безопасности БД почтовых отделений
-- Тестирование всех ролей и их прав доступа

-- =============================================
-- ТЕСТ 1: ПРОВЕРКА СУЩЕСТВОВАНИЯ РОЛЕЙ
-- =============================================

DO $$
DECLARE
    test_result TEXT;
    role_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO role_count
    FROM pg_roles 
    WHERE rolname IN ('app_reader', 'app_writer', 'auditor', 'ddl_admin', 'dml_admin', 'security_admin', 
                      'office_manager', 'office_operator', 'audit_viewer', 'anna_ivanova', 'petr_smirnov', 'maria_petrova');
    
    IF role_count = 12 THEN
        test_result := 'ТЕСТ 1: Все роли созданы - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 1: Все роли созданы - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 2: OFFICE_OPERATOR (ТОЛЬКО ЧТЕНИЕ)
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 2: Office Operator - ПРОЙДЕН';
BEGIN
    SET ROLE office_operator;
    
    -- Проверяем чтение (должно работать)
    BEGIN
        PERFORM * FROM app.offices LIMIT 1;
        PERFORM * FROM app.shipments LIMIT 1;
        PERFORM * FROM ref.shipment_types LIMIT 1;
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 2: Office Operator - ОШИБКА: Чтение не работает';
    END;
    
    -- Проверяем запрет записи (должна быть ошибка)
    BEGIN
        INSERT INTO app.shipment_operations (shipment_id, employee_id, operation_type, location) 
        VALUES (1, 1, 'тест', 'тест');
        test_result := 'ТЕСТ 2: Office Operator - ОШИБКА: Запись разрешена';
    EXCEPTION
        WHEN insufficient_privilege THEN
            test_result := 'ТЕСТ 2: Office Operator - ПРОЙДЕН';
    END;
    
    -- Проверяем запрет обновления (должна быть ошибка)
    BEGIN
        UPDATE app.shipments SET current_status = 'test' WHERE id = 1;
        test_result := 'ТЕСТ 2: Office Operator - ОШИБКА: Обновление разрешено';
    EXCEPTION
        WHEN insufficient_privilege THEN
            test_result := 'ТЕСТ 2: Office Operator - ПРОЙДЕН';
    END;
    
    RESET ROLE;
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 3: OFFICE_MANAGER (ЧТЕНИЕ И ЗАПИСЬ)
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 3: Office Manager - ПРОЙДЕН';
BEGIN
    SET ROLE office_manager;
    
    -- Проверяем чтение (должно работать)
    BEGIN
        PERFORM * FROM app.shipments LIMIT 1;
        PERFORM * FROM app.offices LIMIT 1;
        PERFORM * FROM ref.shipment_types LIMIT 1;
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 3: Office Manager - ОШИБКА: Чтение не работает';
    END;
    
    -- Проверяем запись (должно работать)
    BEGIN
        INSERT INTO app.shipment_operations (shipment_id, employee_id, operation_type, location) 
        VALUES (1, 1, 'обработка', 'MOS001');
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 3: Office Manager - ОШИБКА: Запись не работает';
    END;
    
    -- Проверяем обновление (должно работать)
    BEGIN
        UPDATE app.shipments SET current_status = 'processed' WHERE id = 1;
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 3: Office Manager - ОШИБКА: Обновление не работает';
    END;
    
    RESET ROLE;
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 4: AUDIT_VIEWER (ТОЛЬКО АУДИТ)
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 4: Audit Viewer - ПРОЙДЕН';
BEGIN
    SET ROLE audit_viewer;
    
    -- Проверяем чтение логов (должно работать)
    BEGIN
        PERFORM * FROM audit.login_log LIMIT 1;
        PERFORM * FROM audit.data_changes LIMIT 1;
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 4: Audit Viewer - ОШИБКА: Чтение логов не работает';
    END;
    
    -- Проверяем запрет доступа к app (должна быть ошибка)
    BEGIN
        PERFORM * FROM app.shipments LIMIT 1;
        test_result := 'ТЕСТ 4: Audit Viewer - ОШИБКА: Доступ к app разрешен';
    EXCEPTION
        WHEN insufficient_privilege THEN
            test_result := 'ТЕСТ 4: Audit Viewer - ПРОЙДЕН';
    END;
    
    -- Проверяем запрет доступа к ref (должна быть ошибка)
    BEGIN
        PERFORM * FROM ref.shipment_types LIMIT 1;
        test_result := 'ТЕСТ 4: Audit Viewer - ОШИБКА: Доступ к ref разрешен';
    EXCEPTION
        WHEN insufficient_privilege THEN
            test_result := 'ТЕСТ 4: Audit Viewer - ПРОЙДЕН';
    END;
    
    RESET ROLE;
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 5: APP_READER (ТОЛЬКО ЧТЕНИЕ APP)
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 5: App Reader - ПРОЙДЕН';
BEGIN
    SET ROLE app_reader;
    
    -- Проверяем чтение app (должно работать)
    BEGIN
        PERFORM * FROM app.offices LIMIT 1;
        PERFORM * FROM app.shipments LIMIT 1;
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 5: App Reader - ОШИБКА: Чтение app не работает';
    END;
    
    -- Проверяем запрет записи в app (должна быть ошибка)
    BEGIN
        INSERT INTO app.shipment_operations (shipment_id, employee_id, operation_type, location) 
        VALUES (1, 1, 'тест', 'тест');
        test_result := 'ТЕСТ 5: App Reader - ОШИБКА: Запись в app разрешена';
    EXCEPTION
        WHEN insufficient_privilege THEN
            test_result := 'ТЕСТ 5: App Reader - ПРОЙДЕН';
    END;
    
    RESET ROLE;
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 6: APP_WRITER (ЧТЕНИЕ И ЗАПИСЬ APP)
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 6: App Writer - ПРОЙДЕН';
BEGIN
    SET ROLE app_writer;
    
    -- Проверяем чтение app (должно работать)
    BEGIN
        PERFORM * FROM app.offices LIMIT 1;
        PERFORM * FROM app.shipments LIMIT 1;
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 6: App Writer - ОШИБКА: Чтение app не работает';
    END;
    
    -- Проверяем запись в app (должно работать)
    BEGIN
        INSERT INTO app.shipment_operations (shipment_id, employee_id, operation_type, location) 
        VALUES (1, 1, 'обработка', 'MOS001');
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 6: App Writer - ОШИБКА: Запись в app не работает';
    END;
    
    RESET ROLE;
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 7: AUDITOR (ТОЛЬКО АУДИТ)
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 7: Auditor - ПРОЙДЕН';
BEGIN
    SET ROLE auditor;
    
    -- Проверяем чтение audit (должно работать)
    BEGIN
        PERFORM * FROM audit.login_log LIMIT 1;
        PERFORM * FROM audit.data_changes LIMIT 1;
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 7: Auditor - ОШИБКА: Чтение audit не работает';
    END;
    
    -- Проверяем запрет доступа к app (должна быть ошибка)
    BEGIN
        PERFORM * FROM app.shipments LIMIT 1;
        test_result := 'ТЕСТ 7: Auditor - ОШИБКА: Доступ к app разрешен';
    EXCEPTION
        WHEN insufficient_privilege THEN
            test_result := 'ТЕСТ 7: Auditor - ПРОЙДЕН';
    END;
    
    RESET ROLE;
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 8: DDL_ADMIN (УПРАВЛЕНИЕ СТРУКТУРОЙ)
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 8: DDL Admin - ПРОЙДЕН';
BEGIN
    SET ROLE ddl_admin;
    
    -- Проверяем создание таблицы (должно работать)
    BEGIN
        CREATE TABLE test_ddl_table (id INTEGER);
        DROP TABLE test_ddl_table;
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 8: DDL Admin - ОШИБКА: DDL операции не работают';
    END;
    
    RESET ROLE;
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 9: DML_ADMIN (УПРАВЛЕНИЕ ДАННЫМИ)
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 9: DML Admin - ПРОЙДЕН';
BEGIN
    SET ROLE dml_admin;
    
    -- Проверяем чтение (должно работать)
    BEGIN
        PERFORM * FROM app.offices LIMIT 1;
        PERFORM * FROM app.shipments LIMIT 1;
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 9: DML Admin - ОШИБКА: Чтение не работает';
    END;
    
    -- Проверяем запись (должно работать)
    BEGIN
        INSERT INTO app.shipment_operations (shipment_id, employee_id, operation_type, location) 
        VALUES (1, 1, 'обработка', 'MOS001');
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 9: DML Admin - ОШИБКА: Запись не работает';
    END;
    
    RESET ROLE;
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 10: SECURITY_ADMIN (УПРАВЛЕНИЕ БЕЗОПАСНОСТЬЮ)
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 10: Security Admin - ПРОЙДЕН';
BEGIN
    SET ROLE security_admin;
    
    -- Проверяем управление ролями (должно работать)
    BEGIN
        CREATE ROLE test_security_role;
        DROP ROLE test_security_role;
    EXCEPTION
        WHEN OTHERS THEN
            test_result := 'ТЕСТ 10: Security Admin - ОШИБКА: Управление ролями не работает';
    END;
    
    RESET ROLE;
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 11: RLS ПОЛИТИКИ
-- =============================================

DO $$
DECLARE
    test_result TEXT;
    rls_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO rls_count
    FROM pg_tables t
    WHERE t.schemaname = 'app' AND t.rowsecurity = true;
    
    IF rls_count = 4 THEN
        test_result := 'ТЕСТ 11: RLS политики - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 11: RLS политики - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 12: ЛОГИРОВАНИЕ ПОДКЛЮЧЕНИЙ
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 12: Логирование - ПРОЙДЕН';
    log_count INTEGER;
BEGIN
    -- Логируем подключения
    SET ROLE office_operator;
    PERFORM public.log_user_login();
    RESET ROLE;
    
    SET ROLE office_manager;
    PERFORM public.log_user_login();
    RESET ROLE;
    
    -- Проверяем логи
    SELECT COUNT(*) INTO log_count FROM audit.login_log;
    
    IF log_count > 0 THEN
        test_result := 'ТЕСТ 12: Логирование - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 12: Логирование - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 13: ПОЛЬЗОВАТЕЛИ И РОЛИ
-- =============================================

DO $$
DECLARE
    test_result TEXT;
    user_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count
    FROM pg_roles 
    WHERE rolname IN ('anna_ivanova', 'petr_smirnov', 'maria_petrova')
    AND rolcanlogin = true;
    
    IF user_count = 3 THEN
        test_result := 'ТЕСТ 13: Пользователи - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 13: Пользователи - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 14: ТАБЛИЦЫ СОЗДАНЫ
-- =============================================

DO $$
DECLARE
    test_result TEXT;
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM pg_tables 
    WHERE schemaname IN ('app', 'ref', 'audit');
    
    IF table_count >= 12 THEN
        test_result := 'ТЕСТ 14: Таблицы - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 14: Таблицы - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 15: ПРОВЕРКА ПРАВ PUBLIC
-- =============================================

DO $$
DECLARE
    test_result TEXT;
    public_privs INTEGER;
BEGIN
    SELECT COUNT(*) INTO public_privs
    FROM information_schema.table_privileges 
    WHERE grantee = 'PUBLIC' 
    AND table_schema IN ('app', 'ref', 'audit');
    
    IF public_privs = 0 THEN
        test_result := 'ТЕСТ 15: Права PUBLIC отозваны - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 15: Права PUBLIC отозваны - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;
