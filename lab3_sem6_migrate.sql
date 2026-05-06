-- =============================================
-- LAB3_SEM6: ENCRYPTION (pgcrypto) + demo tables
-- =============================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Task 2 requires using existing tables: app.users + app.offices
-- We store ciphertext in additional columns (BYTEA) to avoid breaking existing app logic.

ALTER TABLE app.users
    ADD COLUMN IF NOT EXISTS phone_cipher_sym BYTEA,
    ADD COLUMN IF NOT EXISTS passport_cipher_pub BYTEA;

COMMENT ON COLUMN app.users.phone_cipher_sym IS 'LAB3_SEM6: phone encrypted with symmetric PGP (pgcrypto)';
COMMENT ON COLUMN app.users.passport_cipher_pub IS 'LAB3_SEM6: passport_data encrypted with PGP public key (pgcrypto)';

ALTER TABLE app.employees
    ADD COLUMN IF NOT EXISTS first_name_cipher_sym BYTEA,
    ADD COLUMN IF NOT EXISTS last_name_cipher_sym BYTEA;

COMMENT ON COLUMN app.employees.first_name_cipher_sym IS 'LAB3_SEM6: first_name encrypted with symmetric PGP (pgcrypto)';
COMMENT ON COLUMN app.employees.last_name_cipher_sym IS 'LAB3_SEM6: last_name encrypted with symmetric PGP (pgcrypto)';

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

-- Ciphertext population is done by /lab3_sem6_demo.sql (client-side key loading).

COMMIT;

