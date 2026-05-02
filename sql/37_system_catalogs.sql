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

-- =============================================================================
-- Reference: docs/pg-deep-dive.md §2 - System catalogs (minimum compat set)
-- The queries below mirror what psql (\d, \df, \di) and ORM/driver
-- introspection (pgx, lib/pq, sqlc, GORM) actually issue. Implementing
-- these in an in-memory PG clone unlocks most tooling out of the box.
-- =============================================================================

-- Setup for §2 extended tests
CREATE TABLE catalog_pets (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    age  INT  CHECK (age >= 0),
    UNIQUE (name)
);
CREATE TABLE catalog_owner (
    id      SERIAL PRIMARY KEY,
    pet_id  INT REFERENCES catalog_pets(id) ON DELETE CASCADE,
    note    TEXT
);
CREATE INDEX idx_catalog_pets_age ON catalog_pets (age);

-- =============================================================================
-- TODO [P1]: \d equivalent — pg_class JOIN pg_namespace JOIN pg_attribute
-- Reference: docs/pg-deep-dive.md §2 - pg_class / pg_attribute / pg_namespace
-- =============================================================================
SELECT n.nspname        AS schema,
       c.relname        AS table_name,
       a.attnum         AS col_no,
       a.attname        AS column_name,
       t.typname        AS type_name,
       a.atttypmod      AS typmod,
       a.attnotnull     AS not_null,
       pg_get_expr(ad.adbin, ad.adrelid) AS default_expr
FROM pg_catalog.pg_class      c
JOIN pg_catalog.pg_namespace  n  ON n.oid = c.relnamespace
JOIN pg_catalog.pg_attribute  a  ON a.attrelid = c.oid
JOIN pg_catalog.pg_type       t  ON t.oid = a.atttypid
LEFT JOIN pg_catalog.pg_attrdef ad
       ON ad.adrelid = a.attrelid AND ad.adnum = a.attnum
WHERE c.relname = 'catalog_pets'
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY a.attnum;

-- =============================================================================
-- TODO [P1]: pg_type — typname / typcategory / typoutput / typreceive
-- Driver-side type registry (pgx) reads exactly these columns.
-- Reference: docs/pg-deep-dive.md §2, §3 - pg_type minimum columns
-- =============================================================================
SELECT t.oid,
       t.typname,
       t.typcategory,
       t.typlen,
       t.typbyval,
       t.typtype,
       i.proname  AS typinput,
       o.proname  AS typoutput,
       r.proname  AS typreceive,
       s.proname  AS typsend
FROM pg_catalog.pg_type        t
LEFT JOIN pg_catalog.pg_proc i ON i.oid = t.typinput
LEFT JOIN pg_catalog.pg_proc o ON o.oid = t.typoutput
LEFT JOIN pg_catalog.pg_proc r ON r.oid = t.typreceive
LEFT JOIN pg_catalog.pg_proc s ON s.oid = t.typsend
WHERE t.typname IN ('bool','int2','int4','int8','float4','float8',
                    'numeric','text','varchar','bpchar','bytea',
                    'date','time','timestamp','timestamptz',
                    'interval','uuid','json','jsonb')
ORDER BY t.typcategory, t.typname;

-- =============================================================================
-- TODO [P2]: pg_proc — pronargs / proargtypes / prorettype
-- Reference: docs/pg-deep-dive.md §2 - pg_proc, §10 - fmgr lookup
-- =============================================================================
SELECT p.proname,
       p.pronargs,
       p.proargtypes,
       p.prorettype::regtype AS returns,
       p.provolatile,
       p.proisstrict,
       p.proretset
FROM pg_catalog.pg_proc      p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'pg_catalog'
  AND p.proname IN ('abs','length','upper','lower','now','coalesce')
ORDER BY p.proname, p.pronargs;

-- =============================================================================
-- TODO [P2]: pg_constraint — PK / FK / UNIQUE / CHECK
-- Reference: docs/pg-deep-dive.md §2 - pg_constraint
-- =============================================================================
SELECT c.conname,
       c.contype,            -- 'p'=primary 'f'=foreign 'u'=unique 'c'=check
       cl.relname AS table_name,
       pg_get_constraintdef(c.oid) AS definition
FROM pg_catalog.pg_constraint c
JOIN pg_catalog.pg_class      cl ON cl.oid = c.conrelid
WHERE cl.relname IN ('catalog_pets','catalog_owner')
ORDER BY cl.relname, c.contype;

-- =============================================================================
-- TODO [P2]: pg_index JOIN pg_class — index list with key columns
-- Reference: docs/pg-deep-dive.md §2 - pg_index
-- =============================================================================
SELECT t.relname  AS table_name,
       i.relname  AS index_name,
       ix.indisunique,
       ix.indisprimary,
       pg_get_indexdef(ix.indexrelid) AS index_def
FROM pg_catalog.pg_index  ix
JOIN pg_catalog.pg_class  i ON i.oid = ix.indexrelid
JOIN pg_catalog.pg_class  t ON t.oid = ix.indrelid
WHERE t.relname IN ('catalog_pets','catalog_owner')
ORDER BY t.relname, i.relname;

-- =============================================================================
-- TODO [P3]: pg_depend — object dependency walk
-- Reference: docs/pg-deep-dive.md §2 - pg_depend / pg_shdepend
-- =============================================================================
SELECT classid::regclass   AS dependent_class,
       objid,
       refclassid::regclass AS referenced_class,
       refobjid,
       deptype             -- 'n'=normal 'a'=auto 'i'=internal 'e'=extension
FROM pg_catalog.pg_depend
WHERE refobjid = 'catalog_pets'::regclass
ORDER BY deptype
LIMIT 20;

-- =============================================================================
-- TODO [P3]: pg_database / pg_roles — minimal cluster introspection
-- Reference: docs/pg-deep-dive.md §2 - pg_database, pg_authid
-- =============================================================================
SELECT datname, datdba::regrole AS owner, encoding, datcollate, datctype, datistemplate
FROM pg_catalog.pg_database
WHERE datname = current_database();

SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin
FROM pg_catalog.pg_roles
WHERE rolname = current_user;

-- Cleanup for §2 extended tests
DROP TABLE IF EXISTS catalog_owner;
DROP TABLE IF EXISTS catalog_pets;
