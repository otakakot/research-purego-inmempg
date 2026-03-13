-- =============================================================================
-- Section 1.1: Data Definition Language (DDL)
-- Verification tests for pure-Go in-memory PostgreSQL implementation
-- =============================================================================

-- =====================
-- Cleanup
-- =====================
DROP MATERIALIZED VIEW IF EXISTS mv_active_users;
DROP VIEW IF EXISTS v_active_users;
DROP TRIGGER IF EXISTS trg_update_timestamp ON test_users;
DROP FUNCTION IF EXISTS fn_update_timestamp();
DROP FUNCTION IF EXISTS fn_add(INTEGER, INTEGER);
DROP TABLE IF EXISTS test_partitions_2024 CASCADE;
DROP TABLE IF EXISTS test_partitions_2025 CASCADE;
DROP TABLE IF EXISTS test_partitions CASCADE;
DROP TABLE IF EXISTS test_like_copy CASCADE;
DROP TABLE IF EXISTS test_table_as CASCADE;
DROP TABLE IF EXISTS test_orders CASCADE;
DROP TABLE IF EXISTS test_users CASCADE;
DROP TABLE IF EXISTS test_temp CASCADE;
DROP SEQUENCE IF EXISTS test_seq;
DROP TYPE IF EXISTS mood_enum;
DROP TYPE IF EXISTS address_type;
DROP DOMAIN IF EXISTS positive_int;
DROP EXTENSION IF EXISTS pg_trgm;
DROP SCHEMA IF EXISTS test_schema CASCADE;

-- =====================
-- [P1] CREATE TABLE — basic table with columns, constraints, and defaults
-- =====================
CREATE TABLE test_users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(100) NOT NULL UNIQUE,
    email       VARCHAR(255) NOT NULL,
    age         INTEGER CHECK (age >= 0),
    is_active   BOOLEAN DEFAULT TRUE,
    balance     NUMERIC(12, 2) DEFAULT 0.00,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP
);

