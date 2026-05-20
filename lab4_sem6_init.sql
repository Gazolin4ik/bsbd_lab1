-- LAB4_SEM6: schema for PITR demonstration
CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE IF NOT EXISTS app.important_data (
    id SERIAL PRIMARY KEY,
    note TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE app.important_data IS 'LAB4_SEM6: control table for PITR demo';

INSERT INTO app.important_data (note)
SELECT 'Initial seed before lab workflow'
WHERE NOT EXISTS (SELECT 1 FROM app.important_data);
