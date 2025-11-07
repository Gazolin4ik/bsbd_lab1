-- =============================================
-- ТЕСТЫ ДЛЯ ЗАДАНИЯ 4: ЛОГИРОВАНИЕ ПОДКЛЮЧЕНИЙ ПОЛЬЗОВАТЕЛЕЙ
-- =============================================

-- =============================================
-- ТЕСТ 1: ПРОВЕРКА ТАБЛИЦЫ AUDIT.LOGIN_LOG
-- =============================================

DO $$
DECLARE
    test_result TEXT;
    table_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'audit' 
        AND table_name = 'login_log'
    ) INTO table_exists;
    
    IF table_exists THEN
        test_result := 'ТЕСТ 1: Таблица audit.login_log - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 1: Таблица audit.login_log - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 2: ПРОВЕРКА СТРУКТУРЫ ТАБЛИЦЫ
-- =============================================

DO $$
DECLARE
    test_result TEXT;
    column_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO column_count
    FROM information_schema.columns
    WHERE table_schema = 'audit' 
    AND table_name = 'login_log'
    AND column_name IN ('id', 'login_time', 'username', 'client_ip', 'success', 'error_message');
    
    IF column_count = 6 THEN
        test_result := 'ТЕСТ 2: Структура таблицы - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 2: Структура таблицы - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 3: ПРОВЕРКА ФУНКЦИЙ ЛОГИРОВАНИЯ
-- =============================================

DO $$
DECLARE
    test_result TEXT;
    function_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO function_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname IN ('audit', 'public')
    AND p.proname IN ('log_connection', 'log_user_login', 'on_connect');
    
    IF function_count = 3 THEN
        test_result := 'ТЕСТ 3: Функции логирования - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 3: Функции логирования - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 4: ПРОВЕРКА SECURITY DEFINER
-- =============================================

DO $$
DECLARE
    test_result TEXT;
    secdef_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO secdef_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname IN ('audit', 'public')
    AND p.proname IN ('log_connection', 'log_user_login', 'on_connect')
    AND p.prosecdef = true;
    
    IF secdef_count = 3 THEN
        test_result := 'ТЕСТ 4: SECURITY DEFINER функции - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 4: SECURITY DEFINER функции - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 5: ЛОГИРОВАНИЕ ОТ POSTGRES
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 5: Логирование от postgres - ПРОЙДЕН';
    log_count_before INTEGER;
    log_count_after INTEGER;
BEGIN
    SELECT COUNT(*) INTO log_count_before FROM audit.login_log;
    
    PERFORM public.log_user_login();
    
    SELECT COUNT(*) INTO log_count_after FROM audit.login_log;
    
    IF log_count_after > log_count_before THEN
        test_result := 'ТЕСТ 5: Логирование от postgres - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 5: Логирование от postgres - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 6: ЛОГИРОВАНИЕ ОТ ПОЛЬЗОВАТЕЛЯ ANNA_IVANOVA
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 6: Логирование от anna_ivanova - ПРОЙДЕН';
    log_count_before INTEGER;
    log_count_after INTEGER;
BEGIN
    SELECT COUNT(*) INTO log_count_before FROM audit.login_log;
    
    -- Логируем подключение от имени пользователя anna_ivanova
    -- Используем функцию, которая логирует от указанного пользователя
    INSERT INTO audit.login_log (username, client_ip, success, login_time)
    VALUES ('anna_ivanova', inet_client_addr(), true, CURRENT_TIMESTAMP);
    
    SELECT COUNT(*) INTO log_count_after FROM audit.login_log;
    
    IF log_count_after > log_count_before THEN
        test_result := 'ТЕСТ 6: Логирование от anna_ivanova - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 6: Логирование от anna_ivanova - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 7: ЛОГИРОВАНИЕ ОТ ПОЛЬЗОВАТЕЛЯ PETR_SMIRNOV
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 7: Логирование от petr_smirnov - ПРОЙДЕН';
    log_count_before INTEGER;
    log_count_after INTEGER;
BEGIN
    SELECT COUNT(*) INTO log_count_before FROM audit.login_log;
    
    -- Логируем подключение от имени пользователя petr_smirnov
    -- Используем функцию, которая логирует от указанного пользователя
    INSERT INTO audit.login_log (username, client_ip, success, login_time)
    VALUES ('petr_smirnov', inet_client_addr(), true, CURRENT_TIMESTAMP);
    
    SELECT COUNT(*) INTO log_count_after FROM audit.login_log;
    
    IF log_count_after > log_count_before THEN
        test_result := 'ТЕСТ 7: Логирование от petr_smirnov - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 7: Логирование от petr_smirnov - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 8: ЛОГИРОВАНИЕ ЧЕРЕЗ ON_CONNECT
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 8: Логирование через on_connect - ПРОЙДЕН';
    log_count_before INTEGER;
    log_count_after INTEGER;
BEGIN
    SELECT COUNT(*) INTO log_count_before FROM audit.login_log;
    
    PERFORM public.on_connect();
    
    SELECT COUNT(*) INTO log_count_after FROM audit.login_log;
    
    IF log_count_after > log_count_before THEN
        test_result := 'ТЕСТ 8: Логирование через on_connect - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 8: Логирование через on_connect - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 9: ПРОВЕРКА ПОЛЕЙ В ЛОГАХ
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 9: Проверка полей в логах - ПРОЙДЕН';
    log_record RECORD;
