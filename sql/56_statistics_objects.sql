-- =============================================================================
-- Section 12.13: Extended Statistics
-- =============================================================================

-- =============================================================================
-- Pre-cleanup
-- =============================================================================

DROP STATISTICS IF EXISTS stats_deps, stats_ndistinct, stats_mcv;
DROP TABLE IF EXISTS stats_test CASCADE;

-- =============================================================================
-- Setup
-- =============================================================================

CREATE TABLE stats_test (
    id   serial PRIMARY KEY,
    city text,
    zip  text,
    age  int
);
INSERT INTO stats_test (city, zip, age)
SELECT
    CASE (i % 3) WHEN 0 THEN 'Tokyo' WHEN 1 THEN 'Osaka' ELSE 'Nagoya' END,
    LPAD((i % 100)::text, 5, '0'),
    20 + (i % 50)
FROM generate_series(1, 1000) AS s(i);
ANALYZE stats_test;

-- =============================================================================
-- TODO [P4]: CREATE STATISTICS (dependencies) — functional dependency stats
-- =============================================================================

CREATE STATISTICS stats_dep (dependencies) ON city, zip FROM stats_test;
ANALYZE stats_test;

-- =============================================================================
-- TODO [P4]: CREATE STATISTICS (ndistinct) — n-distinct stats
-- =============================================================================

CREATE STATISTICS stats_nd (ndistinct) ON city, age FROM stats_test;
ANALYZE stats_test;

-- =============================================================================
-- TODO [P4]: CREATE STATISTICS (mcv) — most common values stats
-- =============================================================================

CREATE STATISTICS stats_mcv (mcv) ON city, zip FROM stats_test;
ANALYZE stats_test;

-- =============================================================================
-- TODO [P4]: pg_stats_ext — view extended statistics
-- =============================================================================

SELECT statistics_name, attnames, kinds FROM pg_stats_ext WHERE statistics_name LIKE 'stats_%';

-- =============================================================================
-- TODO [P4]: EXPLAIN to verify statistics usage
-- =============================================================================

EXPLAIN SELECT * FROM stats_test WHERE city = 'Tokyo' AND zip = '00000';

-- =============================================================================
-- TODO [P4]: ALTER STATISTICS / DROP STATISTICS
-- =============================================================================

ALTER STATISTICS stats_dep SET STATISTICS 1000;
DROP STATISTICS stats_dep;
DROP STATISTICS stats_nd;
DROP STATISTICS stats_mcv;

-- =============================================================================
-- Cleanup
-- =============================================================================

DROP TABLE stats_test;
