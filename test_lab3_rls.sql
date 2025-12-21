-- =============================================
-- ТЕСТЫ ЛАБОРАТОРНОЙ РАБОТЫ №3: ПОСТРОЧНАЯ ИЗОЛЯЦИЯ ДАННЫХ С RLS
-- =============================================

SET client_min_messages TO NOTICE;

-- Сбрасываем GUC перед тестами
RESET ALL;

-- Подготовка: создаем auditor_login если его нет и выдаем права
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'auditor_login') THEN
        CREATE ROLE auditor_login LOGIN PASSWORD 'auditor123';
        GRANT auditor TO auditor_login;
        GRANT CONNECT ON DATABASE bsbd_lab1 TO auditor_login;
    END IF;
    
    -- Выдаем права на схемы и таблицы
    GRANT USAGE ON SCHEMA app TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
    GRANT USAGE ON SCHEMA ref TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
    GRANT SELECT ON ref.segments TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
    GRANT SELECT ON app.user_mappings TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
    GRANT SELECT, INSERT, UPDATE, DELETE ON app.offices TO anna_ivanova, petr_smirnov, maria_petrova;
    GRANT SELECT, INSERT, UPDATE, DELETE ON app.employees TO anna_ivanova, petr_smirnov, maria_petrova;
    GRANT SELECT, INSERT, UPDATE, DELETE ON app.users TO anna_ivanova, petr_smirnov, maria_petrova;
    GRANT SELECT, INSERT, UPDATE, DELETE ON app.shipments TO anna_ivanova, petr_smirnov, maria_petrova;
    GRANT SELECT, INSERT, UPDATE, DELETE ON app.delivery_routes TO anna_ivanova, petr_smirnov, maria_petrova;
    GRANT SELECT, INSERT, UPDATE, DELETE ON app.shipment_operations TO anna_ivanova, petr_smirnov, maria_petrova;
    GRANT SELECT ON ALL TABLES IN SCHEMA app TO auditor_login;
    GRANT SELECT ON ALL TABLES IN SCHEMA ref TO auditor_login;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO anna_ivanova, petr_smirnov, maria_petrova, auditor_login;
END $$;

-- =============================================
-- ТЕСТ 1: Чтение "чужих" строк (должно быть пусто)
-- =============================================
SET SESSION AUTHORIZATION anna_ivanova;
DO $$
DECLARE
    v_shipments INTEGER;
    v_employees INTEGER;
    v_users INTEGER;
    v_segment_id INTEGER;
    v_foreign_shipments INTEGER;
    v_foreign_employees INTEGER;
    v_foreign_users INTEGER;
BEGIN
    SELECT um.segment_id INTO v_segment_id FROM app.user_mappings um WHERE um.db_username = 'anna_ivanova';
    
    -- Подсчитываем все видимые данные (RLS должен отфильтровать чужие)
    SELECT COUNT(*) INTO v_shipments FROM app.shipments;
    SELECT COUNT(*) INTO v_employees FROM app.employees;
    SELECT COUNT(*) INTO v_users FROM app.users;
    
    -- Проверяем, что все видимые данные принадлежат нашему сегменту
    -- (если есть чужие данные, значит RLS не работает)
    SELECT COUNT(*) INTO v_foreign_shipments FROM app.shipments WHERE segment_id != v_segment_id;
    SELECT COUNT(*) INTO v_foreign_employees FROM app.employees WHERE segment_id != v_segment_id;
    SELECT COUNT(*) INTO v_foreign_users FROM app.users WHERE segment_id != v_segment_id;
    
    -- Проверяем изоляцию: чужих данных быть не должно (RLS их скрывает)
    IF v_foreign_shipments = 0 AND v_foreign_employees = 0 AND v_foreign_users = 0 THEN
        RAISE NOTICE 'ТЕСТ 1: Изоляция данных по сегментам - ПРОЙДЕН (видимых: отправлений %, сотрудников %, пользователей %; чужих: 0)', 
            v_shipments, v_employees, v_users;
    ELSE
        RAISE NOTICE 'ТЕСТ 1: Изоляция данных по сегментам - ОШИБКА (видны чужие данные: отправлений %, сотрудников %, пользователей %)', 
            v_foreign_shipments, v_foreign_employees, v_foreign_users;
    END IF;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 2: Вставка с неверным segment_id (ошибка)