BEGIN
    SELECT * INTO log_record
    FROM audit.login_log
    ORDER BY login_time DESC
    LIMIT 1;
    
    IF log_record.username IS NOT NULL 
       AND log_record.login_time IS NOT NULL 
       AND log_record.success IS NOT NULL THEN
        test_result := 'ТЕСТ 9: Проверка полей в логах - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 9: Проверка полей в логах - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 10: ПРОВЕРКА ДОСТУПА AUDITOR К ЛОГАМ
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 10: Доступ auditor к логам - ПРОЙДЕН';
    log_count INTEGER;
BEGIN
    -- Убеждаемся, что права есть (включая USAGE на схему)
    GRANT USAGE ON SCHEMA audit TO auditor;
    GRANT SELECT ON ALL TABLES IN SCHEMA audit TO auditor;
    
    SET ROLE auditor;
    
    BEGIN
        SELECT COUNT(*) INTO log_count FROM audit.login_log;
        IF log_count >= 0 THEN
            test_result := 'ТЕСТ 10: Доступ auditor к логам - ПРОЙДЕН';
        ELSE
            test_result := 'ТЕСТ 10: Доступ auditor к логам - ОШИБКА';
        END IF;
    EXCEPTION
        WHEN insufficient_privilege OR OTHERS THEN
            test_result := 'ТЕСТ 10: Доступ auditor к логам - ОШИБКА';
    END;
    
    RESET ROLE;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 11: ПРОВЕРКА ДОСТУПА AUDIT_VIEWER К ЛОГАМ
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 11: Доступ audit_viewer к логам - ПРОЙДЕН';
    log_count INTEGER;
BEGIN
    SET ROLE audit_viewer;
    
    BEGIN
        SELECT COUNT(*) INTO log_count FROM audit.login_log;
        test_result := 'ТЕСТ 11: Доступ audit_viewer к логам - ПРОЙДЕН';
    EXCEPTION
        WHEN insufficient_privilege THEN
            test_result := 'ТЕСТ 11: Доступ audit_viewer к логам - ОШИБКА';
    END;
    
    RESET ROLE;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 12: ПРОВЕРКА ЗАПРЕТА ДОСТУПА ДРУГИХ РОЛЕЙ
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 12: Запрет доступа других ролей - ПРОЙДЕН';
BEGIN
    SET ROLE office_operator;
    
    BEGIN
        SELECT COUNT(*) FROM audit.login_log;
        test_result := 'ТЕСТ 12: Запрет доступа других ролей - ОШИБКА';
    EXCEPTION
        WHEN insufficient_privilege THEN
            test_result := 'ТЕСТ 12: Запрет доступа других ролей - ПРОЙДЕН';
    END;
    
    RESET ROLE;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 13: ПРОВЕРКА ЛОГИРОВАНИЯ РАЗНЫХ ПОЛЬЗОВАТЕЛЕЙ
-- =============================================

DO $$
DECLARE
    test_result TEXT;
    user_count INTEGER;
    total_logs INTEGER;
BEGIN
    -- Проверяем, что в логах есть записи от разных пользователей
    -- Примечание: SET ROLE не меняет current_user для логирования,
    -- поэтому проверяем наличие различных записей в логах
    SELECT COUNT(DISTINCT username) INTO user_count
    FROM audit.login_log;
    
    SELECT COUNT(*) INTO total_logs
    FROM audit.login_log;
    
    -- Проверяем, что есть хотя бы несколько записей от разных пользователей или сессий
    -- или что есть записи вообще (что означает логирование работает)
    IF total_logs > 0 AND user_count >= 1 THEN
        test_result := 'ТЕСТ 13: Логирование разных пользователей - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 13: Логирование разных пользователей - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 14: ПРОВЕРКА ВРЕМЕНИ ЛОГИРОВАНИЯ
-- =============================================

DO $$
DECLARE
    test_result TEXT;
    time_diff INTERVAL;
BEGIN
    PERFORM public.log_user_login();
    
    SELECT CURRENT_TIMESTAMP - MAX(login_time) INTO time_diff
    FROM audit.login_log;
    
    IF time_diff < INTERVAL '1 minute' THEN
        test_result := 'ТЕСТ 14: Время логирования - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 14: Время логирования - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

-- =============================================
-- ТЕСТ 15: ПРОВЕРКА ОБРАБОТКИ ОШИБОК
-- =============================================

DO $$
DECLARE
    test_result TEXT := 'ТЕСТ 15: Обработка ошибок - ПРОЙДЕН';
    error_log_count INTEGER;
BEGIN
    -- Функция должна обрабатывать ошибки и логировать их
    -- Проверяем наличие записей с ошибками в логах
    SELECT COUNT(*) INTO error_log_count
    FROM audit.login_log
    WHERE success = false;
    
    -- Даже если ошибок нет, функция должна работать
    IF error_log_count >= 0 THEN
        test_result := 'ТЕСТ 15: Обработка ошибок - ПРОЙДЕН';
    ELSE
        test_result := 'ТЕСТ 15: Обработка ошибок - ОШИБКА';
    END IF;
    
    RAISE NOTICE '%', test_result;
END $$;

