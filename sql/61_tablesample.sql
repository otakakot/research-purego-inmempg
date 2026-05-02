-- =============================================================================
-- Section 12.18: TABLESAMPLE
-- =============================================================================

-- =============================================================================
-- Setup
-- =============================================================================

CREATE TABLE sample_data (
    id  serial PRIMARY KEY,
    val double precision,
    cat text
);
INSERT INTO sample_data (val, cat)
SELECT random(), CASE (g % 5)
    WHEN 0 THEN 'alpha'
    WHEN 1 THEN 'beta'
    WHEN 2 THEN 'gamma'
    WHEN 3 THEN 'delta'
    ELSE 'epsilon'
END
FROM generate_series(1, 5000) AS s(g);

-- =============================================================================
-- TODO [P4]: TABLESAMPLE BERNOULLI — row-level sampling
-- =============================================================================

SELECT COUNT(*) AS bernoulli_count FROM sample_data TABLESAMPLE BERNOULLI (10);

-- =============================================================================
-- TODO [P4]: TABLESAMPLE SYSTEM — block-level sampling
-- =============================================================================

SELECT COUNT(*) AS system_count FROM sample_data TABLESAMPLE SYSTEM (10);

-- =============================================================================
-- TODO [P4]: REPEATABLE (seed) — reproducible sampling
-- =============================================================================

SELECT COUNT(*) AS rep1 FROM sample_data TABLESAMPLE BERNOULLI (5) REPEATABLE (42);
SELECT COUNT(*) AS rep2 FROM sample_data TABLESAMPLE BERNOULLI (5) REPEATABLE (42);

-- =============================================================================
-- TODO [P4]: TABLESAMPLE with WHERE clause
-- =============================================================================

SELECT COUNT(*) AS filtered_sample
FROM sample_data TABLESAMPLE BERNOULLI (20)
WHERE cat = 'alpha';

-- =============================================================================
-- Cleanup
-- =============================================================================

DROP TABLE sample_data;
