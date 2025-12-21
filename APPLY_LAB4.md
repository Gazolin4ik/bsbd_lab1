# Инструкция по применению лабораторной работы №4

## Быстрый старт

### 1. Применение миграции

```bash
# Применить миграцию ЛР4
docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /migrate_lab4.sql
```

### 2. Запуск тестов

```bash
# Запустить все тесты ЛР4
./run_tests.sh lab4

# Или напрямую через psql
docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /test_lab4.sql
```

### 3. Анализ производительности

```bash
# Запустить анализ производительности
docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /lab4_performance_analysis.sql
```

## Что было добавлено

### 1. Таблицы аудита
- `audit.row_change_log` - основная таблица для логов изменений
- `audit.row_change_log_archive` - архивная таблица для старых записей

### 2. Представления
- `app.shipments_public_view` - updatable VIEW с WITH CHECK OPTION (скрывает sender_id, recipient_id, declared_value)
- `app.shipments_statistics_view` - SECURITY BARRIER VIEW для агрегированной статистики

### 3. Триггеры аудита
- `trg_users_audit` - аудит изменений в app.users
- `trg_shipments_audit` - аудит изменений в app.shipments
- `trg_employees_audit` - аудит изменений в app.employees

### 4. Функции
- `audit.mask_sensitive_data()` - маскирование/хэширование чувствительных данных
- `audit.log_row_change()` - триггерная функция для логирования изменений
- `audit.backup_audit_logs(days_interval)` - архивация старых логов

## Примеры использования

### Просмотр аудита изменений

```sql
SELECT 
    change_time,
    table_name,
    record_id,
    operation,
    changed_by,
    old_data,
    new_data
FROM audit.row_change_log
ORDER BY change_time DESC
LIMIT 10;
```

### Архивация логов старше 90 дней

```sql
SELECT * FROM audit.backup_audit_logs(90);
```

### Работа с безопасным представлением

```sql
-- Обновление статуса через безопасное представление
UPDATE app.shipments_public_view
SET current_status = 'in_transit'
WHERE id = 1;
```

### Просмотр агрегированной статистики

```sql
SELECT 
    segment_id,
    current_status,
    shipment_count,
    total_weight,
    avg_price
FROM app.shipments_statistics_view
ORDER BY segment_id;
```

## Примечания

- Все чувствительные данные в логах аудита автоматически маскируются/хэшируются
- RLS политики продолжают работать для всех представлений
- SECURITY BARRIER VIEW предотвращает побочные каналы утечки данных
- WITH CHECK OPTION в представлении предотвращает обход ограничений