CREATE TABLE test_orders (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES test_users(id) ON DELETE CASCADE,
    amount      NUMERIC(10, 2) NOT NULL,
    status      VARCHAR(20) DEFAULT 'pending',
    ordered_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================
-- [P1] ALTER TABLE — add column
-- =====================
ALTER TABLE test_users ADD COLUMN bio TEXT;

-- =====================
-- [P1] ALTER TABLE — alter column type
-- =====================
ALTER TABLE test_users ALTER COLUMN bio TYPE VARCHAR(1000);

-- =====================
-- [P1] ALTER TABLE — set/drop default
-- =====================
ALTER TABLE test_users ALTER COLUMN bio SET DEFAULT '';
ALTER TABLE test_users ALTER COLUMN bio DROP DEFAULT;

-- =====================
-- [P1] ALTER TABLE — set/drop NOT NULL
-- =====================
ALTER TABLE test_users ALTER COLUMN bio SET NOT NULL;
ALTER TABLE test_users ALTER COLUMN bio DROP NOT NULL;

-- =====================
-- [P1] ALTER TABLE — add constraint
-- =====================
ALTER TABLE test_users ADD CONSTRAINT chk_email CHECK (email LIKE '%@%');

-- =====================
-- [P1] ALTER TABLE — drop constraint
-- =====================
ALTER TABLE test_users DROP CONSTRAINT chk_email;

-- =====================
-- [P1] ALTER TABLE — drop column
-- =====================
ALTER TABLE test_users DROP COLUMN bio;

-- =====================
-- [P1] ALTER TABLE — rename column
-- =====================
ALTER TABLE test_users RENAME COLUMN is_active TO active;
ALTER TABLE test_users RENAME COLUMN active TO is_active;

-- =====================
-- [P1] ALTER TABLE — rename table
-- =====================
ALTER TABLE test_users RENAME TO test_users_renamed;
ALTER TABLE test_users_renamed RENAME TO test_users;

-- =====================
-- [P2] CREATE INDEX / DROP INDEX
-- =====================
CREATE INDEX idx_users_email ON test_users (email);
CREATE UNIQUE INDEX idx_users_username ON test_users (username);
CREATE INDEX idx_orders_user_status ON test_orders (user_id, status);

DROP INDEX idx_users_email;
DROP INDEX idx_users_username;
DROP INDEX idx_orders_user_status;

-- =====================
-- [P2] CREATE SCHEMA / DROP SCHEMA
-- =====================
CREATE SCHEMA test_schema;
CREATE TABLE test_schema.example (id SERIAL PRIMARY KEY, name TEXT);
INSERT INTO test_schema.example (name) VALUES ('schema_test');
SELECT * FROM test_schema.example;
DROP SCHEMA test_schema CASCADE;

-- =====================
-- [P2] CREATE VIEW / DROP VIEW
-- =====================
INSERT INTO test_users (username, email, age, is_active) VALUES
    ('alice', 'alice@example.com', 30, TRUE),
    ('bob', 'bob@example.com', 25, FALSE);

CREATE VIEW v_active_users AS
    SELECT id, username, email FROM test_users WHERE is_active = TRUE;

SELECT * FROM v_active_users;

DROP VIEW v_active_users;

-- =====================
-- [P2] CREATE SEQUENCE / ALTER SEQUENCE / DROP SEQUENCE
-- =====================
CREATE SEQUENCE test_seq START WITH 100 INCREMENT BY 10;

SELECT nextval('test_seq');  -- expect 100
SELECT nextval('test_seq');  -- expect 110
SELECT currval('test_seq');  -- expect 110

ALTER SEQUENCE test_seq RESTART WITH 500;
SELECT nextval('test_seq');  -- expect 500

DROP SEQUENCE test_seq;

-- =====================
-- [P3] CREATE TYPE (ENUM) / DROP TYPE
-- =====================
CREATE TYPE mood_enum AS ENUM ('happy', 'sad', 'neutral');

SELECT 'happy'::mood_enum;

-- =====================
-- [P3] CREATE TYPE (composite) / DROP TYPE
-- =====================
CREATE TYPE address_type AS (
    street  TEXT,
    city    TEXT,
    zip     VARCHAR(10)
);

SELECT ROW('123 Main St', 'Springfield', '62704')::address_type;

DROP TYPE address_type;
DROP TYPE mood_enum;

-- =====================
-- [P3] CREATE DOMAIN
-- =====================
CREATE DOMAIN positive_int AS INTEGER CHECK (VALUE > 0);

CREATE TABLE test_domain_check (id positive_int);
INSERT INTO test_domain_check VALUES (1);   -- should succeed
-- INSERT INTO test_domain_check VALUES (-1); -- would fail (commented to keep script runnable)

DROP TABLE test_domain_check;
DROP DOMAIN positive_int;

-- =====================
-- [P3] CREATE FUNCTION / DROP FUNCTION
-- =====================
CREATE FUNCTION fn_add(a INTEGER, b INTEGER) RETURNS INTEGER AS $$
BEGIN
    RETURN a + b;
END;
$$ LANGUAGE plpgsql;

SELECT fn_add(3, 4);  -- expect 7

DROP FUNCTION fn_add(INTEGER, INTEGER);

-- =====================
-- [P3] CREATE TRIGGER / DROP TRIGGER
-- =====================
CREATE FUNCTION fn_update_timestamp() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_timestamp
    BEFORE UPDATE ON test_users
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_timestamp();

UPDATE test_users SET age = 31 WHERE username = 'alice';
SELECT username, updated_at FROM test_users WHERE username = 'alice';

DROP TRIGGER trg_update_timestamp ON test_users;
DROP FUNCTION fn_update_timestamp();

-- =====================
-- [P3] CREATE EXTENSION
-- =====================
CREATE EXTENSION IF NOT EXISTS pg_trgm;
DROP EXTENSION IF EXISTS pg_trgm;

-- =====================
-- [P2] TRUNCATE
-- =====================
INSERT INTO test_orders (user_id, amount) VALUES (1, 99.99);
SELECT COUNT(*) FROM test_orders;  -- expect >= 1

TRUNCATE test_orders RESTART IDENTITY CASCADE;
SELECT COUNT(*) FROM test_orders;  -- expect 0

-- =====================
-- [P4] COMMENT ON
-- =====================
COMMENT ON TABLE test_users IS 'Main users table for testing';
COMMENT ON COLUMN test_users.username IS 'Unique login name for the user';

-- =====================
-- [P3] CREATE MATERIALIZED VIEW / REFRESH MATERIALIZED VIEW
-- =====================
CREATE MATERIALIZED VIEW mv_active_users AS
    SELECT id, username, email FROM test_users WHERE is_active = TRUE;

SELECT * FROM mv_active_users;

INSERT INTO test_users (username, email, age, is_active) VALUES ('carol', 'carol@example.com', 28, TRUE);

REFRESH MATERIALIZED VIEW mv_active_users;
SELECT * FROM mv_active_users;

DROP MATERIALIZED VIEW mv_active_users;

-- =====================
-- [P2] CREATE TEMPORARY TABLE
-- =====================
CREATE TEMPORARY TABLE test_temp (
    id   SERIAL PRIMARY KEY,
    data TEXT
);
INSERT INTO test_temp (data) VALUES ('temporary row');
SELECT * FROM test_temp;
DROP TABLE test_temp;

-- =====================
-- [P3] CREATE TABLE ... PARTITION BY
-- =====================
CREATE TABLE test_partitions (
    id         SERIAL,
    created_at DATE NOT NULL,
    payload    TEXT
) PARTITION BY RANGE (created_at);

CREATE TABLE test_partitions_2024 PARTITION OF test_partitions
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE test_partitions_2025 PARTITION OF test_partitions
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

INSERT INTO test_partitions (created_at, payload) VALUES ('2024-06-15', 'row in 2024');
INSERT INTO test_partitions (created_at, payload) VALUES ('2025-03-01', 'row in 2025');

SELECT tableoid::regclass, * FROM test_partitions ORDER BY created_at;

DROP TABLE test_partitions CASCADE;

-- =====================
-- [P2] CREATE TABLE ... LIKE
-- =====================
CREATE TABLE test_like_copy (LIKE test_users INCLUDING ALL);

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'test_like_copy'
ORDER BY ordinal_position;

DROP TABLE test_like_copy;

-- =====================
-- [P2] CREATE TABLE ... AS
-- =====================
CREATE TABLE test_table_as AS
    SELECT id, username, email FROM test_users WHERE is_active = TRUE;

SELECT * FROM test_table_as;
DROP TABLE test_table_as;

-- =====================
-- [P1] DROP TABLE
-- =====================
DROP TABLE test_orders;
DROP TABLE test_users;

-- =====================
-- Final verification: no leftover objects
-- =====================
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
  AND tablename LIKE 'test_%';
