-- =============================================================================
-- Section 8.1: Transaction Isolation Levels
-- =============================================================================

-- Setup
CREATE TABLE accounts (
    id      SERIAL PRIMARY KEY,
    name    TEXT NOT NULL,
    balance NUMERIC(10, 2) NOT NULL DEFAULT 0
);

INSERT INTO accounts (name, balance) VALUES ('Alice', 1000), ('Bob', 500);

-- =============================================================================
-- TODO [P1]: READ COMMITTED (default in PostgreSQL)
-- Each statement sees only rows committed before it began.
-- =============================================================================

-- Session A
BEGIN ISOLATION LEVEL READ COMMITTED;
UPDATE accounts SET balance = balance - 100 WHERE name = 'Alice';

-- In a concurrent session B (simulated sequentially here):
-- The uncommitted change above should NOT be visible
-- SELECT balance FROM accounts WHERE name = 'Alice';  -- should see 1000

COMMIT;
SELECT * FROM accounts;  -- Alice=900, Bob=500

-- Reset
UPDATE accounts SET balance = 1000 WHERE name = 'Alice';

-- =============================================================================
-- TODO [P2]: REPEATABLE READ
-- Snapshot taken at start of transaction; reads are stable.
-- =============================================================================

BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE name = 'Alice';  -- sees 1000

-- Simulate concurrent update (outside this transaction):
-- Another session commits: UPDATE accounts SET balance = 500 WHERE name = 'Alice';

-- Within this transaction, should still see the snapshot value (1000)
SELECT balance FROM accounts WHERE name = 'Alice';
COMMIT;

-- =============================================================================
-- TODO [P3]: SERIALIZABLE
-- Strictest isolation; transactions behave as if executed serially.
-- =============================================================================

BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT SUM(balance) FROM accounts;
-- Any concurrent modification that would violate serializability
-- causes one transaction to abort with a serialization failure.
COMMIT;

-- =============================================================================
-- TODO [P4]: READ UNCOMMITTED
-- In PostgreSQL, this is treated the same as READ COMMITTED.
-- =============================================================================

BEGIN ISOLATION LEVEL READ UNCOMMITTED;
SELECT * FROM accounts;
COMMIT;

-- Cleanup
DROP TABLE accounts;

-- =============================================================================
-- Reference: docs/pg-deep-dive.md §1 - Transaction isolation levels
-- The following sections cover SET TRANSACTION ISOLATION LEVEL, classic
-- anomalies (non-repeatable read, phantom, write skew), and the SERIALIZABLE
-- retry idiom for sqlstate 40001.
-- =============================================================================

-- Setup for §1 isolation tests
CREATE TABLE iso_balances (
    id      INT PRIMARY KEY,
    holder  TEXT,
    balance NUMERIC(10, 2)
);
INSERT INTO iso_balances VALUES
  (1, 'Alice', 1000),
  (2, 'Bob',    500);

CREATE TABLE iso_oncall (
    doctor TEXT PRIMARY KEY,
    is_oncall BOOLEAN
);
INSERT INTO iso_oncall VALUES
  ('Alice', TRUE),
  ('Bob',   TRUE);

-- =============================================================================
-- TODO [P1]: SET TRANSACTION ISOLATION LEVEL — switching levels in-flight
-- Must be the first statement after BEGIN. Default is READ COMMITTED.
-- Reference: docs/pg-deep-dive.md §1 - snapshot acquisition timing
-- =============================================================================

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SHOW transaction_isolation;
COMMIT;

BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SHOW transaction_isolation;
COMMIT;

BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SHOW transaction_isolation;
COMMIT;

-- Per-statement form
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT * FROM iso_balances;
COMMIT;

-- =============================================================================
-- TODO [P2]: Non-repeatable read — visible under READ COMMITTED, prevented
-- under REPEATABLE READ. Requires TWO concurrent sessions.
-- Reference: docs/pg-deep-dive.md §1 - per-statement vs per-xact snapshots
-- =============================================================================

