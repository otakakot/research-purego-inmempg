-- =============================================================================
-- Section 8.2: MVCC (Multi-Version Concurrency Control)
-- =============================================================================

-- Setup
CREATE TABLE mvcc_test (
    id  SERIAL PRIMARY KEY,
    val TEXT
);

INSERT INTO mvcc_test (val) VALUES ('initial');

-- =============================================================================
-- TODO [P1]: Snapshot isolation — verify visibility between transactions
-- Writers do not block readers; each transaction sees a consistent snapshot.
-- =============================================================================

-- Transaction A: begin and read
BEGIN;
SELECT val FROM mvcc_test WHERE id = 1;  -- 'initial'

-- Simulate Transaction B (committed update)
-- In a real concurrent test, another connection would do:
--   UPDATE mvcc_test SET val = 'updated' WHERE id = 1; COMMIT;

-- For single-connection sequential testing, commit A first then verify:
COMMIT;

-- Demonstrate that an UPDATE + SELECT in the same txn sees new value
BEGIN;
UPDATE mvcc_test SET val = 'v2' WHERE id = 1;
SELECT val FROM mvcc_test WHERE id = 1;  -- should see 'v2'
COMMIT;

-- =============================================================================
-- TODO [P2]: Row versioning — xmin/xmax system columns
-- PostgreSQL stores version info per tuple.
-- =============================================================================

SELECT xmin, xmax, val FROM mvcc_test WHERE id = 1;

-- After an update, xmin changes to the new transaction id
UPDATE mvcc_test SET val = 'v3' WHERE id = 1;
SELECT xmin, xmax, val FROM mvcc_test WHERE id = 1;

-- =============================================================================
-- TODO [P2]: Deadlock detection
-- PostgreSQL automatically detects deadlocks and aborts one transaction.
-- This test is best run with two concurrent sessions.
-- Shown here as a structural template.
-- =============================================================================

CREATE TABLE deadlock_test (
    id  INT PRIMARY KEY,
    val TEXT
);
INSERT INTO deadlock_test VALUES (1, 'a'), (2, 'b');

-- Session A:
-- BEGIN;
-- UPDATE deadlock_test SET val = 'a1' WHERE id = 1;  -- locks row 1
-- (wait for session B to lock row 2)
-- UPDATE deadlock_test SET val = 'b1' WHERE id = 2;  -- waits for row 2 → deadlock

-- Session B:
-- BEGIN;
-- UPDATE deadlock_test SET val = 'b2' WHERE id = 2;  -- locks row 2
-- UPDATE deadlock_test SET val = 'a2' WHERE id = 1;  -- waits for row 1 → deadlock detected

-- PostgreSQL will detect the deadlock and abort one of the transactions
-- with: ERROR: deadlock detected

DROP TABLE deadlock_test;

-- Cleanup
DROP TABLE mvcc_test;