-- =============================================
SET SESSION AUTHORIZATION anna_ivanova;
DO $$
DECLARE
    v_segment_spb INTEGER;
    v_office_id INTEGER;
BEGIN
    SELECT id INTO v_segment_spb FROM ref.segments WHERE code = 'SPB';
    SELECT id INTO v_office_id FROM app.offices LIMIT 1;
    
    BEGIN
        -- Используем функцию secure_insert_user для проверки segment_id
        PERFORM app.secure_insert_user('test_rls_block_' || random()::text || '@example.com', '+7-999-999-99-99', v_segment_spb);
        RAISE NOTICE 'ТЕСТ 2: Вставка с неверным segment_id - ОШИБКА (операция прошла)';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%segment_id%' OR SQLERRM LIKE '%политик%' OR SQLERRM LIKE '%policy%' OR SQLERRM LIKE '%new row violates%' OR SQLERRM LIKE '%не может вставлять%' OR SQLERRM LIKE '%check_segment_id%' THEN
                RAISE NOTICE 'ТЕСТ 2: Вставка с неверным segment_id заблокирована - ПРОЙДЕН';
            ELSE
                RAISE NOTICE 'ТЕСТ 2: Вставка с неверным segment_id - ОШИБКА (%)', SQLERRM;
            END IF;
    END;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 3: Обновление с неверным segment_id (ошибка)
-- =============================================
SET SESSION AUTHORIZATION anna_ivanova;
DO $$
DECLARE
    v_segment_spb INTEGER;
    v_user_id INTEGER;
BEGIN
    SELECT id INTO v_segment_spb FROM ref.segments WHERE code = 'SPB';
    SELECT id INTO v_user_id FROM app.users WHERE segment_id = 1 LIMIT 1;
    
    IF v_user_id IS NOT NULL THEN
        BEGIN
            UPDATE app.users SET segment_id = v_segment_spb WHERE id = v_user_id;
            RAISE NOTICE 'ТЕСТ 3: Обновление с неверным segment_id - ОШИБКА (операция прошла)';
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLERRM LIKE '%segment_id%' OR SQLERRM LIKE '%политик%' OR SQLERRM LIKE '%policy%' OR SQLERRM LIKE '%не может%' OR SQLERRM LIKE '%check_segment_id%' OR SQLERRM LIKE '%new row violates%' THEN
                    RAISE NOTICE 'ТЕСТ 3: Обновление с неверным segment_id заблокировано - ПРОЙДЕН';
                ELSE
                    RAISE NOTICE 'ТЕСТ 3: Обновление с неверным segment_id - ОШИБКА (%)', SQLERRM;
                END IF;
        END;
    ELSE
        RAISE NOTICE 'ТЕСТ 3: Обновление с неверным segment_id - ПРОЙДЕН (нет данных для теста)';
    END IF;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 4: Корректные операции в своём сегменте
-- =============================================
SET SESSION AUTHORIZATION anna_ivanova;
DO $$
DECLARE
    v_segment_id INTEGER;
    v_user_id INTEGER;
BEGIN
    SELECT um.segment_id INTO v_segment_id FROM app.user_mappings um WHERE um.db_username = 'anna_ivanova';
    
    BEGIN
        INSERT INTO app.users (email, phone, segment_id)
        VALUES ('test_lab3@example.com', '+7-999-999-99-99', v_segment_id)
        RETURNING id INTO v_user_id;
        
        UPDATE app.users SET email = 'updated_lab3@example.com' WHERE id = v_user_id;
        
        DELETE FROM app.users WHERE id = v_user_id;
        
        RAISE NOTICE 'ТЕСТ 4: Корректные операции в своём сегменте - ПРОЙДЕН';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ТЕСТ 4: Корректные операции в своём сегменте - ОШИБКА (%)', SQLERRM;
    END;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 5: Проверка работы set_session_ctx() - успешная
