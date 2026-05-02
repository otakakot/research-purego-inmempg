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

-- =============================================================================
-- Reference: docs/pg-deep-dive.md §1 - MVCC and visibility checks
-- The following sections exercise PostgreSQL's tuple-versioning machinery so
-- that an in-memory clone can be validated against authentic semantics.
-- =============================================================================

-- Setup for §1 extended tests
CREATE TABLE mvcc_sys (
    id  SERIAL PRIMARY KEY,
    val TEXT,
    tag TEXT
);
INSERT INTO mvcc_sys (val, tag) VALUES ('a', 't1'), ('b', 't1'), ('c', 't1');

-- =============================================================================
-- TODO [P2]: System columns — xmin / xmax / cmin / cmax / ctid
-- Every heap tuple carries (xmin, xmax, cmin, cmax, ctid). xmin is the
-- inserting xid, xmax the deleting/locking xid, cmin/cmax the command id
-- inside that xact, and ctid the physical (block, offset) location.
-- Reference: docs/pg-deep-dive.md §1 - HeapTupleHeader fields
-- =============================================================================

SELECT ctid, xmin, xmax, cmin, cmax, id, val FROM mvcc_sys ORDER BY id;

-- After UPDATE: a new tuple version is appended; xmin advances and ctid moves.
BEGIN;
UPDATE mvcc_sys SET val = 'a2' WHERE id = 1;
SELECT ctid, xmin, xmax, cmin, cmax, val FROM mvcc_sys WHERE id = 1;
COMMIT;

-- After DELETE in an open xact: xmax of the deleted version equals the
-- current txid; until COMMIT the row is still visible to other snapshots.
BEGIN;
DELETE FROM mvcc_sys WHERE id = 2;
SELECT ctid, xmin, xmax, val FROM mvcc_sys WHERE id = 2;  -- visible inside this txn? no (own delete)
ROLLBACK;
SELECT ctid, xmin, xmax, val FROM mvcc_sys WHERE id = 2;  -- alive again after ROLLBACK

-- =============================================================================
-- TODO [P2]: HOT (Heap-Only Tuple) update
-- When an UPDATE does NOT touch any indexed column, PostgreSQL may perform a
-- HOT update: the new tuple lives on the same heap page and the index keeps
-- pointing at the old ctid via a HOT chain. ctid of the visible row changes,
-- but the index entry is not re-inserted (visible via pg_stat_user_tables).
-- Reference: docs/pg-deep-dive.md §1 - HOT chains and version pruning
-- =============================================================================

CREATE TABLE mvcc_hot (
    id  INT PRIMARY KEY,
    idx_col TEXT,
    plain_col TEXT
);
CREATE INDEX idx_mvcc_hot_idx ON mvcc_hot (idx_col);
INSERT INTO mvcc_hot VALUES (1, 'k1', 'v1'), (2, 'k2', 'v2');

-- Capture initial ctid
SELECT ctid, * FROM mvcc_hot WHERE id = 1;

-- HOT-eligible update (only plain_col changes)
UPDATE mvcc_hot SET plain_col = 'v1_hot' WHERE id = 1;
SELECT ctid, * FROM mvcc_hot WHERE id = 1;  -- ctid may stay on the same page

-- Non-HOT update (touches indexed column → new index entry required)
UPDATE mvcc_hot SET idx_col = 'k1_new' WHERE id = 1;
SELECT ctid, * FROM mvcc_hot WHERE id = 1;

-- Inspect HOT statistics
SELECT relname, n_tup_upd, n_tup_hot_upd, n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'mvcc_hot';

-- =============================================================================
-- TODO [P3]: VACUUM and VACUUM FULL — dead tuple reclamation
-- VACUUM removes dead row versions and updates n_dead_tup; VACUUM FULL
-- rewrites the entire relation and resets reltuples/relpages.
-- Reference: docs/pg-deep-dive.md §1 - HeapTupleSatisfiesVacuum
-- =============================================================================

CREATE TABLE mvcc_vac (id INT PRIMARY KEY, payload TEXT);
INSERT INTO mvcc_vac SELECT g, repeat('x', 200) FROM generate_series(1, 1000) g;

-- Generate dead tuples
UPDATE mvcc_vac SET payload = payload || '!' WHERE id <= 500;
DELETE FROM mvcc_vac WHERE id > 800;

-- Observe dead tuples before vacuum
SELECT relname, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'mvcc_vac';

VACUUM mvcc_vac;
SELECT relname, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'mvcc_vac';

VACUUM FULL mvcc_vac;
SELECT relname, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'mvcc_vac';

-- =============================================================================
-- TODO [P3]: Snapshot inspection — txid_current / pg_current_snapshot /
-- pg_visible_in_snapshot
-- These expose the (xmin, xmax, xip[]) triple used by HeapTupleSatisfiesMVCC.
-- Reference: docs/pg-deep-dive.md §1 - GetSnapshotData / ProcArray
-- =============================================================================

SELECT txid_current() AS my_xid;
SELECT pg_current_snapshot() AS snap;

-- xmin / xmax / xip from the snapshot
SELECT pg_snapshot_xmin(pg_current_snapshot()) AS snap_xmin,
       pg_snapshot_xmax(pg_current_snapshot()) AS snap_xmax;

-- Is a given xid visible in the current snapshot?
SELECT pg_visible_in_snapshot(txid_current(), pg_current_snapshot()) AS self_visible;

BEGIN;
SELECT txid_current() AS xact_xid, pg_current_snapshot() AS xact_snap;
INSERT INTO mvcc_sys (val, tag) VALUES ('snap-test', 't2');
SELECT xmin, xmax, val FROM mvcc_sys WHERE tag = 't2';
COMMIT;

-- Cleanup for §1 extended tests
DROP TABLE IF EXISTS mvcc_vac;
DROP TABLE IF EXISTS mvcc_hot;
DROP TABLE IF EXISTS mvcc_sys;
