## task2_basebackup.sh

```sh
docker exec -u postgres bsbd_lab4_pitr_db rm -rf /tmp/pg_backup/base
docker exec -u postgres bsbd_lab4_pitr_db mkdir -p /tmp/pg_backup/base
docker exec -u postgres bsbd_lab4_pitr_db pg_basebackup -U postgres -D /tmp/pg_backup/base -Fp -Xs -P --checkpoint=fast
```

## task2_flow.sql

```sql
DROP TABLE IF EXISTS app.important_data;
CREATE TABLE app.important_data (
    id SERIAL PRIMARY KEY,
    note TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO app.important_data (note) VALUES ('Данные до аварии');
SELECT now() AS target_time;
TRUNCATE app.important_data;
INSERT INTO app.important_data (note) VALUES ('Данные после аварии');
SELECT pg_switch_wal();
CHECKPOINT;
SELECT * FROM app.important_data ORDER BY id;
```

## checks_task2.sh

```sh
docker exec bsbd_lab4_pitr_db sh -c "ls -la /tmp/pg_backup/base | sed -n '1,40p'"
docker exec bsbd_lab4_pitr_db sh -c "ls -1 /var/lib/postgresql/archive/*.gz.enc 2>/dev/null | wc -l"
```