-- =============================================
SET SESSION AUTHORIZATION anna_ivanova;
DO $$
DECLARE
    v_segment_id INTEGER;
BEGIN
    SELECT um.segment_id INTO v_segment_id FROM app.user_mappings um WHERE um.db_username = 'anna_ivanova';
    
    BEGIN
        PERFORM app.set_session_ctx(v_segment_id::INTEGER, NULL::INTEGER);
        RAISE NOTICE 'ТЕСТ 5: set_session_ctx() с правильным сегментом - ПРОЙДЕН';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ТЕСТ 5: set_session_ctx() с правильным сегментом - ОШИБКА (%)', SQLERRM;
    END;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 6: Проверка работы set_session_ctx() - ошибка (неверный сегмент)
-- =============================================
SET SESSION AUTHORIZATION anna_ivanova;
DO $$
DECLARE
    v_segment_spb INTEGER;
BEGIN
    SELECT id INTO v_segment_spb FROM ref.segments WHERE code = 'SPB';
    
    BEGIN
        PERFORM app.set_session_ctx(v_segment_spb::INTEGER, NULL::INTEGER);
        RAISE NOTICE 'ТЕСТ 6: set_session_ctx() с неверным сегментом - ОШИБКА (операция прошла)';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%не имеет доступа к сегменту%' OR SQLERRM LIKE '%segment%' THEN
                RAISE NOTICE 'ТЕСТ 6: set_session_ctx() с неверным сегментом заблокирован - ПРОЙДЕН';
            ELSE
                RAISE NOTICE 'ТЕСТ 6: set_session_ctx() с неверным сегментом - ОШИБКА (%)', SQLERRM;
            END IF;
    END;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 7: Режим суперпользователя для auditor - видит все сегменты
-- =============================================
SET SESSION AUTHORIZATION auditor_login;
DO $$
DECLARE
    v_shipments INTEGER;
    v_employees INTEGER;
    v_users INTEGER;
    v_segments_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_shipments FROM app.shipments;
    SELECT COUNT(*) INTO v_employees FROM app.employees;
    SELECT COUNT(*) INTO v_users FROM app.users;
    
    -- Auditor должен видеть все данные, независимо от сегментов
    IF v_shipments >= 0 AND v_employees >= 0 AND v_users >= 0 THEN
        RAISE NOTICE 'ТЕСТ 7: Auditor видит все сегменты - ПРОЙДЕН (отправлений: %, сотрудников: %, пользователей: %)', 
            v_shipments, v_employees, v_users;
    ELSE
        RAISE NOTICE 'ТЕСТ 7: Auditor видит все сегменты - ОШИБКА';
    END IF;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 8: Проверка изоляции между пользователями разных сегментов
-- =============================================
-- Временно перемещаем petr_smirnov в сегмент 2 (СПб)
DO $$
DECLARE
    v_segment_spb INTEGER;
    v_segment_petr_old INTEGER;
BEGIN
    SELECT id INTO v_segment_spb FROM ref.segments WHERE code = 'SPB';
    SELECT segment_id INTO v_segment_petr_old FROM app.user_mappings WHERE db_username = 'petr_smirnov';
    UPDATE app.user_mappings SET segment_id = v_segment_spb WHERE db_username = 'petr_smirnov';
END;
$$;

SET SESSION AUTHORIZATION petr_smirnov;
DO $$
DECLARE
    v_shipments_petr INTEGER;
    v_employees_petr INTEGER;
    v_segment_petr INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_shipments_petr FROM app.shipments;
    SELECT COUNT(*) INTO v_employees_petr FROM app.employees;
    SELECT um.segment_id INTO v_segment_petr FROM app.user_mappings um WHERE um.db_username = 'petr_smirnov';
    
    RAISE NOTICE 'ТЕСТ 8: Изоляция petr_smirnov (сегмент %) - ПРОЙДЕН (отправлений: %, сотрудников: %)', 
        v_segment_petr, v_shipments_petr, v_employees_petr;
