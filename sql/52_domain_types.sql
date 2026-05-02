-- =============================================================================
-- Section 12.9: Domain Types
-- Verification tests for pure-Go in-memory PostgreSQL implementation
-- =============================================================================

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_domain_func_result CASCADE;
DROP TABLE IF EXISTS test_domain_array_col CASCADE;
DROP TABLE IF EXISTS test_domain_email_col CASCADE;
DROP TABLE IF EXISTS test_domain_validation CASCADE;
DROP TABLE IF EXISTS test_domain_multi CASCADE;
DROP FUNCTION IF EXISTS fn_domain_param(email_addr);
DROP FUNCTION IF EXISTS fn_domain_param(us_phone);
DROP DOMAIN IF EXISTS positive_int_multi;
DROP DOMAIN IF EXISTS nonempty_text;
DROP DOMAIN IF EXISTS rated_score;
DROP DOMAIN IF EXISTS us_phone;
DROP DOMAIN IF EXISTS email_addr;
DROP DOMAIN IF EXISTS text_array;
DROP DOMAIN IF EXISTS short_list;
DROP DOMAIN IF EXISTS renamed_domain;
DROP DOMAIN IF EXISTS rename_me;

-- =====================
-- [P3] CREATE DOMAIN with CHECK constraint — multiple constraints, NOT NULL, DEFAULT
-- =====================
-- Domain with multiple CHECK constraints
CREATE DOMAIN rated_score AS INTEGER
    CHECK (VALUE >= 0)
    CHECK (VALUE <= 100);

-- Domain with NOT NULL
CREATE DOMAIN nonempty_text AS TEXT NOT NULL;

-- Domain with DEFAULT and CHECK
CREATE DOMAIN positive_int_multi AS INTEGER
    DEFAULT 1
    NOT NULL
    CHECK (VALUE > 0);

-- =====================
-- [P3] Domain over existing types — email pattern
-- =====================
CREATE DOMAIN email_addr AS TEXT
    CHECK (VALUE ~ '^[^@]+@[^@]+$');

-- =====================
-- [P3] Domain over existing types — US phone pattern
-- =====================
CREATE DOMAIN us_phone AS TEXT
    CHECK (VALUE ~ '^\d{3}-\d{3}-\d{4}$');

-- =====================
-- [P3] Domain over arrays
-- =====================
CREATE DOMAIN text_array AS TEXT[]
    CHECK (array_length(VALUE, 1) <= 5);

CREATE DOMAIN short_list AS INTEGER[]
    NOT NULL
    CHECK (array_length(VALUE, 1) BETWEEN 1 AND 3);

-- =====================
-- [P3] Domain used in table columns — validation on INSERT/UPDATE
-- =====================
CREATE TABLE test_domain_validation (
    id    SERIAL PRIMARY KEY,
    score rated_score,
    name  nonempty_text,
    qty   positive_int_multi
);

INSERT INTO test_domain_validation (score, name, qty) VALUES (85, 'Alice', 10);
INSERT INTO test_domain_validation (score, name, qty) VALUES (0, 'Bob', 1);
INSERT INTO test_domain_validation (score, name, qty) VALUES (100, 'Carol', 99);
-- INSERT INTO test_domain_validation (score, name, qty) VALUES (101, 'Bad', 1);  -- would fail CHECK
-- INSERT INTO test_domain_validation (score, name, qty) VALUES (-1, 'Bad', 1);   -- would fail CHECK
-- INSERT INTO test_domain_validation (score, name) VALUES (50, NULL);             -- would fail NOT NULL on nonempty_text

SELECT * FROM test_domain_validation;

UPDATE test_domain_validation SET score = 50 WHERE id = 1;
-- UPDATE test_domain_validation SET score = 200 WHERE id = 1; -- would fail CHECK

-- Domain with DEFAULT: omit qty to use default value 1
INSERT INTO test_domain_validation (score, name) VALUES (42, 'DefaultQty');
SELECT * FROM test_domain_validation WHERE name = 'DefaultQty';

-- =====================
-- [P3] Domain used with email validation
-- =====================
CREATE TABLE test_domain_email_col (
    id    SERIAL PRIMARY KEY,
    email email_addr
);

INSERT INTO test_domain_email_col (email) VALUES ('user@example.com');
-- INSERT INTO test_domain_email_col (email) VALUES ('invalid');  -- would fail CHECK

SELECT * FROM test_domain_email_col;

-- =====================
-- [P3] Domain over arrays — table usage
-- =====================
CREATE TABLE test_domain_array_col (
    id   SERIAL PRIMARY KEY,
    tags text_array
);

INSERT INTO test_domain_array_col (tags) VALUES (ARRAY['a', 'b', 'c']);
INSERT INTO test_domain_array_col (tags) VALUES (ARRAY['x']);
-- INSERT INTO test_domain_array_col (tags) VALUES (ARRAY['1','2','3','4','5','6']); -- would fail CHECK (>5)

SELECT * FROM test_domain_array_col;

-- =====================
-- [P3] Domain used in function parameters
-- =====================
CREATE FUNCTION fn_domain_param(addr email_addr) RETURNS TEXT AS $$
BEGIN
    RETURN 'Validated: ' || addr;
END;
$$ LANGUAGE plpgsql;

SELECT fn_domain_param('test@example.com');

-- =====================
-- [P3] ALTER DOMAIN ADD CONSTRAINT
-- =====================
ALTER DOMAIN us_phone ADD CONSTRAINT phone_not_empty CHECK (VALUE <> '');

-- =====================
-- [P3] ALTER DOMAIN DROP CONSTRAINT
-- =====================
ALTER DOMAIN us_phone DROP CONSTRAINT phone_not_empty;

-- =====================
-- [P3] ALTER DOMAIN SET DEFAULT / DROP DEFAULT
-- =====================
ALTER DOMAIN rated_score SET DEFAULT 50;
ALTER DOMAIN rated_score DROP DEFAULT;

-- =====================
-- [P3] ALTER DOMAIN SET NOT NULL / DROP NOT NULL
-- =====================
ALTER DOMAIN rated_score SET NOT NULL;
ALTER DOMAIN rated_score DROP NOT NULL;

-- =====================
-- [P3] ALTER DOMAIN RENAME TO
-- =====================
CREATE DOMAIN rename_me AS INTEGER CHECK (VALUE > 0);
ALTER DOMAIN rename_me RENAME TO renamed_domain;

CREATE TABLE test_domain_multi (val renamed_domain);
INSERT INTO test_domain_multi (val) VALUES (42);
SELECT * FROM test_domain_multi;

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_domain_func_result CASCADE;
DROP TABLE IF EXISTS test_domain_array_col CASCADE;
DROP TABLE IF EXISTS test_domain_email_col CASCADE;
DROP TABLE IF EXISTS test_domain_validation CASCADE;
DROP TABLE IF EXISTS test_domain_multi CASCADE;
DROP FUNCTION IF EXISTS fn_domain_param(email_addr);
DROP DOMAIN IF EXISTS positive_int_multi;
DROP DOMAIN IF EXISTS nonempty_text;
DROP DOMAIN IF EXISTS rated_score;
DROP DOMAIN IF EXISTS us_phone;
DROP DOMAIN IF EXISTS email_addr;
DROP DOMAIN IF EXISTS text_array;
DROP DOMAIN IF EXISTS short_list;
DROP DOMAIN IF EXISTS renamed_domain;
