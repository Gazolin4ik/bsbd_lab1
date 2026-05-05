-- =============================================
-- LAB3_SEM6: DEMO SCRIPT (Tasks 1-5)
-- Run:
--   docker exec bsbd_lab1_db psql -U postgres -d bsbd_lab1 -f /lab3_sem6_demo.sql
-- For SSL check from host:
--   psql "postgresql://postgres:123@localhost:5433/bsbd_lab1?sslmode=require" -c "\\conninfo"
-- =============================================

\echo '=========================================='
\echo 'LAB3_SEM6 TASK 1: PASSWORD HASHING METHOD'
\echo '=========================================='

SHOW password_encryption;

SELECT
    rolname,
    CASE
        WHEN rolpassword LIKE 'md5%' THEN 'md5'
        WHEN rolpassword LIKE 'SCRAM-SHA-256$%' THEN 'scram-sha-256'
        WHEN rolpassword IS NULL THEN 'NULL (no password stored)'
        ELSE 'other'
    END AS password_hash_method,
    left(COALESCE(rolpassword, ''), 20) AS password_prefix
FROM pg_authid
WHERE rolname IN ('anna_ivanova','petr_smirnov','maria_petrova','auditor_login')
ORDER BY rolname;

\echo ''
\echo '--- Switching password_encryption to scram-sha-256 and re-hashing login roles ---'

ALTER SYSTEM SET password_encryption = 'scram-sha-256';
SELECT pg_reload_conf();

ALTER ROLE anna_ivanova PASSWORD 'anna123';
ALTER ROLE petr_smirnov PASSWORD 'petr123';
ALTER ROLE maria_petrova PASSWORD 'maria123';
ALTER ROLE auditor_login PASSWORD 'auditor123';

SELECT
    rolname,
    CASE
        WHEN rolpassword LIKE 'md5%' THEN 'md5'
        WHEN rolpassword LIKE 'SCRAM-SHA-256$%' THEN 'scram-sha-256'
        WHEN rolpassword IS NULL THEN 'NULL'
        ELSE 'other'
    END AS password_hash_method,
    left(COALESCE(rolpassword, ''), 20) AS password_prefix
FROM pg_authid
WHERE rolname IN ('anna_ivanova','petr_smirnov','maria_petrova','auditor_login')
ORDER BY rolname;

\echo ''
\echo '=========================================='
\echo 'LAB3_SEM6 TASK 2: COLUMN ENCRYPTION (SYMMETRIC + PGP PUBLIC KEY)'
\echo '=========================================='

\echo '--- Load keys from container files (psql client-side) ---'
CREATE TEMP TABLE lab3_sem6__symkey(line TEXT);
CREATE TEMP TABLE lab3_sem6__pubkey(line TEXT);
CREATE TEMP TABLE lab3_sem6__privkey(line TEXT);

\copy lab3_sem6__symkey FROM PROGRAM 'cat /etc/postgresql/keys/lab3_sem6_sym.key'
\copy lab3_sem6__pubkey FROM PROGRAM 'cat /etc/postgresql/keys/lab3_sem6_pub.asc'
\copy lab3_sem6__privkey FROM PROGRAM 'cat /etc/postgresql/keys/lab3_sem6_priv.asc'

WITH keys AS (
    SELECT
        (SELECT btrim(string_agg(line, E'\n')) FROM lab3_sem6__symkey) AS sym_key,
        (SELECT string_agg(line, E'\n') FROM lab3_sem6__pubkey) AS pub_asc,
        (SELECT string_agg(line, E'\n') FROM lab3_sem6__privkey) AS priv_asc
)
SELECT
    length(sym_key)   AS sym_key_len,
    length(pub_asc)   AS pgp_pub_len,
    length(priv_asc)  AS pgp_priv_len
FROM keys;

\echo ''
\echo '--- Populate encrypted demo tables (ciphertext) ---'
TRUNCATE TABLE app.lab3_sem6_users_secure;
TRUNCATE TABLE app.lab3_sem6_offices_secure;

WITH keys AS (
    SELECT
        (SELECT btrim(string_agg(line, E'\n')) FROM lab3_sem6__symkey) AS sym_key,
        dearmor((SELECT string_agg(line, E'\n') FROM lab3_sem6__pubkey)) AS pub_key
)
INSERT INTO app.lab3_sem6_users_secure (user_id, email, phone_cipher_sym, passport_cipher_pub)
SELECT
    u.id,
    u.email,
    CASE WHEN u.phone IS NULL THEN NULL
         ELSE pgp_sym_encrypt(u.phone, keys.sym_key, 'cipher-algo=aes256, compress-algo=1')
    END,
    CASE WHEN u.passport_data IS NULL THEN NULL
         ELSE pgp_pub_encrypt(u.passport_data, keys.pub_key, 'cipher-algo=aes256, compress-algo=1')
    END
FROM app.users u
CROSS JOIN keys;

WITH keys AS (
    SELECT (SELECT btrim(string_agg(line, E'\n')) FROM lab3_sem6__symkey) AS sym_key
)
INSERT INTO app.lab3_sem6_offices_secure (office_id, office_number, address_cipher_sym, phone_cipher_sym)
SELECT
    o.id,
    o.office_number,
    pgp_sym_encrypt(o.address, keys.sym_key, 'cipher-algo=aes256, compress-algo=1'),
    CASE WHEN o.phone IS NULL THEN NULL
         ELSE pgp_sym_encrypt(o.phone, keys.sym_key, 'cipher-algo=aes256, compress-algo=1')
    END