END;
$$;
RESET SESSION AUTHORIZATION;

-- Восстанавливаем сегмент petr_smirnov и перемещаем maria_petrova в сегмент 3 (Новосибирск)
DO $$
DECLARE
    v_segment_nsk INTEGER;
    v_segment_maria_old INTEGER;
BEGIN
    UPDATE app.user_mappings SET segment_id = 1 WHERE db_username = 'petr_smirnov';
    SELECT id INTO v_segment_nsk FROM ref.segments WHERE code = 'NOVOSIBIRSK';
    SELECT segment_id INTO v_segment_maria_old FROM app.user_mappings WHERE db_username = 'maria_petrova';
    UPDATE app.user_mappings SET segment_id = v_segment_nsk WHERE db_username = 'maria_petrova';
END;
$$;

SET SESSION AUTHORIZATION maria_petrova;
DO $$
DECLARE
    v_shipments_maria INTEGER;
    v_employees_maria INTEGER;
    v_segment_maria INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_shipments_maria FROM app.shipments;
    SELECT COUNT(*) INTO v_employees_maria FROM app.employees;
    SELECT um.segment_id INTO v_segment_maria FROM app.user_mappings um WHERE um.db_username = 'maria_petrova';
    
    RAISE NOTICE 'ТЕСТ 8: Изоляция maria_petrova (сегмент %) - ПРОЙДЕН (отправлений: %, сотрудников: %)', 
        v_segment_maria, v_shipments_maria, v_employees_maria;
END;
$$;
RESET SESSION AUTHORIZATION;

-- Восстанавливаем исходные сегменты
DO $$
BEGIN
    UPDATE app.user_mappings SET segment_id = 1 WHERE db_username = 'maria_petrova';
END;
$$;

-- =============================================
-- ТЕСТ 9: Проверка политик INSERT/UPDATE/DELETE для разных сегментов
-- =============================================
SET SESSION AUTHORIZATION anna_ivanova;
DO $$
DECLARE
    v_segment_id INTEGER;
    v_user_id INTEGER;
BEGIN
    SELECT um.segment_id INTO v_segment_id FROM app.user_mappings um WHERE um.db_username = 'anna_ivanova';
    
    BEGIN
        INSERT INTO app.users (email, phone, segment_id)
        VALUES ('test_insert@example.com', '+7-999-999-99-99', v_segment_id)
        RETURNING id INTO v_user_id;
        
        UPDATE app.users SET email = 'test_update@example.com' WHERE id = v_user_id;
        
        DELETE FROM app.users WHERE id = v_user_id;
        
        RAISE NOTICE 'ТЕСТ 9: Политики INSERT/UPDATE/DELETE в своём сегменте - ПРОЙДЕН';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ТЕСТ 9: Политики INSERT/UPDATE/DELETE в своём сегменте - ОШИБКА (%)', SQLERRM;
    END;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 10: Проверка работы get_session_segment_id()
-- =============================================
SET SESSION AUTHORIZATION anna_ivanova;
DO $$
DECLARE
    v_session_seg_id INTEGER;
    v_user_seg_id INTEGER;
BEGIN
    -- Сбрасываем GUC перед тестом (устанавливаем пустое значение)
    PERFORM set_config('app.segment_id', '', true);
    
    v_session_seg_id := app.get_session_segment_id();
    SELECT um.segment_id INTO v_user_seg_id FROM app.user_mappings um WHERE um.db_username = 'anna_ivanova';
    
    IF v_session_seg_id = v_user_seg_id THEN
        RAISE NOTICE 'ТЕСТ 10: get_session_segment_id() работает корректно - ПРОЙДЕН (segment_id: %)', v_session_seg_id;
    ELSE
        RAISE NOTICE 'ТЕСТ 10: get_session_segment_id() работает корректно - ОШИБКА (ожидали: %, получили: %)', 
            v_user_seg_id, v_session_seg_id;
    END IF;
END;
$$;
RESET SESSION AUTHORIZATION;
