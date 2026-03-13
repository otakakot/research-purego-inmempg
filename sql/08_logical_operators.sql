-- ============================================================================
-- Section 3.2: Logical Operators
-- ============================================================================
-- TODO: Verify three-valued logic with NULL propagation
-- Priority: P1

-- ----------------------------------------------------------------------------
-- P1: AND — truth table including NULL
-- ----------------------------------------------------------------------------

-- AND: TRUE combinations
SELECT TRUE AND TRUE AS and_tt;
SELECT TRUE AND FALSE AS and_tf;
SELECT FALSE AND TRUE AS and_ft;
SELECT FALSE AND FALSE AS and_ff;

-- AND: NULL combinations
SELECT TRUE AND NULL AS and_tn;
SELECT NULL AND TRUE AS and_nt;
SELECT FALSE AND NULL AS and_fn;
SELECT NULL AND FALSE AS and_nf;
SELECT NULL AND NULL AS and_nn;

-- ----------------------------------------------------------------------------
-- P1: OR — truth table including NULL
-- ----------------------------------------------------------------------------

SELECT TRUE OR TRUE AS or_tt;
SELECT TRUE OR FALSE AS or_tf;
SELECT FALSE OR TRUE AS or_ft;
SELECT FALSE OR FALSE AS or_ff;

-- OR: NULL combinations
SELECT TRUE OR NULL AS or_tn;
SELECT NULL OR TRUE AS or_nt;
SELECT FALSE OR NULL AS or_fn;
SELECT NULL OR FALSE AS or_nf;
SELECT NULL OR NULL AS or_nn;

-- ----------------------------------------------------------------------------
-- P1: NOT — including NULL
-- ----------------------------------------------------------------------------

SELECT NOT TRUE AS not_t;
SELECT NOT FALSE AS not_f;
SELECT NOT NULL AS not_n;

-- ----------------------------------------------------------------------------
-- P1: Compound expressions
-- TODO: Verify operator precedence (NOT > AND > OR)
-- ----------------------------------------------------------------------------

-- NOT binds tighter than AND
SELECT NOT FALSE AND FALSE AS precedence_not_and;  -- (NOT FALSE) AND FALSE = FALSE

-- AND binds tighter than OR
SELECT TRUE OR FALSE AND FALSE AS precedence_and_or;  -- TRUE OR (FALSE AND FALSE) = TRUE

-- Parentheses override precedence
SELECT (TRUE OR FALSE) AND FALSE AS parens_override;  -- FALSE

-- Complex expression with NULLs
SELECT NOT (NULL AND TRUE) OR FALSE AS complex_null_expr;
