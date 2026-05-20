## lab4_sem6_restore_wal.sh

```sh
WAL_FILE="$1"
DEST_PATH="$2"
ARCHIVE_DIR="/var/lib/postgresql/archive"
PASS_FILE="/etc/postgresql/lab4_sem6_wal_pass.txt"

if [ ! -f "${ARCHIVE_DIR}/${WAL_FILE}.gz.enc" ]; then
  exit 1
fi

openssl enc -d -aes-256-cbc -pass "file:${PASS_FILE}" -in "${ARCHIVE_DIR}/${WAL_FILE}.gz.enc" | gunzip -c > "${DEST_PATH}"
exit $?
```

## lab4_sem6_prepare_recovery.sh

```sh
TARGET_TIME="$1"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/pg_backup/base}"
BROKEN="${PGDATA}_broken"

rm -rf "$BROKEN"
mkdir -p "$BROKEN"
cp -a "$PGDATA"/. "$BROKEN"/
find "$PGDATA" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "$BACKUP_DIR"/. "$PGDATA"/
chown -R postgres:postgres "$PGDATA" "$BROKEN"

cat > "$PGDATA/postgresql.auto.conf" <<EOF
restore_command = '/usr/local/bin/lab4_sem6_restore_wal.sh %f %p'
recovery_target_time = '$TARGET_TIME'
recovery_target_action = 'promote'
EOF
chown postgres:postgres "$PGDATA/postgresql.auto.conf"
chmod 600 "$PGDATA/postgresql.auto.conf"
touch "$PGDATA/recovery.signal"
chown postgres:postgres "$PGDATA/recovery.signal"
```

## checks_task3.sh

```sh
docker compose stop postgres_lab4
docker compose run --rm --no-deps -u root --entrypoint "" postgres_lab4 /usr/local/bin/lab4_sem6_prepare_recovery.sh '2026-05-20 00:00:00+00'
docker compose up -d postgres_lab4
docker exec bsbd_lab4_pitr_db pg_isready -U postgres
docker exec bsbd_lab4_pitr_db sh -c "cat /var/lib/postgresql/data/postgresql.auto.conf"
docker exec bsbd_lab4_pitr_db sh -c "ls -la /var/lib/postgresql/data/recovery.signal"
docker exec bsbd_lab4_pitr_db sh -c "tail -80 /var/lib/postgresql/data/log/postgresql-*.log 2>/dev/null || true"
```

## checks_task3.sql

```sql
SELECT pg_is_in_recovery();
SELECT * FROM app.important_data ORDER BY id;
SELECT COUNT(*) FILTER (WHERE note = 'Данные до аварии') AS before_incident, COUNT(*) FILTER (WHERE note = 'Данные после аварии') AS after_incident FROM app.important_data;
SHOW restore_command;
```
