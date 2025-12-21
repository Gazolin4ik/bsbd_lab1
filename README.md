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

## Лабораторная работа №4

Полный отчёт: `LAB4_REPORT.md`.

### Новые цели
- безопасные представления (updatable VIEW с WITH CHECK OPTION, SECURITY BARRIER VIEW)
- аудит изменений с маскированием чувствительных данных
- тесты доступов (4 кейса)
- анализ производительности RLS
- автоматическое резервное копирование audit-логов

### Безопасные представления

#### Updatable VIEW с WITH CHECK OPTION
- `app.shipments_public_view` — представление для работы с неконфиденциальными полями отправлений
- Скрывает чувствительные поля: `sender_id`, `recipient_id`, `declared_value`
- WITH CHECK OPTION предотвращает обход ограничений через изменение скрытых полей
- Использует INSTEAD OF триггер для контроля обновлений

#### SECURITY BARRIER VIEW для агрегатов
- `app.shipments_statistics_view` — агрегированная статистика по отправлениям
- Защищает от побочных каналов через HAVING/подзапросы
- Возвращает только агрегированные данные (COUNT, SUM, AVG)

### Аудит изменений

#### Таблица `audit.row_change_log`
- Логирует все UPDATE/DELETE операции на критичных таблицах (users, shipments, employees)
- Фиксирует: кто (changed_by), что (table_name, record_id), когда (change_time), old/new данные
- Чувствительные поля маскируются/хэшируются:
  - **users**: email → `***@domain`, phone → `HASH:md5`, passport_data → `HASH:md5`
  - **shipments**: declared_value → `>1M` / `>100K` / `>10K` / `>1K`
  - **employees**: first_name/last_name → `A***`

#### Триггеры аудита
- `trg_users_audit` — аудит изменений пользователей
- `trg_shipments_audit` — аудит изменений отправлений
- `trg_employees_audit` — аудит изменений сотрудников

### Автоматическое резервное копирование

#### Функция `audit.backup_audit_logs(days_interval INT)`
- Переносит записи старше указанного количества дней из `audit.row_change_log` в `audit.row_change_log_archive`
- Удаляет перенесенные записи из основной таблицы
- Возвращает количество архивированных и удаленных записей

Пример использования:
```sql
SELECT * FROM audit.backup_audit_logs(90); -- Архивация записей старше 90 дней
```

### Тесты доступов (4 кейса)

1. **Попытка обхода WITH CHECK OPTION** — должна блокироваться
2. **Попытка получения деталей через SECURITY BARRIER VIEW** — должна возвращать только агрегаты
3. **Изменение строки** — проверка появления записи в `row_change_log`
4. **Попытка удаления строки не из своего сегмента** — ошибка RLS

Запуск: `./run_tests.sh lab4`

### Анализ производительности

Скрипт `lab4_performance_analysis.sql` выполняет:
- `EXPLAIN (ANALYZE, BUFFERS)` для типовых запросов
- Подбор индексов под условия политик RLS
- Сравнение производительности до/после RLS
- Анализ использования индексов через `pg_stat_user_indexes`

Рекомендуемые индексы:
- `idx_shipments_segment_status_created` — для фильтрации по segment_id и current_status
- Индексы на `segment_id` уже существуют для всех таблиц с RLS

Запуск:
```bash
docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /lab4_performance_analysis.sql
```

## Остановка системы

```bash
docker compose down
```

## Удаление данных

```bash
docker compose down -v
```
