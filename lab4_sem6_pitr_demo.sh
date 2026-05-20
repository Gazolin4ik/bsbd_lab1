#!/bin/bash
# LAB4_SEM6: automated PITR demo (Tasks 1-3)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CONTAINER="${LAB4_CONTAINER:-bsbd_lab4_pitr_db}"
SERVICE="${LAB4_SERVICE:-postgres_lab4}"
DB="${LAB4_DB:-bsbd_lab1}"
PGUSER="${LAB4_USER:-postgres}"
BACKUP_DIR="/tmp/pg_backup/base"
PGDATA="/var/lib/postgresql/data"
TARGET_FILE="/tmp/pg_backup/lab4_sem6_recovery_target.txt"
WAIT_SEC="${LAB4_WAIT_SEC:-75}"

psql_cmd() {
  docker exec -u postgres "$CONTAINER" psql -U "$PGUSER" -d "$DB" -v ON_ERROR_STOP=1 "$@"
}

wait_ready() {
  for _ in $(seq 1 90); do
    if docker exec "$CONTAINER" pg_isready -U "$PGUSER" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "PostgreSQL not ready in $CONTAINER"
  exit 1
}

echo "=== LAB4_SEM6 Task 1: checksums, WAL, archive ==="
wait_ready
psql_cmd -c "SHOW data_checksums;"
psql_cmd -c "SHOW wal_level;"
psql_cmd -c "SHOW archive_mode;"
psql_cmd -c "SHOW archive_command;"

ARCHIVE_COUNT=$(docker exec "$CONTAINER" sh -c 'ls -1 /var/lib/postgresql/archive/*.gz.enc 2>/dev/null | wc -l' || true)
echo "Encrypted WAL archives present: ${ARCHIVE_COUNT}"

echo ""
echo "=== LAB4_SEM6 Task 2: base backup + incident ==="
docker exec -u postgres "$CONTAINER" rm -rf /tmp/pg_backup/base
docker exec -u postgres "$CONTAINER" mkdir -p /tmp/pg_backup/base
docker exec -u postgres "$CONTAINER" pg_basebackup -U "$PGUSER" -D "$BACKUP_DIR" -Fp -Xs -P --checkpoint=fast

psql_cmd -c "DROP TABLE IF EXISTS app.important_data;"
psql_cmd -c "CREATE TABLE app.important_data (id SERIAL PRIMARY KEY, note TEXT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP);"
psql_cmd -c "INSERT INTO app.important_data (note) VALUES ('Данные до аварии');"
TARGET_TIME=$(psql_cmd -tAc "SELECT now();" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
docker exec -u postgres "$CONTAINER" sh -c "printf '%s\n' '$TARGET_TIME' > $TARGET_FILE"
echo "Recovery target (target_time): $TARGET_TIME"

echo "Waiting ${WAIT_SEC}s before simulated incident..."
sleep "$WAIT_SEC"

psql_cmd -c "TRUNCATE app.important_data;"
psql_cmd -c "INSERT INTO app.important_data (note) VALUES ('Данные после аварии');"
psql_cmd -c "SELECT pg_switch_wal();"
psql_cmd -c "CHECKPOINT;"

echo "State after incident:"
psql_cmd -c "SELECT * FROM app.important_data;"

echo ""
echo "=== LAB4_SEM6 Task 3: PITR recovery ==="
docker compose stop "$SERVICE"

docker compose run --rm --no-deps -u root --entrypoint "" "$SERVICE" \
  /usr/local/bin/lab4_sem6_prepare_recovery.sh "$TARGET_TIME"

docker compose up -d "$SERVICE"
wait_ready

echo ""
echo "=== LAB4_SEM6 verification ==="
psql_cmd -c "SELECT * FROM app.important_data ORDER BY id;"
FOUND=$(psql_cmd -tAc "SELECT COUNT(*) FROM app.important_data WHERE note = 'Данные до аварии';")
AFTER=$(psql_cmd -tAc "SELECT COUNT(*) FROM app.important_data WHERE note = 'Данные после аварии';")

if [ "$FOUND" = "1" ] && [ "$AFTER" = "0" ]; then
  echo "LAB4_SEM6 PITR: PASSED (restored to moment before incident)"
  exit 0
fi

echo "LAB4_SEM6 PITR: FAILED (expected 'Данные до аварии', not post-incident data)"
exit 1
