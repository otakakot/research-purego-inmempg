-- ============================================================================
-- Section 3.4: String Operators
-- ============================================================================
-- TODO: Verify string operator support and pattern matching
-- Priority levels noted per operator group

-- ----------------------------------------------------------------------------
-- P1: || (string concatenation)
-- ----------------------------------------------------------------------------

SELECT 'hello' || ' ' || 'world' AS concat_basic;
SELECT 'foo' || '' AS concat_empty;
SELECT '' || '' AS concat_both_empty;
SELECT 'value: ' || 42 AS concat_int_cast;
SELECT 'pi=' || 3.14 AS concat_float_cast;

-- NULL propagation
SELECT 'hello' || NULL AS concat_null;
SELECT NULL || 'world' AS concat_null_left;
SELECT NULL || NULL AS concat_null_both;

-- ----------------------------------------------------------------------------
-- P1: LIKE / NOT LIKE
-- TODO: Verify LIKE pattern matching with % and _ wildcards
-- ----------------------------------------------------------------------------

SELECT 'hello' LIKE 'hello' AS like_exact;
SELECT 'hello' LIKE 'hell%' AS like_prefix;
SELECT 'hello' LIKE '%ello' AS like_suffix;
SELECT 'hello' LIKE '%ell%' AS like_contains;
SELECT 'hello' LIKE 'h_llo' AS like_single;
SELECT 'hello' LIKE 'H%' AS like_case_sensitive;

SELECT 'hello' NOT LIKE 'world%' AS not_like_true;
SELECT 'hello' NOT LIKE 'hell%' AS not_like_false;

-- LIKE with escape
SELECT 'a%b' LIKE 'a\%b' ESCAPE '\' AS like_escape_pct;
SELECT 'a_b' LIKE 'a\_b' ESCAPE '\' AS like_escape_under;

-- LIKE with NULL
SELECT NULL LIKE '%' AS like_null_val;
SELECT 'hello' LIKE NULL AS like_null_pattern;

-- ----------------------------------------------------------------------------
-- P1: ILIKE / NOT ILIKE (case-insensitive LIKE)
-- TODO: Verify case-insensitive pattern matching
-- ----------------------------------------------------------------------------

SELECT 'Hello' ILIKE 'hello' AS ilike_exact;
SELECT 'HELLO' ILIKE 'h%' AS ilike_prefix;
SELECT 'Hello World' ILIKE '%WORLD' AS ilike_suffix;

SELECT 'Hello' NOT ILIKE 'hello' AS not_ilike_match;
SELECT 'Hello' NOT ILIKE 'xyz%' AS not_ilike_nomatch;

-- ----------------------------------------------------------------------------
-- P2: SIMILAR TO
-- TODO: Verify SQL-standard regex pattern support
-- ----------------------------------------------------------------------------

SELECT 'abc' SIMILAR TO 'abc' AS similar_exact;
SELECT 'abc' SIMILAR TO '%(b|d)%' AS similar_alt;
SELECT 'abc' SIMILAR TO 'a%' AS similar_prefix;
SELECT 'abc' SIMILAR TO '[a-z]{3}' AS similar_range;

SELECT 'abc' NOT SIMILAR TO '[0-9]+' AS not_similar;

-- ----------------------------------------------------------------------------
-- P2: POSIX regular expression operators (~ ~* !~ !~*)
-- TODO: Verify POSIX regex operator support
-- ----------------------------------------------------------------------------

-- ~ case-sensitive match
SELECT 'hello' ~ 'ell' AS regex_match;
SELECT 'hello' ~ '^h' AS regex_anchor_start;
SELECT 'hello' ~ 'o$' AS regex_anchor_end;
SELECT 'Hello' ~ 'hello' AS regex_case_mismatch;

-- ~* case-insensitive match
SELECT 'Hello' ~* 'hello' AS regex_icase_match;
SELECT 'HELLO' ~* '^h' AS regex_icase_anchor;

-- !~ negated case-sensitive match
SELECT 'hello' !~ 'xyz' AS regex_not_match;
SELECT 'hello' !~ 'ell' AS regex_not_match_false;

-- !~* negated case-insensitive match
SELECT 'Hello' !~* 'xyz' AS regex_not_icase;
SELECT 'Hello' !~* 'hello' AS regex_not_icase_false;

-- Regex patterns
SELECT 'abc123' ~ '[0-9]+' AS regex_digits;
SELECT 'foo bar' ~ '\bbar\b' AS regex_word_boundary;
SELECT '2024-01-15' ~ '^\d{4}-\d{2}-\d{2}$' AS regex_date_pattern;

-- ----------------------------------------------------------------------------
-- P2: ^@ (starts_with operator)
-- TODO: Verify starts_with operator support (PostgreSQL 11+)
-- ----------------------------------------------------------------------------

SELECT 'hello world' ^@ 'hello' AS starts_with_true;
SELECT 'hello world' ^@ 'world' AS starts_with_false;
SELECT 'hello' ^@ '' AS starts_with_empty;
SELECT '' ^@ '' AS starts_with_both_empty;
SELECT 'hello' ^@ 'hello world' AS starts_with_longer;
