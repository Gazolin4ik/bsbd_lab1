-- =============================================
-- LAB3_SEM6: ENCRYPTION (pgcrypto) + demo tables
-- =============================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1) Secure copies for column encryption demos (do not break existing app tables)
CREATE TABLE IF NOT EXISTS app.lab3_sem6_users_secure (
    user_id INTEGER PRIMARY KEY REFERENCES app.users(id),
    email TEXT,
    phone_cipher_sym BYTEA,
    passport_cipher_pub BYTEA,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE app.lab3_sem6_users_secure IS 'LAB3_SEM6: encrypted copies of users sensitive fields (sym + PGP public key)';

CREATE TABLE IF NOT EXISTS app.lab3_sem6_offices_secure (
    office_id INTEGER PRIMARY KEY REFERENCES app.offices(id),
    office_number TEXT,
    address_cipher_sym BYTEA,
    phone_cipher_sym BYTEA,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE app.lab3_sem6_offices_secure IS 'LAB3_SEM6: encrypted copies of offices sensitive fields (sym)';

-- 3) Performance benchmark tables (plaintext vs encrypted)
CREATE TABLE IF NOT EXISTS app.lab3_sem6_perf_plain (
    id BIGSERIAL PRIMARY KEY,
    token TEXT NOT NULL,
    payload TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS app.lab3_sem6_perf_enc (
    id BIGSERIAL PRIMARY KEY,
    token TEXT NOT NULL,
    payload_cipher BYTEA NOT NULL
);

COMMENT ON TABLE app.lab3_sem6_perf_plain IS 'LAB3_SEM6: perf dataset plaintext';
COMMENT ON TABLE app.lab3_sem6_perf_enc IS 'LAB3_SEM6: perf dataset encrypted (pgp_sym_encrypt)';

-- 2) Populate encrypted demo tables (idempotent refresh)
-- Data population is done by /lab3_sem6_demo.sql because
-- PostgreSQL server-side pg_read_file() is restricted to data_directory,
-- while the demo reads keys from container files on the psql (client) side.

COMMIT;

