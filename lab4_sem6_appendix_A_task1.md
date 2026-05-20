## lab4_sem6_postgresql.conf

```conf
wal_level = replica
archive_mode = on
archive_command = '/usr/local/bin/lab4_sem6_archive_wal.sh %p %f'
archive_timeout = 60
```

## lab4_sem6_archive_wal.sh

```sh
WAL_PATH="$1"
WAL_FILE="$2"
ARCHIVE_DIR="/var/lib/postgresql/archive"
PASS_FILE="/etc/postgresql/lab4_sem6_wal_pass.txt"

mkdir -p "$ARCHIVE_DIR"
gzip -c "$WAL_PATH" | openssl enc -aes-256-cbc -salt -pass "file:${PASS_FILE}" -out "${ARCHIVE_DIR}/${WAL_FILE}.gz.enc"
exit $?
```

## checks_task1.sql

```sql
SHOW data_checksums;
SHOW wal_level;
SHOW archive_mode;
SHOW archive_command;
SHOW archive_timeout;
SELECT pg_ls_dir('/var/lib/postgresql/archive') AS archive_file;
```
