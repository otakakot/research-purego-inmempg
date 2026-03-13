-- =============================================================================
-- Section 8.3: Locks
-- =============================================================================

-- Setup
CREATE TABLE lock_test (
    id  SERIAL PRIMARY KEY,
    val TEXT
);
INSERT INTO lock_test (val) VALUES ('row1'), ('row2'), ('row3');

-- =============================================================================
-- TODO [P2]: Row-level locks — FOR UPDATE
-- Acquire an exclusive lock on specific rows within a transaction.
-- =============================================================================

BEGIN;
SELECT * FROM lock_test WHERE id = 1 FOR UPDATE;
-- Row id=1 is now locked; other transactions attempting FOR UPDATE on it will wait
UPDATE lock_test SET val = 'row1_updated' WHERE id = 1;
COMMIT;

-- TODO [P2]: Row-level locks — FOR SHARE
BEGIN;
SELECT * FROM lock_test WHERE id = 2 FOR SHARE;
-- Row id=2 has a shared lock; other transactions can also FOR SHARE but not FOR UPDATE
COMMIT;

-- =============================================================================
-- TODO [P3]: Table-level locks — LOCK TABLE
-- =============================================================================

BEGIN;
LOCK TABLE lock_test IN ACCESS SHARE MODE;
SELECT COUNT(*) FROM lock_test;
COMMIT;

BEGIN;
LOCK TABLE lock_test IN SHARE MODE;
SELECT COUNT(*) FROM lock_test;
COMMIT;

BEGIN;
LOCK TABLE lock_test IN EXCLUSIVE MODE;
UPDATE lock_test SET val = 'locked_update' WHERE id = 3;
COMMIT;

-- =============================================================================
-- TODO [P3]: Advisory locks — application-level cooperative locks
-- =============================================================================

-- Acquire session-level advisory lock (key = 12345)
SELECT pg_advisory_lock(12345);

-- Check that the lock is held
SELECT * FROM pg_locks WHERE locktype = 'advisory';

-- Release the advisory lock
SELECT pg_advisory_unlock(12345);

-- Try-lock variant (non-blocking)
SELECT pg_try_advisory_lock(99999) AS acquired;
SELECT pg_advisory_unlock(99999);

-- Transaction-level advisory lock (released at end of transaction)
BEGIN;
SELECT pg_advisory_xact_lock(54321);
-- Lock is held until COMMIT or ROLLBACK
COMMIT;

-- Cleanup
DROP TABLE lock_test;
