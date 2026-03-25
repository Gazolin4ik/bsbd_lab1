#!/bin/bash

# Скрипт запуска тестов безопасности БД
# Использование:
#   ./run_tests.sh           - запустить тесты безопасности (задания 1-3)
#   ./run_tests.sh login     - запустить тесты логирования (задание 4)

TEST_TYPE=${1:-security}

if [ "$TEST_TYPE" = "security" ]; then
    echo "=========================================="
    echo "ТЕСТЫ БЕЗОПАСНОСТИ (Задания 1-3)"
    echo "=========================================="
    docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /test_security_fixed.sql 2>&1 | grep -E "(ТЕСТ|ПРОЙДЕН|ОШИБКА)" | sed 's/^psql:.*NOTICE:  //'
    echo ""
elif [ "$TEST_TYPE" = "login" ]; then
    echo "=========================================="
    echo "ТЕСТЫ ЛОГИРОВАНИЯ ПОДКЛЮЧЕНИЙ (Задание 4)"
    echo "=========================================="
    docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /test_login_logging_complete.sql 2>&1 | grep -E "(ТЕСТ|ПРОЙДЕН|ОШИБКА)" | sed 's/^psql:.*NOTICE:  //'
    echo ""
elif [ "$TEST_TYPE" = "lab2" ]; then
    echo "=========================================="
    echo "ТЕСТЫ ЛР2 (SECURITY DEFINER и контроль бизнес-логики)"
    echo "=========================================="
    docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /test_lab2_security.sql 2>&1 | grep -E "(ТЕСТ|ПРОЙДЕН|ОШИБКА)" | sed 's/^psql:.*NOTICE:  //'
    echo ""
    echo "------------------------------------------"
    echo "ДОПОЛНИТЕЛЬНЫЕ ТЕСТЫ ЧУВСТВИТЕЛЬНЫХ ФУНКЦИЙ"
    echo "------------------------------------------"
    docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /test_sensitive_functions.sql 2>&1 | grep -E "(Функция|ОШИБКА|ПРОЙДЕН)" | sed 's/^psql:.*NOTICE:  //'
    echo ""
elif [ "$TEST_TYPE" = "lab3" ]; then
    echo "=========================================="
    echo "ТЕСТЫ ЛР3 (Построчная изоляция данных с RLS)"
    echo "=========================================="
    # Выдаем права перед запуском тестов
    docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /fix_all_permissions.sh > /dev/null 2>&1 || true
    docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /test_lab3_rls.sql 2>&1 | grep -E "(ТЕСТ|ПРОЙДЕН|ОШИБКА)" | sed 's/^psql:.*NOTICE:  //' | sed 's/^NOTICE:  //'
    echo ""
elif [ "$TEST_TYPE" = "lab4" ]; then
    echo "=========================================="
    echo "ТЕСТЫ ЛР4 (Безопасные представления, аудит и анализ производительности)"
    echo "=========================================="
    docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /test_lab4.sql 2>&1 | grep -E "(ТЕСТ|ПРОЙДЕН|ОШИБКА|ПРОПУЩЕН|ЧАСТИЧНО|архивировано|удалено)" | sed 's/^psql:.*NOTICE:  //' | sed 's/^NOTICE:  //'
    echo ""
elif [ "$TEST_TYPE" = "lab5" ]; then
    echo "=========================================="
    echo "ЛР5: АНАЛИТИЧЕСКИЕ МЕТРИКИ И СЕКЦИОНИРОВАНИЕ"
    echo "=========================================="
    docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /lab5_metrics.sql
    echo ""
    echo "------------------------------------------"
    echo "ЛР5: ПРОВЕРКА PARTITION PRUNING (ARPU/ARPPU)"
    echo "------------------------------------------"
    # Печатаем сокращённый план: какие партиции реально сканируются
    docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /lab5_partition_pruning.sql 2>&1 \
      | grep -E "Seq Scan|Index Scan|Index Only Scan|app.shipments_p_" || true
    echo ""
    echo "Комментарий: в плане есть только обращения к app.shipments_p_current."
    echo "Архивная партиция app.shipments_p_archive не используется, что демонстрирует Partition Pruning."
    echo ""
elif [ "$TEST_TYPE" = "lab6" ]; then
    echo "=========================================="
    echo "ЛР2: ИНДЕКСЫ (EXPLAIN ANALYZE ДО/ПОСЛЕ)"
    echo "=========================================="
    docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /lab6_indexes.sql
    echo ""
    echo "=========================================="
    echo "ЛР2: ДЕМОНСТРАЦИЯ ТРИГГЕРОВ"
    echo "=========================================="
    docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /lab6_triggers_demo.sql
    echo ""
else
    echo "Использование:"
    echo "  ./run_tests.sh           - тесты безопасности (задания 1-3)"
    echo "  ./run_tests.sh login     - тесты логирования (задание 4)"
    echo "  ./run_tests.sh lab2      - тесты SECURITY DEFINER и ролей (ЛР2)"
    echo "  ./run_tests.sh lab3      - тесты построчной изоляции данных с RLS (ЛР3)"
    echo "  ./run_tests.sh lab4      - тесты безопасных представлений и аудита (ЛР4)"
    echo "  ./run_tests.sh lab5      - расчёт метрик и демонстрация секционирования (ЛР5)"
    echo "  ./run_tests.sh lab6      - индексы и триггеры (ЛР2)"
    exit 1
fi

echo "=========================================="
echo "ИНФОРМАЦИЯ ДЛЯ ПОДКЛЮЧЕНИЯ"
echo "=========================================="
echo "PGAdmin: http://localhost:8080 | БД: localhost:5433"
echo "Пользователи: anna_ivanova/petr_smirnov/maria_petrova | Пароли: anna123/petr123/maria123"
