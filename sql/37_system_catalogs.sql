-- =============================================================================
-- Section 9.1: System Catalogs
-- =============================================================================

-- Setup: create objects to query in catalogs
CREATE TABLE catalog_test (
    id    SERIAL PRIMARY KEY,
    name  TEXT NOT NULL,
    score INT DEFAULT 0
);

CREATE INDEX idx_catalog_test_name ON catalog_test (name);

CREATE SEQUENCE catalog_seq START 100;

-- =============================================================================
-- TODO [P1]: pg_catalog.pg_class — list relations (tables, indexes, sequences)
-- =============================================================================
SELECT relname, relkind
FROM pg_catalog.pg_class
WHERE relname LIKE 'catalog_%'
ORDER BY relname;

-- =============================================================================
-- TODO [P1]: pg_attribute — column metadata
-- =============================================================================
SELECT attname, atttypid::regtype, attnum, attnotnull
FROM pg_catalog.pg_attribute
WHERE attrelid = 'catalog_test'::regclass AND attnum > 0
ORDER BY attnum;

-- =============================================================================
-- TODO [P1]: pg_type — data type information
-- =============================================================================
SELECT typname, typlen, typtype
FROM pg_catalog.pg_type
WHERE typname IN ('int4', 'text', 'bool', 'numeric');

-- =============================================================================
-- TODO [P1]: pg_namespace — schema information
-- =============================================================================
SELECT nspname
FROM pg_catalog.pg_namespace
WHERE nspname NOT LIKE 'pg_toast%'
ORDER BY nspname;

-- =============================================================================
-- TODO [P2]: pg_index — index metadata
-- =============================================================================
SELECT indexrelid::regclass AS index_name,
       indrelid::regclass AS table_name,
       indisunique, indisprimary
FROM pg_catalog.pg_index
WHERE indrelid = 'catalog_test'::regclass;

-- =============================================================================
-- TODO [P2]: pg_constraint — constraint metadata
-- =============================================================================
SELECT conname, contype, conrelid::regclass
FROM pg_catalog.pg_constraint
WHERE conrelid = 'catalog_test'::regclass;

-- =============================================================================
-- TODO [P2]: pg_sequence — sequence parameters
-- =============================================================================
SELECT seqrelid::regclass, seqstart, seqincrement, seqmax
FROM pg_catalog.pg_sequence
WHERE seqrelid = 'catalog_seq'::regclass;

-- =============================================================================
-- TODO [P2]: pg_depend — dependency tracking
-- =============================================================================
SELECT classid::regclass, objid, deptype
FROM pg_catalog.pg_depend
WHERE refobjid = 'catalog_test'::regclass
LIMIT 10;

-- =============================================================================
-- TODO [P2]: pg_description — object comments
-- =============================================================================
COMMENT ON TABLE catalog_test IS 'Test table for catalog queries';
SELECT description
FROM pg_catalog.pg_description
WHERE objoid = 'catalog_test'::regclass AND objsubid = 0;

-- =============================================================================
-- TODO [P2]: pg_settings — server configuration
-- =============================================================================
SELECT name, setting, unit
FROM pg_catalog.pg_settings
WHERE name IN ('max_connections', 'shared_buffers', 'work_mem')
ORDER BY name;

-- =============================================================================
-- TODO [P2]: pg_database — database listing
-- =============================================================================
SELECT datname, encoding, datcollate
FROM pg_catalog.pg_database
ORDER BY datname;

-- =============================================================================
-- TODO [P2]: pg_enum — enum type values
-- =============================================================================
CREATE TYPE mood AS ENUM ('happy', 'sad', 'neutral');
SELECT enumlabel
FROM pg_catalog.pg_enum
WHERE enumtypid = 'mood'::regtype
ORDER BY enumsortorder;

-- =============================================================================
-- TODO [P2]: pg_attrdef — column defaults
-- =============================================================================
SELECT adrelid::regclass, adnum, pg_get_expr(adbin, adrelid) AS default_expr
FROM pg_catalog.pg_attrdef
WHERE adrelid = 'catalog_test'::regclass;

-- =============================================================================
-- TODO [P2]: pg_views — view definitions
-- =============================================================================
CREATE VIEW catalog_view AS SELECT id, name FROM catalog_test;
SELECT viewname, definition
FROM pg_catalog.pg_views
WHERE viewname = 'catalog_view';

-- =============================================================================
-- TODO [P3]: pg_proc — function/procedure metadata
-- =============================================================================
SELECT proname, pronargs, prorettype::regtype
FROM pg_catalog.pg_proc
WHERE proname = 'now';

-- =============================================================================
-- TODO [P3]: pg_trigger — trigger metadata
-- =============================================================================
SELECT tgname, tgrelid::regclass, tgenabled
FROM pg_catalog.pg_trigger
WHERE tgrelid = 'catalog_test'::regclass;

-- =============================================================================
-- TODO [P3]: pg_roles — role information
-- =============================================================================
SELECT rolname, rolsuper, rolcreatedb, rolcanlogin
FROM pg_catalog.pg_roles
WHERE rolname NOT LIKE 'pg_%'
ORDER BY rolname;

-- =============================================================================
-- TODO [P3]: pg_stat_user_tables — table statistics
-- =============================================================================
INSERT INTO catalog_test (name, score) VALUES ('test', 42);
ANALYZE catalog_test;
SELECT relname, seq_scan, n_live_tup
FROM pg_catalog.pg_stat_user_tables
WHERE relname = 'catalog_test';

-- =============================================================================
-- TODO [P3]: pg_stat_activity — active session info
-- =============================================================================
SELECT pid, state, query
FROM pg_catalog.pg_stat_activity
WHERE datname = current_database()
LIMIT 5;

-- =============================================================================
-- TODO [P3]: pg_locks — current lock info
-- =============================================================================
SELECT locktype, relation::regclass, mode, granted
FROM pg_catalog.pg_locks
WHERE relation = 'catalog_test'::regclass;

-- Cleanup
DROP VIEW catalog_view;
DROP TYPE mood;
DROP SEQUENCE catalog_seq;
DROP TABLE catalog_test;
