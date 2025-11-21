# База данных почтовых отделений

База данных для управления почтовыми отделениями с защитой персональных данных отправителей и получателей.

## Быстрый старт

### 1. Запуск системы
```bash
docker compose up -d
```

### 2. Запуск тестов
```bash
# Тесты безопасности 
./run_tests.sh 

# Тесты логирования подключений 
./run_tests.sh login

# Тесты ЛР2 (SECURITY DEFINER + контроль бизнес-логики)
./run_tests.sh lab2
```

### 3. Доступ к системе
- **pgAdmin**: http://localhost:8080
  - Email: admin@example.com
  - Пароль: 123

## Структура проекта

- `docker-compose.yml` - конфигурация Docker (PostgreSQL + pgAdmin)
- `init.sql` - инициализация базы данных (схемы, таблицы, роли, права)
- `test_security_complete.sql` - тесты безопасности 
- `test_login_logging_complete.sql` - тесты логирования подключений 
- `run_tests.sh` - скрипт запуска тестов

## Архитектура

### Схемы
- `app` - основные таблицы (отделения, пользователи, сотрудники, отправления)
- `ref` - справочники (типы отделений, должности, типы отправлений)
- `audit` - аудит и логирование (логи подключений, изменения данных)
- `stg` - промежуточные данные

### Роли
- `office_manager` - менеджер отделения (чтение/запись)
- `office_operator` - оператор (только чтение)
- `audit_viewer` - просмотр аудита
- `app_reader`, `app_writer`, `auditor` - групповые роли
- `ddl_admin`, `dml_admin`, `security_admin` - административные роли

### Безопасность
- Row Level Security (RLS) для ограничения доступа по отделениям
- SECURITY DEFINER функции для безопасного логирования
- Аудит подключений пользователей
- Классификация данных по уровням (PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED)
- Отзыв прав PUBLIC

## Лабораторная работа №2

Полный отчёт: `LAB2_REPORT.md`.

### Новые цели
- точечное повышение привилегий через SECURITY DEFINER функции
- журнал вызовов чувствительных операций
- сравнение CHECK и триггера для сложного бизнес-правила
- расширенные тесты прав и сценариев злоупотреблений

### SECURITY DEFINER функции
- `app.secure_create_shipment(...)` — создаёт отправление без прямого доступа к таблице, проверяет вес/стоимость и пишет в `audit.function_calls`
- `app.secure_update_shipment_status(...)` — обновляет статус из белого списка, логируется
- `app.secure_adjust_declared_value(...)` — корректирует объявленную стоимость только для менеджеров

Доступ к функциям выдаётся через `GRANT EXECUTE`, а не прямые DML-правa.

### Контроль бизнес-логики
- CHECK `chk_shipments_declared_vs_price` гарантирует, что объявленная стоимость >= стоимости услуги
- Триггер `trg_shipments_weight_limit` сверяет вес с `ref.shipment_types.max_weight` (нельзя выразить через CHECK)
- Скрипт `lab2_rule_benchmark.sql` воспроизводит вставку 10,000 строк для сравнения производительности CHECK vs Trigger

### Журнал вызовов
- `audit.function_calls` + процедура `audit.log_function_call` фиксируют все вызовы SECURITY DEFINER функций (название, роль, входные параметры, успех/ошибка)
- Пример запроса:
  ```sql
  SELECT function_name, caller_role, call_time, success
  FROM audit.function_calls
  ORDER BY call_time DESC
  LIMIT 10;
  ```

### Тесты ЛР2
Скрипты `test_lab2_security.sql` и `test_sensitive_functions.sql` покрывают 9+ сценариев:
- чтение разрешённых таблиц
- запрет прямых INSERT/DDL/DML в audit
- вызовы SECURITY DEFINER с валидными/невалидными данными
- проверка аудита вызовов

Запуск: `./run_tests.sh lab2`

### Сценарий сравнения CHECK vs Trigger
```bash
docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /lab2_rule_benchmark.sql
```
Вывод содержит длительность вставок для обеих стратегий и количество загруженных строк. По итогам выбрана связка CHECK+Trigger: CHECK для простых внутритабличных правил, триггер для кросс-табличной проверки веса.

## Остановка системы

```bash
docker compose down
```

## Удаление данных

```bash
docker compose down -v
```
