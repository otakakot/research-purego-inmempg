-- =============================================================================
-- Section 4.10: System / Information Functions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TODO [P1] current_database, current_schema, current_user, session_user
-- -----------------------------------------------------------------------------

SELECT current_database() AS cur_db;
SELECT current_schema() AS cur_schema;
SELECT current_user AS cur_user;
SELECT session_user AS sess_user;

-- -----------------------------------------------------------------------------
-- TODO [P2] current_schemas, version, pg_typeof, pg_backend_pid
-- -----------------------------------------------------------------------------

-- current_schemas(include_implicit)
SELECT current_schemas(TRUE) AS schemas_all;
SELECT current_schemas(FALSE) AS schemas_explicit;

-- version()
SELECT version() AS pg_version;

-- pg_typeof
SELECT pg_typeof(42) AS type_int;
SELECT pg_typeof(3.14) AS type_num;
SELECT pg_typeof('hello') AS type_text;
SELECT pg_typeof(TRUE) AS type_bool;
SELECT pg_typeof(ARRAY[1,2,3]) AS type_arr;
SELECT pg_typeof(NOW()) AS type_ts;
SELECT pg_typeof('{"a":1}'::JSON) AS type_json;
SELECT pg_typeof('{"a":1}'::JSONB) AS type_jsonb;

-- pg_backend_pid
SELECT pg_backend_pid() AS backend_pid;

-- -----------------------------------------------------------------------------
-- TODO [P3] has_table_privilege, has_schema_privilege, txid_current
-- -----------------------------------------------------------------------------

-- has_table_privilege (uses a temp table for a self-contained test)
CREATE TEMP TABLE priv_test (id INT);
SELECT has_table_privilege(current_user, 'priv_test', 'SELECT') AS can_select;
SELECT has_table_privilege(current_user, 'priv_test', 'INSERT') AS can_insert;
DROP TABLE IF EXISTS priv_test;

-- has_schema_privilege
SELECT has_schema_privilege(current_user, 'public', 'CREATE') AS can_create;
SELECT has_schema_privilege(current_user, 'public', 'USAGE') AS can_usage;

-- txid_current
SELECT txid_current() AS current_txid;

-- -----------------------------------------------------------------------------
-- TODO [P4] pg_table_size, pg_total_relation_size, pg_column_size
-- -----------------------------------------------------------------------------

-- pg_column_size
SELECT pg_column_size(42) AS size_int;
SELECT pg_column_size('hello'::TEXT) AS size_text;
SELECT pg_column_size(TRUE) AS size_bool;

-- pg_table_size / pg_total_relation_size (requires a table)
CREATE TEMP TABLE size_test (id INT, data TEXT);
INSERT INTO size_test SELECT g, repeat('x', 100) FROM generate_series(1, 100) g;
SELECT pg_table_size('size_test') AS tbl_size;
SELECT pg_total_relation_size('size_test') AS total_size;
SELECT pg_size_pretty(pg_table_size('size_test')) AS tbl_size_pretty;
DROP TABLE IF EXISTS size_test;

-- -----------------------------------------------------------------------------
-- Reference: docs/pg-deep-dive.md §10 - Function call convention (fmgr)
-- The following queries inspect fmgr metadata via pg_proc, demonstrate
-- overload resolution, and surface the volatility classification used by
-- the planner to decide on inlining/caching.
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- TODO [P2] pg_proc — inspect built-in function metadata (pg_catalog scope)
-- Reference: docs/pg-deep-dive.md §10 - FmgrInfo / pg_proc
-- -----------------------------------------------------------------------------
SELECT p.proname,
       p.pronargs,
       p.proargtypes::regtype[]   AS arg_types,
       p.prorettype::regtype       AS return_type,
       p.proretset                AS returns_set,
       p.proisstrict              AS strict,
       p.provolatile              AS volatility   -- 'i'=immutable 's'=stable 'v'=volatile
FROM pg_catalog.pg_proc        p
JOIN pg_catalog.pg_namespace   n ON n.oid = p.pronamespace
WHERE n.nspname = 'pg_catalog'
  AND p.proname IN ('abs','length','now','random','generate_series','coalesce','upper')
ORDER BY p.proname, p.pronargs;

-- -----------------------------------------------------------------------------
-- TODO [P2] Overload resolution — abs(int) vs abs(numeric) vs abs(float8)
-- pg_proc has multiple rows for the same proname; the parser picks one based
-- on argument types via parse_func.c.
-- Reference: docs/pg-deep-dive.md §10 - oprid / function lookup
-- -----------------------------------------------------------------------------
SELECT p.proname,
       p.pronargs,
       p.proargtypes::regtype[] AS arg_types,
       p.prorettype::regtype     AS return_type
FROM pg_catalog.pg_proc      p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'pg_catalog' AND p.proname = 'abs'
ORDER BY p.proargtypes::text;

-- Verify that the chosen overload returns the expected type
SELECT pg_typeof(abs(-1::int4))    AS abs_int4,
       pg_typeof(abs(-1::int8))    AS abs_int8,
       pg_typeof(abs(-1::numeric)) AS abs_numeric,
       pg_typeof(abs(-1::float8))  AS abs_float8;

-- -----------------------------------------------------------------------------
-- TODO [P3] Volatility classification — IMMUTABLE / STABLE / VOLATILE
-- IMMUTABLE: same input → same output, no side effects (e.g. abs, length)
-- STABLE   : constant within a single statement (e.g. now, current_user)
-- VOLATILE : can change at any call (e.g. random, nextval, clock_timestamp)
-- Reference: docs/pg-deep-dive.md §10 - provolatile and planner inlining
-- -----------------------------------------------------------------------------
SELECT p.proname,
       CASE p.provolatile
            WHEN 'i' THEN 'IMMUTABLE'
            WHEN 's' THEN 'STABLE'
            WHEN 'v' THEN 'VOLATILE'
       END AS volatility
FROM pg_catalog.pg_proc      p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'pg_catalog'
  AND p.proname IN ('abs','length','upper','now','current_timestamp',
                    'clock_timestamp','random','nextval')
ORDER BY p.provolatile DESC, p.proname;
