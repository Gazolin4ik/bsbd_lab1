-- LAB4_SEM6: quick checks after PITR (manual or CI)
\echo '=== data_checksums ==='
SHOW data_checksums;

\echo '=== WAL / archive ==='
SHOW wal_level;
SHOW archive_mode;
SHOW archive_command;

\echo '=== important_data ==='
SELECT * FROM app.important_data ORDER BY id;

\echo '=== archive files (host: docker exec ... ls /var/lib/postgresql/archive) ==='
