WAL_FILE="$1"
DEST_PATH="$2"
ARCHIVE_DIR="/var/lib/postgresql/archive"
PASS_FILE="/etc/postgresql/lab4_sem6_wal_pass.txt"

if [ ! -f "${ARCHIVE_DIR}/${WAL_FILE}.gz.enc" ]; then
  exit 1
fi

openssl enc -d -aes-256-cbc -pass "file:${PASS_FILE}" -in "${ARCHIVE_DIR}/${WAL_FILE}.gz.enc" | gunzip -c > "${DEST_PATH}"
exit $?
