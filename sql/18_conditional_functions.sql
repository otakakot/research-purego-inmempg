-- =============================================================================
-- Section 4.6: Conditional Functions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TODO [P1] CASE WHEN, COALESCE, NULLIF, GREATEST, LEAST
-- -----------------------------------------------------------------------------

-- CASE WHEN ... THEN ... ELSE ... END (searched form)
SELECT
    val,
    CASE
        WHEN val < 0  THEN 'negative'
        WHEN val = 0  THEN 'zero'
        WHEN val > 0  THEN 'positive'
        ELSE 'null'
    END AS sign_label
FROM (VALUES (10), (-5), (0), (NULL)) AS t(val);

-- CASE expr WHEN ... (simple form)
SELECT
    status,
    CASE status
        WHEN 1 THEN 'active'
        WHEN 2 THEN 'inactive'
        WHEN 3 THEN 'banned'
        ELSE 'unknown'
    END AS status_label
FROM (VALUES (1), (2), (3), (99)) AS t(status);

-- COALESCE: return first non-NULL argument
SELECT COALESCE(NULL, NULL, 'fallback') AS coal_str;
SELECT COALESCE(NULL, 42, 99) AS coal_int;
SELECT COALESCE(1, 2, 3) AS coal_first;

-- NULLIF: return NULL if the two arguments are equal
SELECT NULLIF(10, 10) AS nullif_equal;
SELECT NULLIF(10, 20) AS nullif_diff;

-- GREATEST / LEAST with mixed expressions
SELECT GREATEST(1, 2, 3, 4, 5) AS g_int, LEAST(1, 2, 3, 4, 5) AS l_int;
SELECT GREATEST('a', 'z', 'm') AS g_text, LEAST('a', 'z', 'm') AS l_text;

-- NULL handling in GREATEST / LEAST
SELECT GREATEST(1, NULL, 3) AS g_with_null, LEAST(1, NULL, 3) AS l_with_null;
