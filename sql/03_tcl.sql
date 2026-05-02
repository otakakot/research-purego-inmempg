-- =============================================================================
-- Section 1.3: Transaction Control Language (TCL)
-- Verification tests for pure-Go in-memory PostgreSQL implementation
-- =============================================================================

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_tcl CASCADE;

-- =====================
-- Setup
-- =====================
CREATE TABLE test_tcl (
    id    SERIAL PRIMARY KEY,
    value TEXT NOT NULL
);

-- =====================
-- [P1] BEGIN / COMMIT — basic transaction that persists
-- =====================
BEGIN;
INSERT INTO test_tcl (value) VALUES ('committed_row');
COMMIT;

SELECT * FROM test_tcl WHERE value = 'committed_row';  -- expect 1 row

-- =====================
-- [P1] START TRANSACTION / COMMIT — alternate syntax
-- =====================
START TRANSACTION;
INSERT INTO test_tcl (value) VALUES ('start_txn_row');
COMMIT;

SELECT * FROM test_tcl WHERE value = 'start_txn_row';  -- expect 1 row

-- =====================
-- [P1] ROLLBACK — transaction rollback discards changes
-- =====================
BEGIN;
INSERT INTO test_tcl (value) VALUES ('rolled_back_row');
ROLLBACK;

SELECT * FROM test_tcl WHERE value = 'rolled_back_row';  -- expect 0 rows

-- =====================
-- [P1] COMMIT after multiple operations
-- =====================
BEGIN;
INSERT INTO test_tcl (value) VALUES ('multi_op_1');
INSERT INTO test_tcl (value) VALUES ('multi_op_2');
UPDATE test_tcl SET value = 'multi_op_1_updated' WHERE value = 'multi_op_1';
DELETE FROM test_tcl WHERE value = 'multi_op_2';
INSERT INTO test_tcl (value) VALUES ('multi_op_3');
COMMIT;

SELECT * FROM test_tcl WHERE value LIKE 'multi_op%' ORDER BY value;
-- expect: multi_op_1_updated, multi_op_3

-- =====================
-- [P2] SAVEPOINT / ROLLBACK TO SAVEPOINT
-- =====================
BEGIN;

INSERT INTO test_tcl (value) VALUES ('before_savepoint');

SAVEPOINT sp1;

INSERT INTO test_tcl (value) VALUES ('after_savepoint_1');

SAVEPOINT sp2;

INSERT INTO test_tcl (value) VALUES ('after_savepoint_2');

-- Rollback to sp2: discard 'after_savepoint_2'
ROLLBACK TO SAVEPOINT sp2;

SELECT * FROM test_tcl WHERE value = 'after_savepoint_2';  -- expect 0 rows

-- 'after_savepoint_1' should still be present
SELECT * FROM test_tcl WHERE value = 'after_savepoint_1';  -- expect 1 row

-- Rollback to sp1: discard 'after_savepoint_1' as well
ROLLBACK TO SAVEPOINT sp1;

SELECT * FROM test_tcl WHERE value = 'after_savepoint_1';  -- expect 0 rows

-- 'before_savepoint' should still be present
SELECT * FROM test_tcl WHERE value = 'before_savepoint';   -- expect 1 row

COMMIT;

-- Verify final state after commit
SELECT * FROM test_tcl WHERE value = 'before_savepoint';   -- expect 1 row

-- =====================
-- [P2] RELEASE SAVEPOINT
-- =====================
BEGIN;

SAVEPOINT sp_release;

INSERT INTO test_tcl (value) VALUES ('released_savepoint_row');

RELEASE SAVEPOINT sp_release;

-- After release, we can no longer rollback to sp_release, but the data persists
COMMIT;

SELECT * FROM test_tcl WHERE value = 'released_savepoint_row';  -- expect 1 row

-- =====================
-- [P2] Nested savepoints
-- =====================
BEGIN;

SAVEPOINT outer_sp;

INSERT INTO test_tcl (value) VALUES ('outer_data');

SAVEPOINT inner_sp;

INSERT INTO test_tcl (value) VALUES ('inner_data');

-- Rollback only inner
ROLLBACK TO SAVEPOINT inner_sp;

SELECT * FROM test_tcl WHERE value = 'inner_data';   -- expect 0 rows
SELECT * FROM test_tcl WHERE value = 'outer_data';   -- expect 1 row

COMMIT;

SELECT * FROM test_tcl WHERE value = 'outer_data';   -- expect 1 row

-- =====================
-- [P2] SET TRANSACTION — isolation level and access mode
-- =====================
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO test_tcl (value) VALUES ('read_committed_row');
COMMIT;

SELECT * FROM test_tcl WHERE value = 'read_committed_row';  -- expect 1 row

BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM test_tcl;
COMMIT;

BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM test_tcl;
COMMIT;

BEGIN;
SET TRANSACTION READ ONLY;
SELECT * FROM test_tcl;
-- INSERT would fail here in read-only mode (not attempted to keep script runnable)
COMMIT;

BEGIN;
SET TRANSACTION READ WRITE;
INSERT INTO test_tcl (value) VALUES ('read_write_row');
COMMIT;

SELECT * FROM test_tcl WHERE value = 'read_write_row';  -- expect 1 row

-- =====================
-- [P2] SET TRANSACTION with combined options
-- =====================
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, READ ONLY;
SELECT COUNT(*) FROM test_tcl;
COMMIT;

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_tcl CASCADE;
