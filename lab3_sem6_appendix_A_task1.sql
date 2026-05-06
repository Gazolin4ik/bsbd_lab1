SHOW password_encryption;

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