FROM app.offices o
CROSS JOIN keys;

\echo ''
\echo '--- Prepare performance dataset (plaintext vs encrypted) ---'
TRUNCATE TABLE app.lab3_sem6_perf_plain;
TRUNCATE TABLE app.lab3_sem6_perf_enc;

INSERT INTO app.lab3_sem6_perf_plain (token, payload)
SELECT
    'T' || (gs % 1000)::text,
    repeat(md5(gs::text), 10)  -- ~320 chars
FROM generate_series(1, 20000) gs;

WITH keys AS (
    SELECT (SELECT btrim(string_agg(line, E'\n')) FROM lab3_sem6__symkey) AS sym_key
)
INSERT INTO app.lab3_sem6_perf_enc (token, payload_cipher)
SELECT
    p.token,
    pgp_sym_encrypt(p.payload, keys.sym_key, 'cipher-algo=aes256, compress-algo=1')
FROM app.lab3_sem6_perf_plain p
CROSS JOIN keys;

\echo ''
\echo '--- Encrypted data without passing any key (ciphertext) ---'
SELECT user_id, email, phone_cipher_sym, passport_cipher_pub
FROM app.lab3_sem6_users_secure
ORDER BY user_id
LIMIT 5;

\echo ''
\echo '--- Decrypt symmetric fields (phone) by providing symmetric key ---'
WITH k AS (
    SELECT (SELECT btrim(string_agg(line, E'\n')) FROM lab3_sem6__symkey) AS sym_key
)
SELECT
    s.user_id,
    s.email,
    pgp_sym_decrypt(s.phone_cipher_sym, k.sym_key) AS phone_decrypted
FROM app.lab3_sem6_users_secure s
CROSS JOIN k
WHERE s.phone_cipher_sym IS NOT NULL
ORDER BY s.user_id
LIMIT 5;

\echo ''
\echo '--- Decrypt PGP public-key encrypted field (passport_data) by providing private key ---'
WITH priv AS (
    SELECT dearmor((SELECT string_agg(line, E'\n') FROM lab3_sem6__privkey)) AS priv_key
)
SELECT
    s.user_id,
    s.email,
    pgp_pub_decrypt(s.passport_cipher_pub, priv.priv_key) AS passport_decrypted
FROM app.lab3_sem6_users_secure s
CROSS JOIN priv
WHERE s.passport_cipher_pub IS NOT NULL
ORDER BY s.user_id
LIMIT 5;

\echo ''
\echo '=========================================='
\echo 'LAB3_SEM6 TASK 3: SSL CHECK (SERVER SIDE)'
\echo '=========================================='

SHOW ssl;

\echo ''
\echo '--- Note: this session may be local (no SSL). Use host connection with sslmode=require for proof. ---'
SELECT *
FROM pg_stat_ssl
WHERE pid = pg_backend_pid();

\echo ''
\echo '=========================================='
\echo 'LAB3_SEM6 TASK 5: PERFORMANCE (EXPLAIN ANALYZE)'
\echo '=========================================='

\echo '--- Plaintext lookup in app.users (can use index on phone) ---'
EXPLAIN ANALYZE
SELECT id, email
FROM app.users
WHERE phone IS NOT NULL
ORDER BY id
LIMIT 1;

\echo ''
\echo '--- Encrypted lookup requires decrypt (slower, cannot use index directly) ---'
EXPLAIN ANALYZE
WITH k AS (
    SELECT (SELECT btrim(string_agg(line, E'\n')) FROM lab3_sem6__symkey) AS sym_key
),
sample AS (
    SELECT pgp_sym_decrypt(s.phone_cipher_sym, k.sym_key) AS phone_value
    FROM app.lab3_sem6_users_secure s
    CROSS JOIN k
    WHERE s.phone_cipher_sym IS NOT NULL
    LIMIT 1
)
SELECT s.user_id, s.email
FROM app.lab3_sem6_users_secure s
CROSS JOIN k
WHERE pgp_sym_decrypt(s.phone_cipher_sym, k.sym_key) = (SELECT phone_value FROM sample);

\echo ''
\echo '--- Perf dataset: plaintext filter by token (fast) ---'
EXPLAIN ANALYZE
SELECT count(*)
FROM app.lab3_sem6_perf_plain
WHERE token = 'T10';

\echo ''
\echo '--- Perf dataset: encrypted filter by decrypted payload (slow) ---'
EXPLAIN ANALYZE
WITH k AS (
    SELECT (SELECT btrim(string_agg(line, E'\n')) FROM lab3_sem6__symkey) AS sym_key
),
sample AS (
    SELECT pgp_sym_decrypt(payload_cipher, k.sym_key) AS payload_value
    FROM app.lab3_sem6_perf_enc
    CROSS JOIN k
    LIMIT 1
)
SELECT count(*)
FROM app.lab3_sem6_perf_enc e
CROSS JOIN k
WHERE pgp_sym_decrypt(e.payload_cipher, k.sym_key) = (SELECT payload_value FROM sample);

