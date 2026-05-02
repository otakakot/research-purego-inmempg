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

-- =============================================================================
-- Reference: docs/pg-deep-dive.md §8 - Lock manager (3-tier model)
-- The following sections cover the 8 heavyweight modes, the 4 row-level
-- modes, pg_locks introspection, advisory locks, and SIREAD predicate locks.
-- =============================================================================

-- Setup for §8 extended tests
CREATE TABLE lock_modes (
    id  SERIAL PRIMARY KEY,
    val TEXT
);
INSERT INTO lock_modes (val) VALUES ('a'), ('b'), ('c');

-- =============================================================================
-- TODO [P2]: Heavyweight 8 modes — LOCK TABLE
-- (AccessShare, RowShare, RowExclusive, ShareUpdateExclusive, Share,
--  ShareRowExclusive, Exclusive, AccessExclusive). LockConflicts[] in
-- src/backend/storage/lmgr/lock.c defines pairwise compatibility.
-- Reference: docs/pg-deep-dive.md §8 - Heavyweight Lock / LockConflicts[]
-- =============================================================================

BEGIN;
LOCK TABLE lock_modes IN ACCESS SHARE MODE;            -- acquired by SELECT
SELECT mode, granted FROM pg_locks
 WHERE relation = 'lock_modes'::regclass AND pid = pg_backend_pid();
COMMIT;

BEGIN;
LOCK TABLE lock_modes IN ROW SHARE MODE;               -- acquired by SELECT FOR UPDATE/SHARE
COMMIT;

BEGIN;
LOCK TABLE lock_modes IN ROW EXCLUSIVE MODE;           -- acquired by INSERT/UPDATE/DELETE
COMMIT;

BEGIN;
LOCK TABLE lock_modes IN SHARE UPDATE EXCLUSIVE MODE;  -- VACUUM (non-FULL), ANALYZE, CREATE INDEX CONCURRENTLY
COMMIT;

BEGIN;
LOCK TABLE lock_modes IN SHARE MODE;                   -- CREATE INDEX (non-concurrent)
COMMIT;

BEGIN;
LOCK TABLE lock_modes IN SHARE ROW EXCLUSIVE MODE;     -- explicit only
COMMIT;

BEGIN;
LOCK TABLE lock_modes IN EXCLUSIVE MODE;               -- explicit only; conflicts with all but ACCESS SHARE
COMMIT;

BEGIN;
LOCK TABLE lock_modes IN ACCESS EXCLUSIVE MODE;        -- DROP TABLE, ALTER TABLE, TRUNCATE, REINDEX, CLUSTER, VACUUM FULL
COMMIT;

-- =============================================================================
-- TODO [P2]: Row-level locks — 4 modes
-- FOR UPDATE / FOR NO KEY UPDATE / FOR SHARE / FOR KEY SHARE.
-- The "NO KEY" / "KEY SHARE" variants exist so that foreign-key checks do
-- not block ordinary updates of non-key columns.
-- Reference: docs/pg-deep-dive.md §8 - tuple locks via heap_lock_tuple
-- =============================================================================

BEGIN;
SELECT * FROM lock_modes WHERE id = 1 FOR UPDATE;
SELECT locktype, mode, granted FROM pg_locks
 WHERE pid = pg_backend_pid() AND locktype IN ('tuple','transactionid','relation');
COMMIT;

BEGIN;
SELECT * FROM lock_modes WHERE id = 1 FOR NO KEY UPDATE;
COMMIT;

BEGIN;
SELECT * FROM lock_modes WHERE id = 1 FOR SHARE;
COMMIT;

BEGIN;
SELECT * FROM lock_modes WHERE id = 1 FOR KEY SHARE;
COMMIT;

-- =============================================================================
-- TODO [P2]: pg_locks — introspection of held / waiting locks
-- Reference: docs/pg-deep-dive.md §8 - LOCK / PROCLOCK shared hash tables
-- =============================================================================

BEGIN;
LOCK TABLE lock_modes IN EXCLUSIVE MODE;
SELECT locktype,
       relation::regclass AS rel,
       mode,
       granted,
       fastpath
FROM pg_locks
WHERE pid = pg_backend_pid()
ORDER BY locktype, mode;
COMMIT;

-- =============================================================================
-- TODO [P3]: Advisory locks — pg_advisory_lock / pg_try_advisory_lock /
-- pg_advisory_unlock. Cooperative application-level locks unrelated to any
-- row or relation; visible in pg_locks with locktype='advisory'.
-- Reference: docs/pg-deep-dive.md §8 - advisory locks API
-- =============================================================================

SELECT pg_advisory_lock(424242);
SELECT locktype, classid, objid, mode, granted FROM pg_locks
 WHERE locktype = 'advisory' AND pid = pg_backend_pid();
SELECT pg_advisory_unlock(424242);

SELECT pg_try_advisory_lock(424243) AS got_first;
SELECT pg_try_advisory_lock(424243) AS got_second;  -- TRUE again in same session (re-entrant)
SELECT pg_advisory_unlock(424243);
SELECT pg_advisory_unlock(424243);

-- Two-key variant
SELECT pg_advisory_lock(1, 2);
SELECT pg_advisory_unlock(1, 2);

-- Transactional variant — released automatically at COMMIT/ROLLBACK
BEGIN;
SELECT pg_advisory_xact_lock(777);
SELECT pg_try_advisory_xact_lock(778) AS got;
COMMIT;

-- =============================================================================
-- TODO [P3]: Predicate locks (SIREAD) under SERIALIZABLE
-- SSI tracks read-sets via SIREAD locks (not blocking, only used to detect
-- read/write dependency cycles → 40001 serialization_failure).
-- Reference: docs/pg-deep-dive.md §8 - Predicate Lock / SSI
-- =============================================================================

BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM lock_modes WHERE val = 'a';
-- Inspect SIREAD locks acquired by this read
SELECT locktype, mode, granted
FROM pg_locks
WHERE pid = pg_backend_pid() AND mode = 'SIReadLock';
COMMIT;

-- Cleanup for §8 extended tests
DROP TABLE IF EXISTS lock_modes;
