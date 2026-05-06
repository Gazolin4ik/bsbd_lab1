SELECT table_schema, table_name, column_name, data_type FROM information_schema.columns
WHERE table_schema = 'app'
  AND (
    (table_name = 'users' AND column_name IN ('phone_cipher_sym', 'passport_cipher_pub'))
    OR
    (table_name = 'employees' AND column_name IN ('first_name_cipher_sym', 'last_name_cipher_sym'))
  )
ORDER BY table_name, column_name;

SELECT id, email, phone_cipher_sym, passport_cipher_pub FROM app.users
WHERE phone_cipher_sym IS NOT NULL OR passport_cipher_pub IS NOT NULL
ORDER BY id
LIMIT 5;

SELECT id, first_name_cipher_sym, last_name_cipher_sym FROM app.employees
WHERE first_name_cipher_sym IS NOT NULL OR last_name_cipher_sym IS NOT NULL
ORDER BY id
LIMIT 5;

WITH k AS (
  SELECT '0c063ee879e8eb4e4db62a85eb230fc7342da46c92e9ac87fc92c43d23ba8d2e'::text AS sym_key
)
SELECT u.id, u.email, pgp_sym_decrypt(u.phone_cipher_sym, k.sym_key) AS phone_decrypted
FROM app.users u CROSS JOIN k WHERE u.phone_cipher_sym IS NOT NULL
ORDER BY u.id
LIMIT 5;

WITH k AS (
  SELECT '0c063ee879e8eb4e4db62a85eb230fc7342da46c92e9ac87fc92c43d23ba8d2e'::text AS sym_key
)
SELECT e.id, pgp_sym_decrypt(e.first_name_cipher_sym, k.sym_key) AS first_name_decrypted,
pgp_sym_decrypt(e.last_name_cipher_sym,  k.sym_key) AS last_name_decrypted
FROM app.employees e CROSS JOIN k WHERE e.first_name_cipher_sym IS NOT NULL
ORDER BY e.id
LIMIT 5;

WITH priv AS (
  SELECT dearmor($$-----BEGIN PGP PRIVATE KEY BLOCK-----
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
=I1fe
-----END PGP PRIVATE KEY BLOCK-----$$) AS priv_key
)
SELECT u.id, u.email, pgp_pub_decrypt(u.passport_cipher_pub, priv.priv_key) AS passport_decrypted
FROM app.users u CROSS JOIN priv WHERE u.passport_cipher_pub IS NOT NULL
ORDER BY u.id
LIMIT 5;

