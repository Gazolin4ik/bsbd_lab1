-- Тесты чувствительных SECURITY DEFINER функций для ЛР2
-- Перед выполнением очищаем тестовые данные, чтобы избежать конфликтов по tracking_number

DELETE FROM app.shipments
WHERE tracking_number IN ('TRK_FUNC_CREATE_OK', 'TRK_FUNC_HEAVY');

-- =============================================
-- Функция: app.secure_create_shipment
-- =============================================

DO $$
DECLARE
    v_id INTEGER;
BEGIN
    SET SESSION AUTHORIZATION petr_smirnov;

    BEGIN
        v_id := app.secure_create_shipment('TRK_FUNC_CREATE_OK', 1, 2, 1, 2, 2, 1.1, 2000, 250);
        RAISE NOTICE 'Функция secure_create_shipment (валидный кейс) - ПРОЙДЕН (id=%)', v_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Функция secure_create_shipment (валидный кейс) - ОШИБКА (%).', SQLERRM;
    END;

    BEGIN
        PERFORM app.secure_create_shipment('TRK_FUNC_HEAVY', 1, 2, 1, 2, 1, 5.5, 2000, 250);
        RAISE NOTICE 'Функция secure_create_shipment (перегруз) - ОШИБКА (ожидали блокировку)';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%Вес%' THEN
                RAISE NOTICE 'Функция secure_create_shipment (перегруз) - ПРОЙДЕН';
            ELSE
                RAISE NOTICE 'Функция secure_create_shipment (перегруз) - ОШИБКА (%).', SQLERRM;
            END IF;
    END;

    RESET SESSION AUTHORIZATION;
END;
$$;

-- =============================================
-- Функция: app.secure_update_shipment_status
-- =============================================

DO $$
BEGIN
    SET SESSION AUTHORIZATION anna_ivanova;

    BEGIN
        PERFORM app.secure_update_shipment_status('TRK_FUNC_CREATE_OK', 'delivered', 'Тестовое завершение');
        RAISE NOTICE 'Функция secure_update_shipment_status (валидный кейс) - ПРОЙДЕН';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Функция secure_update_shipment_status (валидный кейс) - ОШИБКА (%).', SQLERRM;
    END;

    BEGIN
        PERFORM app.secure_update_shipment_status('TRK_FUNC_CREATE_OK', 'invalid_state', NULL);
        RAISE NOTICE 'Функция secure_update_shipment_status (невалидный статус) - ОШИБКА (ожидали отказ)';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%Недопустимый статус%' THEN
                RAISE NOTICE 'Функция secure_update_shipment_status (невалидный статус) - ПРОЙДЕН';
            ELSE
                RAISE NOTICE 'Функция secure_update_shipment_status (невалидный статус) - ОШИБКА (%).', SQLERRM;
            END IF;
    END;

    RESET SESSION AUTHORIZATION;
END;
$$;

-- =============================================
-- Функция: app.secure_adjust_declared_value
-- =============================================

DO $$
BEGIN
    SET SESSION AUTHORIZATION anna_ivanova;

    BEGIN
        PERFORM app.secure_adjust_declared_value('TRK_FUNC_CREATE_OK', 5000);
        RAISE NOTICE 'Функция secure_adjust_declared_value (валидный кейс) - ПРОЙДЕН';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Функция secure_adjust_declared_value (валидный кейс) - ОШИБКА (%).', SQLERRM;
    END;

    BEGIN
        PERFORM app.secure_adjust_declared_value('TRK_FUNC_CREATE_OK', 100);
        RAISE NOTICE 'Функция secure_adjust_declared_value (значение < price) - ОШИБКА (ожидали отказ)';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%не может быть меньше фактической стоимости%' THEN
                RAISE NOTICE 'Функция secure_adjust_declared_value (значение < price) - ПРОЙДЕН';
            ELSE
                RAISE NOTICE 'Функция secure_adjust_declared_value (значение < price) - ОШИБКА (%).', SQLERRM;
            END IF;
    END;

    RESET SESSION AUTHORIZATION;

    SET SESSION AUTHORIZATION petr_smirnov;

    BEGIN
        PERFORM app.secure_adjust_declared_value('TRK_FUNC_CREATE_OK', 7000);
        RAISE NOTICE 'Функция secure_adjust_declared_value (оператор) - ОШИБКА (операция разрешена)';
    EXCEPTION
        WHEN insufficient_privilege THEN
            RAISE NOTICE 'Функция secure_adjust_declared_value (оператор) - ПРОЙДЕН';
        WHEN OTHERS THEN
            RAISE NOTICE 'Функция secure_adjust_declared_value (оператор) - ОШИБКА (%).', SQLERRM;
    END;

    RESET SESSION AUTHORIZATION;
END;
$$;
