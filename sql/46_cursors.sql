-- =============================================================================
-- Section 12.3: Cursors
-- Verification tests for pure-Go in-memory PostgreSQL implementation
-- =============================================================================

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_cursors CASCADE;

-- =====================
-- Setup
-- =====================
CREATE TABLE test_cursors (
    id    SERIAL PRIMARY KEY,
    label TEXT NOT NULL
);

INSERT INTO test_cursors (label)
SELECT 'row_' || g FROM generate_series(1, 10) AS g;

-- =====================
-- [P3] DECLARE CURSOR — basic cursor declaration
-- =====================
BEGIN;

DECLARE cur_basic CURSOR FOR SELECT id, label FROM test_cursors ORDER BY id;

FETCH NEXT FROM cur_basic;  -- expect row_1

CLOSE cur_basic;
COMMIT;

-- =====================
-- [P3] FETCH NEXT / FETCH FORWARD — forward traversal
-- =====================
BEGIN;

DECLARE cur_fwd CURSOR FOR SELECT id, label FROM test_cursors ORDER BY id;

FETCH NEXT FROM cur_fwd;       -- expect row_1
FETCH NEXT FROM cur_fwd;       -- expect row_2
FETCH FORWARD 3 FROM cur_fwd;  -- expect row_3, row_4, row_5

CLOSE cur_fwd;
COMMIT;

-- =====================
-- [P3] FETCH PRIOR / FETCH BACKWARD — backward traversal (requires SCROLL)
-- =====================
BEGIN;

DECLARE cur_back SCROLL CURSOR FOR SELECT id, label FROM test_cursors ORDER BY id;

FETCH NEXT FROM cur_back;        -- expect row_1
FETCH NEXT FROM cur_back;        -- expect row_2
FETCH NEXT FROM cur_back;        -- expect row_3
FETCH PRIOR FROM cur_back;       -- expect row_2
FETCH BACKWARD 1 FROM cur_back;  -- expect row_1

CLOSE cur_back;
COMMIT;

-- =====================
-- [P3] FETCH FIRST / FETCH LAST — jump to boundaries
-- =====================
BEGIN;

DECLARE cur_bounds SCROLL CURSOR FOR SELECT id, label FROM test_cursors ORDER BY id;

FETCH LAST FROM cur_bounds;   -- expect row_10
FETCH FIRST FROM cur_bounds;  -- expect row_1

CLOSE cur_bounds;
COMMIT;

-- =====================
-- [P3] FETCH ABSOLUTE n / FETCH RELATIVE n — positional fetch
-- =====================
BEGIN;

DECLARE cur_pos SCROLL CURSOR FOR SELECT id, label FROM test_cursors ORDER BY id;

FETCH ABSOLUTE 5 FROM cur_pos;   -- expect row_5
FETCH RELATIVE 2 FROM cur_pos;   -- expect row_7
FETCH RELATIVE -3 FROM cur_pos;  -- expect row_4
FETCH ABSOLUTE -1 FROM cur_pos;  -- expect row_10 (last row)

CLOSE cur_pos;
COMMIT;

-- =====================
-- [P3] FETCH ALL — fetch all remaining rows
-- =====================
BEGIN;

DECLARE cur_all CURSOR FOR SELECT id, label FROM test_cursors ORDER BY id;

FETCH FORWARD 3 FROM cur_all;  -- expect row_1, row_2, row_3
FETCH ALL FROM cur_all;        -- expect row_4 through row_10 (7 rows)

CLOSE cur_all;
COMMIT;

-- =====================
-- [P3] MOVE — move cursor without returning data
-- =====================
BEGIN;

DECLARE cur_move SCROLL CURSOR FOR SELECT id, label FROM test_cursors ORDER BY id;

MOVE NEXT FROM cur_move;        -- skip row_1
MOVE FORWARD 2 FROM cur_move;   -- skip row_2, row_3
FETCH NEXT FROM cur_move;       -- expect row_4
MOVE ABSOLUTE 8 FROM cur_move;  -- position on row_8
FETCH NEXT FROM cur_move;       -- expect row_9

CLOSE cur_move;
COMMIT;

-- =====================
-- [P3] CLOSE — close cursor
-- =====================
BEGIN;

DECLARE cur_close CURSOR FOR SELECT id, label FROM test_cursors ORDER BY id;
FETCH NEXT FROM cur_close;  -- expect row_1

CLOSE cur_close;

-- Fetching after CLOSE should raise an error (not executed to keep script runnable)
-- FETCH NEXT FROM cur_close;  -- ERROR: cursor "cur_close" does not exist

COMMIT;

-- =====================
-- [P3] SCROLL vs NO SCROLL cursors
-- =====================
BEGIN;

-- NO SCROLL: only forward fetching is allowed
DECLARE cur_noscroll NO SCROLL CURSOR FOR SELECT id, label FROM test_cursors ORDER BY id;

FETCH NEXT FROM cur_noscroll;     -- expect row_1
FETCH NEXT FROM cur_noscroll;     -- expect row_2
-- FETCH PRIOR FROM cur_noscroll; -- ERROR: cursor can only scan forward

CLOSE cur_noscroll;

-- SCROLL: both forward and backward fetching allowed
DECLARE cur_scroll SCROLL CURSOR FOR SELECT id, label FROM test_cursors ORDER BY id;

FETCH NEXT FROM cur_scroll;   -- expect row_1
FETCH NEXT FROM cur_scroll;   -- expect row_2
FETCH PRIOR FROM cur_scroll;  -- expect row_1 (backward works)

CLOSE cur_scroll;
COMMIT;

-- =====================
-- [P4] WITH HOLD cursors — survive transaction commit
-- =====================
BEGIN;

DECLARE cur_hold CURSOR WITH HOLD FOR SELECT id, label FROM test_cursors ORDER BY id;

FETCH NEXT FROM cur_hold;  -- expect row_1

COMMIT;

-- Cursor is still usable after COMMIT because of WITH HOLD
FETCH NEXT FROM cur_hold;  -- expect row_2
FETCH NEXT FROM cur_hold;  -- expect row_3

CLOSE cur_hold;

-- =====================
-- [P4] Cursor in PL/pgSQL (FOR rec IN cursor LOOP)
-- =====================
DO $$
DECLARE
    cur CURSOR FOR SELECT id, label FROM test_cursors ORDER BY id LIMIT 5;
    rec RECORD;
BEGIN
    FOR rec IN cur LOOP
        RAISE NOTICE 'id=%, label=%', rec.id, rec.label;
    END LOOP;
END;
$$;

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_cursors CASCADE;
