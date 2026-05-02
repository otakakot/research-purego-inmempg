-- =============================================================================
-- Section 1.5: Other Commands
-- Verification tests for pure-Go in-memory PostgreSQL implementation
-- =============================================================================

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_other CASCADE;
DEALLOCATE ALL;

-- =====================
-- Setup
-- =====================
CREATE TABLE test_other (
    id         SERIAL PRIMARY KEY,
    category   VARCHAR(50) NOT NULL,
    value      INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO test_other (category, value) VALUES
    ('alpha', 10),
    ('alpha', 20),
    ('beta', 30),
    ('beta', 40),
    ('gamma', 50);

CREATE INDEX idx_other_category ON test_other (category);

-- =====================
-- [P2] EXPLAIN — show query plan
-- =====================
EXPLAIN SELECT * FROM test_other WHERE category = 'alpha';

-- =====================
-- [P2] EXPLAIN ANALYZE — execute and show actual timing
-- =====================
EXPLAIN ANALYZE SELECT * FROM test_other WHERE category = 'beta';

-- =====================
-- [P2] EXPLAIN with options
-- =====================
EXPLAIN (FORMAT JSON) SELECT * FROM test_other;

EXPLAIN (VERBOSE, COSTS, BUFFERS, ANALYZE) SELECT * FROM test_other WHERE value > 20;

-- =====================
-- [P2] PREPARE / EXECUTE / DEALLOCATE — prepared statements
-- =====================
PREPARE get_by_category(VARCHAR) AS
    SELECT * FROM test_other WHERE category = $1;

EXECUTE get_by_category('alpha');
EXECUTE get_by_category('beta');

PREPARE insert_row(VARCHAR, INTEGER) AS
    INSERT INTO test_other (category, value) VALUES ($1, $2) RETURNING id;

EXECUTE insert_row('delta', 60);

DEALLOCATE get_by_category;
DEALLOCATE insert_row;

-- =====================
-- [P2] DEALLOCATE ALL
-- =====================
PREPARE temp_stmt AS SELECT 1;
DEALLOCATE ALL;

-- =====================
-- [P2] SET — change runtime configuration
-- =====================
SET search_path TO public;
SET statement_timeout TO '30s';
SET work_mem TO '64MB';
SET client_encoding TO 'UTF8';
SET timezone TO 'UTC';
SET DateStyle TO 'ISO, MDY';

-- =====================
-- [P2] SHOW — display current configuration
-- =====================
SHOW search_path;
SHOW statement_timeout;
SHOW work_mem;
SHOW client_encoding;
SHOW timezone;
SHOW server_version;
SHOW ALL;

-- =====================
-- [P2] RESET — reset to default values
-- =====================
RESET statement_timeout;
RESET work_mem;
RESET ALL;

-- =====================
-- [P3] LISTEN / NOTIFY — async notification channels
-- =====================
LISTEN test_channel;

NOTIFY test_channel;
NOTIFY test_channel, 'hello from notify';

-- pg_notify function form
SELECT pg_notify('test_channel', 'hello from pg_notify');

UNLISTEN test_channel;
UNLISTEN *;

-- =====================
-- [P3] LOCK — explicit table locking
-- =====================
BEGIN;

LOCK TABLE test_other IN ACCESS SHARE MODE;

COMMIT;

BEGIN;

LOCK TABLE test_other IN SHARE MODE;

COMMIT;

BEGIN;

LOCK TABLE test_other IN EXCLUSIVE MODE;

COMMIT;

BEGIN;

LOCK TABLE test_other IN ACCESS EXCLUSIVE MODE;

COMMIT;

-- LOCK with NOWAIT option
BEGIN;

LOCK TABLE test_other IN ROW EXCLUSIVE MODE NOWAIT;

COMMIT;

-- =====================
-- [P4] VACUUM — reclaim storage and update statistics
-- =====================
VACUUM test_other;

VACUUM (VERBOSE) test_other;

VACUUM (ANALYZE) test_other;

VACUUM FULL test_other;

-- =====================
-- [P3] ANALYZE — collect table statistics
-- =====================
ANALYZE test_other;

ANALYZE test_other (category);

ANALYZE test_other (category, value);

-- =====================
-- [P4] CLUSTER — physically reorder table by index
-- =====================
CLUSTER test_other USING idx_other_category;

-- Cluster again without specifying index (uses previously set index)
CLUSTER test_other;

-- =====================
-- [P4] REINDEX — rebuild indexes
-- =====================
REINDEX TABLE test_other;

REINDEX INDEX idx_other_category;

-- =====================
-- [P3] DO — anonymous code block
-- =====================
DO $$
BEGIN
    RAISE NOTICE 'Anonymous block executed successfully';
END;
$$;

DO $$
DECLARE
    row_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO row_count FROM test_other;
    RAISE NOTICE 'test_other has % rows', row_count;
END;
$$;

-- DO with explicit language specification
DO LANGUAGE plpgsql $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT category, SUM(value) AS total FROM test_other GROUP BY category LOOP
        RAISE NOTICE 'Category: %, Total: %', rec.category, rec.total;
    END LOOP;
END;
$$;

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_other CASCADE;
DEALLOCATE ALL;
