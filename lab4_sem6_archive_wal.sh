#!/bin/sh
# LAB4_SEM6: encrypt and store WAL segment (archive_command)
WAL_PATH="$1"
WAL_FILE="$2"
ARCHIVE_DIR="/var/lib/postgresql/archive"
PASS_FILE="/etc/postgresql/lab4_sem6_wal_pass.txt"

mkdir -p "$ARCHIVE_DIR"
gzip -c "$WAL_PATH" | openssl enc -aes-256-cbc -salt -pass "file:${PASS_FILE}" -out "${ARCHIVE_DIR}/${WAL_FILE}.gz.enc"
exit $?
