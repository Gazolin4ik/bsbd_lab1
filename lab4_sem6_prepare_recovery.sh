#!/bin/sh
# LAB4_SEM6: replace PGDATA from base backup and enable PITR (run while postgres is stopped)
set -e

TARGET_TIME="$1"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/pg_backup/base}"
BROKEN="${PGDATA}_broken"

if [ -z "$TARGET_TIME" ]; then
  echo "Usage: $0 <recovery_target_time>"
  exit 1
fi

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

echo "Recovery prepared. target_time=$TARGET_TIME"
