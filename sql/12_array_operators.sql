-- ============================================================================
-- Section 3.6: Array Operators
-- ============================================================================
-- TODO: Verify array operator support in pure-Go implementation
-- Priority: P2 for all operators in this section

-- ----------------------------------------------------------------------------
-- P2: @> (array contains) and <@ (array contained by)
-- TODO: Verify array containment semantics
-- ----------------------------------------------------------------------------

SELECT ARRAY[1, 2, 3] @> ARRAY[1, 3] AS contains_true;
SELECT ARRAY[1, 2] @> ARRAY[1, 2, 3] AS contains_false;
SELECT ARRAY[1, 2, 3] @> ARRAY[]::int[] AS contains_empty;
SELECT ARRAY[1, 1, 2] @> ARRAY[1, 2] AS contains_dupes;

SELECT ARRAY[1, 3] <@ ARRAY[1, 2, 3] AS contained_by_true;
SELECT ARRAY[1, 2, 3] <@ ARRAY[1, 2] AS contained_by_false;
SELECT ARRAY[]::int[] <@ ARRAY[1, 2] AS contained_empty;

-- Text arrays
SELECT ARRAY['a', 'b'] @> ARRAY['a'] AS contains_text;
SELECT ARRAY['a'] <@ ARRAY['a', 'b', 'c'] AS contained_text;

-- ----------------------------------------------------------------------------
-- P2: && (array overlap)
-- TODO: Verify overlap operator returns true when arrays share elements
-- ----------------------------------------------------------------------------

SELECT ARRAY[1, 2, 3] && ARRAY[3, 4, 5] AS overlap_true;
SELECT ARRAY[1, 2] && ARRAY[3, 4] AS overlap_false;
SELECT ARRAY[1, 2] && ARRAY[]::int[] AS overlap_empty;
SELECT ARRAY[]::int[] && ARRAY[]::int[] AS overlap_both_empty;

SELECT ARRAY['a', 'b'] && ARRAY['b', 'c'] AS overlap_text;

-- ----------------------------------------------------------------------------
-- P2: || (array concatenation)
-- TODO: Verify array concatenation and element append/prepend
-- ----------------------------------------------------------------------------

-- Array-to-array concatenation
SELECT ARRAY[1, 2] || ARRAY[3, 4] AS concat_arrays;
SELECT ARRAY[]::int[] || ARRAY[1, 2] AS concat_empty_left;
SELECT ARRAY[1, 2] || ARRAY[]::int[] AS concat_empty_right;

-- Element append / prepend
SELECT ARRAY[1, 2] || 3 AS append_elem;
SELECT 0 || ARRAY[1, 2] AS prepend_elem;

-- Text arrays
SELECT ARRAY['a', 'b'] || ARRAY['c'] AS concat_text;

-- NULL handling
SELECT ARRAY[1, 2] || NULL::int[] AS concat_null;

-- ----------------------------------------------------------------------------
-- P2: ANY(array) / SOME(array)
-- TODO: Verify ANY/SOME with various comparison operators
-- ----------------------------------------------------------------------------

SELECT 3 = ANY(ARRAY[1, 2, 3]) AS any_eq_true;
SELECT 4 = ANY(ARRAY[1, 2, 3]) AS any_eq_false;
SELECT 3 > ANY(ARRAY[1, 2, 3]) AS any_gt;
SELECT 1 < ANY(ARRAY[1, 2, 3]) AS any_lt;

-- SOME is synonym for ANY
SELECT 3 = SOME(ARRAY[1, 2, 3]) AS some_eq_true;

-- ANY with text
SELECT 'b' = ANY(ARRAY['a', 'b', 'c']) AS any_text;
SELECT 'x' = ANY(ARRAY['a', 'b', 'c']) AS any_text_false;

-- ANY with NULL elements
SELECT 1 = ANY(ARRAY[1, NULL]) AS any_null_match;
SELECT 99 = ANY(ARRAY[1, NULL]) AS any_null_nomatch;

-- ANY with empty array
SELECT 1 = ANY(ARRAY[]::int[]) AS any_empty;

-- LIKE ANY
SELECT 'hello' LIKE ANY(ARRAY['h%', 'w%']) AS like_any_true;
SELECT 'hello' LIKE ANY(ARRAY['x%', 'y%']) AS like_any_false;

-- ----------------------------------------------------------------------------
-- P2: ALL(array)
-- TODO: Verify ALL requires condition to hold for every element
-- ----------------------------------------------------------------------------

SELECT 5 > ALL(ARRAY[1, 2, 3]) AS all_gt_true;
SELECT 3 > ALL(ARRAY[1, 2, 3]) AS all_gt_false;
SELECT 0 < ALL(ARRAY[1, 2, 3]) AS all_lt_true;

SELECT 1 = ALL(ARRAY[1, 1, 1]) AS all_eq_true;
SELECT 1 = ALL(ARRAY[1, 1, 2]) AS all_eq_false;

-- ALL with empty array (vacuously true)
SELECT 1 = ALL(ARRAY[]::int[]) AS all_empty;

-- ALL with NULL elements
SELECT 1 = ALL(ARRAY[1, NULL]) AS all_null_partial;
SELECT 99 = ALL(ARRAY[NULL]::int[]) AS all_null_only;
