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
