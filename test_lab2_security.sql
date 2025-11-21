-- Тесты для лабораторной работы №2 (точечное повышение привилегий)
-- Скрипт покрывает 9 кейсов (позитивные и негативные сценарии)

-- =============================================
-- ТЕСТ 1: Оператор видит разрешённые таблицы (SELECT)
-- =============================================
SET SESSION AUTHORIZATION petr_smirnov;
DO $$
DECLARE
    v_cnt INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_cnt FROM app.offices;
    IF v_cnt >= 0 THEN
        RAISE NOTICE 'ТЕСТ 1: Чтение app.offices оператором - ПРОЙДЕН';
    ELSE
        RAISE NOTICE 'ТЕСТ 1: Чтение app.offices оператором - ОШИБКА';
    END IF;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 2: Оператор не может напрямую вставлять данные в app.shipments
-- =============================================
SET SESSION AUTHORIZATION petr_smirnov;
DO $$
BEGIN
    BEGIN
        INSERT INTO app.shipments (tracking_number, from_office_id, to_office_id, sender_id, recipient_id, shipment_type_id, weight, price)
        VALUES ('TRK_LAB2_DENY', 1, 2, 1, 2, 1, 0.05, 100);
        RAISE NOTICE 'ТЕСТ 2: Прямая вставка - ОШИБКА (операция прошла)';
    EXCEPTION
        WHEN insufficient_privilege THEN
            RAISE NOTICE 'ТЕСТ 2: Прямая вставка запрещена - ПРОЙДЕН';
        WHEN OTHERS THEN
            RAISE NOTICE 'ТЕСТ 2: Прямая вставка - ОШИБКА (%).', SQLERRM;
    END;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 3: Оператор использует SECURITY DEFINER функцию для создания отправления
-- =============================================
SET SESSION AUTHORIZATION petr_smirnov;
DO $$
DECLARE
    v_id INTEGER;
BEGIN
    v_id := app.secure_create_shipment('TRK_LAB2_OK', 1, 2, 1, 2, 2, 1.5, 2000, 250);
    IF v_id IS NOT NULL THEN
        RAISE NOTICE 'ТЕСТ 3: secure_create_shipment для оператора - ПРОЙДЕН (id=%)', v_id;
    ELSE
        RAISE NOTICE 'ТЕСТ 3: secure_create_shipment для оператора - ОШИБКА (нет id)';
    END IF;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 4: Контроль бизнес-правила (перегруз) через функцию
-- =============================================
SET SESSION AUTHORIZATION petr_smirnov;
DO $$
BEGIN
    BEGIN
        PERFORM app.secure_create_shipment('TRK_LAB2_HEAVY', 1, 2, 1, 2, 1, 5, 2000, 250);
        RAISE NOTICE 'ТЕСТ 4: Контроль веса - ОШИБКА (ожидали исключение)';
    EXCEPTION
        WHEN others THEN
            IF SQLERRM LIKE '%Вес%' THEN
                RAISE NOTICE 'ТЕСТ 4: Контроль веса - ПРОЙДЕН';
            ELSE
                RAISE NOTICE 'ТЕСТ 4: Контроль веса - ОШИБКА (%).', SQLERRM;
            END IF;
    END;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 5: Оператор не может корректировать объявленную стоимость
-- =============================================
SET SESSION AUTHORIZATION petr_smirnov;
DO $$
BEGIN
    BEGIN
        PERFORM app.secure_adjust_declared_value('TRK001', 9999);
        RAISE NOTICE 'ТЕСТ 5: Запрещённый вызов secure_adjust_declared_value - ОШИБКА';
    EXCEPTION
        WHEN insufficient_privilege THEN
            RAISE NOTICE 'ТЕСТ 5: Запрещённый вызов secure_adjust_declared_value - ПРОЙДЕН';
        WHEN OTHERS THEN
            RAISE NOTICE 'ТЕСТ 5: secure_adjust_declared_value - ОШИБКА (%).', SQLERRM;
    END;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 6: Менеджер обновляет статус через SECURITY DEFINER функцию
-- =============================================
SET SESSION AUTHORIZATION anna_ivanova;
DO $$
BEGIN
    BEGIN
        PERFORM app.secure_update_shipment_status('TRK_LAB2_OK', 'in_transit', 'Передано курьеру');
        RAISE NOTICE 'ТЕСТ 6: secure_update_shipment_status менеджером - ПРОЙДЕН';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ТЕСТ 6: secure_update_shipment_status менеджером - ОШИБКА (%).', SQLERRM;
    END;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 7: Оператор не может выполнять DDL
-- =============================================
SET SESSION AUTHORIZATION petr_smirnov;
DO $$
BEGIN
    BEGIN
        EXECUTE 'CREATE TABLE app.ddl_forbidden(id INT)';
        RAISE NOTICE 'ТЕСТ 7: DDL оператором - ОШИБКА (операция разрешена)';
    EXCEPTION
        WHEN insufficient_privilege THEN
            RAISE NOTICE 'ТЕСТ 7: DDL оператором - ПРОЙДЕН';
        WHEN OTHERS THEN
            RAISE NOTICE 'ТЕСТ 7: DDL оператором - ОШИБКА (%).', SQLERRM;
    END;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 8: Запрет DML в audit-схеме для оператора
-- =============================================
SET SESSION AUTHORIZATION petr_smirnov;
DO $$
BEGIN
    BEGIN
        INSERT INTO audit.function_calls (function_name, caller_role, input_params, success)
        VALUES ('test', 'office_operator', '{}'::jsonb, true);
        RAISE NOTICE 'ТЕСТ 8: DML в audit оператором - ОШИБКА';
    EXCEPTION
        WHEN insufficient_privilege THEN
            RAISE NOTICE 'ТЕСТ 8: DML в audit оператором - ПРОЙДЕН';
        WHEN OTHERS THEN
            RAISE NOTICE 'ТЕСТ 8: DML в audit оператором - ОШИБКА (%).', SQLERRM;
    END;
END;
$$;
RESET SESSION AUTHORIZATION;

-- =============================================
-- ТЕСТ 9: Журнал вызовов содержит записи после операций
-- =============================================
DO $$
DECLARE
    v_cnt INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_cnt FROM audit.function_calls WHERE function_name LIKE 'app.secure%';
    IF v_cnt > 0 THEN
        RAISE NOTICE 'ТЕСТ 9: Журнал вызовов SECURITY DEFINER функций - ПРОЙДЕН (кол-во=%)', v_cnt;
    ELSE
        RAISE NOTICE 'ТЕСТ 9: Журнал вызовов SECURITY DEFINER функций - ОШИБКА';
    END IF;
END;
$$;

