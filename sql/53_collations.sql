-- ============================================================================
-- 53_collations.sql — Section 12.10: Collations
-- Tests collation support for pure-Go in-memory PostgreSQL implementation.
-- Covers COLLATE clause, collation functions, index collation, and catalog.
-- ============================================================================

-- ============================================================================
-- Cleanup: Drop all test objects from previous runs
-- ============================================================================
DROP INDEX IF EXISTS idx_collation_name_c;
DROP TABLE IF EXISTS test_collation_data;
DROP TABLE IF EXISTS test_collation_coldef;
DROP COLLATION IF EXISTS test_custom_collation;

-- ============================================================================
-- Setup: Create table with text data that sorts differently under collations
-- ============================================================================
CREATE TABLE test_collation_data (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

INSERT INTO test_collation_data (name) VALUES
    ('abc'),
    ('ABC'),
    ('äbc'),
    ('Abc'),
    ('ÄBC'),
    ('bcd'),
    ('BCD');

-- ============================================================================
-- [P3] COLLATE clause in expressions
-- ============================================================================
-- TODO: [P3] COLLATE clause in expressions
SELECT 'abc' < 'ABC' COLLATE "C" AS compare_with_c_collate;

SELECT 'abc' = 'ABC' COLLATE "C" AS eq_with_c_collate;

-- ============================================================================
-- [P3] COLLATE in column definitions
-- ============================================================================
-- TODO: [P3] COLLATE in column definitions
CREATE TABLE test_collation_coldef (
    id   SERIAL PRIMARY KEY,
    name TEXT COLLATE "C" NOT NULL
);

INSERT INTO test_collation_coldef (name) VALUES ('abc'), ('ABC'), ('Abc');

SELECT name FROM test_collation_coldef ORDER BY name;

-- ============================================================================
-- [P3] ORDER BY with COLLATE
-- ============================================================================
-- TODO: [P3] ORDER BY with COLLATE
SELECT name FROM test_collation_data ORDER BY name COLLATE "POSIX";

SELECT name FROM test_collation_data ORDER BY name COLLATE "C";

-- ============================================================================
-- [P3] collation for() function
-- ============================================================================
-- TODO: [P3] collation for() function
SELECT collation for ('hello'::TEXT) AS text_collation;

SELECT collation for (name) AS column_collation FROM test_collation_coldef LIMIT 1;

-- ============================================================================
-- [P3] Index with specific collation
-- ============================================================================
-- TODO: [P3] Index with specific collation
CREATE INDEX idx_collation_name_c ON test_collation_data (name COLLATE "C");

SELECT indexname, indexdef FROM pg_indexes
 WHERE tablename = 'test_collation_data' AND indexname = 'idx_collation_name_c';

-- ============================================================================
-- [P4] CREATE COLLATION (if available)
-- ============================================================================
-- TODO: [P4] CREATE COLLATION (if available)
CREATE COLLATION test_custom_collation (LOCALE = 'en_US.utf8');

SELECT 'abc' < 'ABC' COLLATE test_custom_collation AS compare_with_custom;

-- ============================================================================
-- [P4] pg_collation catalog query
-- ============================================================================
-- TODO: [P4] pg_collation catalog query
SELECT collname, collencoding, collctype
  FROM pg_collation
 WHERE collname IN ('C', 'POSIX', 'default')
 ORDER BY collname;

-- ============================================================================
-- [P3] Default collation behavior
-- ============================================================================
-- TODO: [P3] Default collation behavior — comparison with different collations
SELECT name, name COLLATE "C" AS c_sorted
  FROM test_collation_data
 ORDER BY name COLLATE "C";

SELECT name FROM test_collation_data ORDER BY name COLLATE "default";

-- Compare results: "C" collation sorts uppercase before lowercase
SELECT a.name AS c_order
  FROM test_collation_data a
 ORDER BY a.name COLLATE "C";

-- ============================================================================
-- Cleanup
-- ============================================================================
DROP INDEX IF EXISTS idx_collation_name_c;
DROP TABLE IF EXISTS test_collation_data;
DROP TABLE IF EXISTS test_collation_coldef;
DROP COLLATION IF EXISTS test_custom_collation;