-- Session A:
--   BEGIN ISOLATION LEVEL READ COMMITTED;
--   SELECT balance FROM iso_balances WHERE id = 1;  -- 1000
--   -- (now Session B commits an UPDATE, see below)
--   SELECT balance FROM iso_balances WHERE id = 1;  -- 900  ← NON-REPEATABLE READ
--   COMMIT;
--
-- Session B (between the two reads above):
--   BEGIN;
--   UPDATE iso_balances SET balance = 900 WHERE id = 1;
--   COMMIT;
--
-- Repeating Session A under REPEATABLE READ keeps both reads at 1000.

-- =============================================================================
-- TODO [P2]: Phantom read — a second range scan returns new rows.
-- Prevented in PostgreSQL even at REPEATABLE READ (snapshot isolation).
-- Requires TWO concurrent sessions.
-- Reference: docs/pg-deep-dive.md §1 - snapshot xmin / xmax / xip[]
-- =============================================================================

-- Session A:
--   BEGIN ISOLATION LEVEL REPEATABLE READ;
--   SELECT count(*) FROM iso_balances WHERE balance > 0;   -- 2
--   -- Session B commits an INSERT below
--   SELECT count(*) FROM iso_balances WHERE balance > 0;   -- still 2 (no phantom)
--   COMMIT;
--
-- Session B:
--   BEGIN;
--   INSERT INTO iso_balances VALUES (3, 'Carol', 200);
--   COMMIT;

-- =============================================================================
-- TODO [P3]: Write skew — the on-call doctor problem.
-- Two doctors each read "the other is on-call" and both go off-call,
-- leaving zero on-call doctors. SNAPSHOT (REPEATABLE READ) allows this;
-- SERIALIZABLE detects the read/write dependency cycle and aborts one.
-- Reference: docs/pg-deep-dive.md §1, §8 - SSI / Predicate locks
-- =============================================================================

-- Session A:
--   BEGIN ISOLATION LEVEL SERIALIZABLE;
--   SELECT count(*) FROM iso_oncall WHERE is_oncall;  -- 2
--   UPDATE iso_oncall SET is_oncall = FALSE WHERE doctor = 'Alice';
--
-- Session B (concurrently):
--   BEGIN ISOLATION LEVEL SERIALIZABLE;
--   SELECT count(*) FROM iso_oncall WHERE is_oncall;  -- 2
--   UPDATE iso_oncall SET is_oncall = FALSE WHERE doctor = 'Bob';
--   COMMIT;
--
-- Session A:
--   COMMIT;   -- ERROR:  could not serialize access due to read/write
--             --        dependencies among transactions (SQLSTATE 40001)

-- =============================================================================
-- TODO [P3]: 40001 retry pattern.
-- Applications must wrap SERIALIZABLE / REPEATABLE READ transactions in a
-- retry loop. Pseudocode:
--
--   for attempt in 1..MAX_ATTEMPTS:
--       try:
--           BEGIN ISOLATION LEVEL SERIALIZABLE;
--           ... business logic ...
--           COMMIT;
--           break
--       except SQLSTATE in ('40001','40P01'):     -- serialization or deadlock
--           ROLLBACK;
--           sleep(backoff(attempt))
--           continue
--
-- 40001 = serialization_failure, 40P01 = deadlock_detected.
-- Reference: docs/pg-deep-dive.md §1, §11 - ereport / SQLSTATE
-- =============================================================================

-- Demonstrate that a simple SERIALIZABLE read-only xact succeeds on its own
BEGIN ISOLATION LEVEL SERIALIZABLE READ ONLY;
SELECT count(*) FROM iso_balances;
COMMIT;

-- Cleanup for §1 isolation tests
DROP TABLE IF EXISTS iso_oncall;
DROP TABLE IF EXISTS iso_balances;
