-- ============================================================================
-- Section 3.1: Comparison Operators
-- ============================================================================
-- TODO: Verify comparison operator support in pure-Go in-memory PostgreSQL
-- Priority levels noted per operator group

-- ----------------------------------------------------------------------------
-- P1: Basic comparison operators (=, <>, !=, <, >, <=, >=)
-- ----------------------------------------------------------------------------

SELECT 1 = 1 AS eq_true;
SELECT 1 = 2 AS eq_false;
SELECT 'abc' = 'abc' AS eq_str_true;
SELECT 'abc' = 'def' AS eq_str_false;

SELECT 1 <> 2 AS ne_true;
SELECT 1 <> 1 AS ne_false;

-- TODO: Confirm != is accepted as alias for <>
SELECT 1 != 2 AS ne_alias_true;
SELECT 1 != 1 AS ne_alias_false;

SELECT 1 < 2 AS lt_true;
SELECT 2 < 1 AS lt_false;
SELECT 1 < 1 AS lt_equal;

SELECT 2 > 1 AS gt_true;
SELECT 1 > 2 AS gt_false;
SELECT 1 > 1 AS gt_equal;

SELECT 1 <= 2 AS le_true;
SELECT 1 <= 1 AS le_equal;
SELECT 2 <= 1 AS le_false;

SELECT 2 >= 1 AS ge_true;
SELECT 1 >= 1 AS ge_equal;
SELECT 1 >= 2 AS ge_false;

-- NULL propagation
SELECT 1 = NULL AS eq_null;
SELECT NULL = NULL AS null_eq_null;
SELECT 1 <> NULL AS ne_null;

-- ----------------------------------------------------------------------------
-- P1: BETWEEN ... AND ... / NOT BETWEEN
-- ----------------------------------------------------------------------------

SELECT 5 BETWEEN 1 AND 10 AS between_true;
SELECT 1 BETWEEN 1 AND 10 AS between_lower_bound;
SELECT 10 BETWEEN 1 AND 10 AS between_upper_bound;
SELECT 0 BETWEEN 1 AND 10 AS between_false;

SELECT 0 NOT BETWEEN 1 AND 10 AS not_between_true;
SELECT 5 NOT BETWEEN 1 AND 10 AS not_between_false;

-- BETWEEN with different types
SELECT 'b' BETWEEN 'a' AND 'c' AS between_str;
SELECT DATE '2024-06-15' BETWEEN DATE '2024-01-01' AND DATE '2024-12-31' AS between_date;

-- BETWEEN with NULL
SELECT NULL BETWEEN 1 AND 10 AS between_null_val;
SELECT 5 BETWEEN NULL AND 10 AS between_null_lower;
SELECT 5 BETWEEN 1 AND NULL AS between_null_upper;

-- ----------------------------------------------------------------------------
-- P1: IS NULL / IS NOT NULL
-- ----------------------------------------------------------------------------

SELECT NULL IS NULL AS is_null_true;
SELECT 1 IS NULL AS is_null_false;
SELECT '' IS NULL AS empty_str_is_null;

SELECT 1 IS NOT NULL AS is_not_null_true;
SELECT NULL IS NOT NULL AS is_not_null_false;

-- ----------------------------------------------------------------------------
-- P2: IS DISTINCT FROM / IS NOT DISTINCT FROM
-- TODO: Verify NULL-safe equality support
-- ----------------------------------------------------------------------------

SELECT 1 IS DISTINCT FROM 2 AS distinct_diff;
SELECT 1 IS DISTINCT FROM 1 AS distinct_same;
SELECT 1 IS DISTINCT FROM NULL AS distinct_null;
SELECT NULL IS DISTINCT FROM NULL AS distinct_both_null;

SELECT 1 IS NOT DISTINCT FROM 1 AS not_distinct_same;
SELECT 1 IS NOT DISTINCT FROM 2 AS not_distinct_diff;
SELECT 1 IS NOT DISTINCT FROM NULL AS not_distinct_null;
SELECT NULL IS NOT DISTINCT FROM NULL AS not_distinct_both_null;

-- ----------------------------------------------------------------------------
-- P2: IS TRUE / IS FALSE / IS UNKNOWN
-- TODO: Verify three-valued boolean predicate support
-- ----------------------------------------------------------------------------

SELECT TRUE IS TRUE AS is_true_t;
SELECT FALSE IS TRUE AS is_true_f;
SELECT NULL::boolean IS TRUE AS is_true_null;

SELECT FALSE IS FALSE AS is_false_f;
SELECT TRUE IS FALSE AS is_false_t;
SELECT NULL::boolean IS FALSE AS is_false_null;

SELECT NULL::boolean IS UNKNOWN AS is_unknown_null;
SELECT TRUE IS UNKNOWN AS is_unknown_true;
SELECT FALSE IS UNKNOWN AS is_unknown_false;

-- Negated forms
SELECT FALSE IS NOT TRUE AS is_not_true;
SELECT TRUE IS NOT FALSE AS is_not_false;
SELECT TRUE IS NOT UNKNOWN AS is_not_unknown;
