-- =============================================================================
-- Section 4.4: Aggregate Functions
-- =============================================================================

-- Setup: create and populate test table
DROP TABLE IF EXISTS agg_test;
CREATE TABLE agg_test (
    id       SERIAL PRIMARY KEY,
    category TEXT NOT NULL,
    val      INTEGER,
    score    NUMERIC(5,2),
    flag     BOOLEAN,
    name     TEXT
);

INSERT INTO agg_test (category, val, score, flag, name) VALUES
    ('A', 10,  1.5,  TRUE,  'alpha'),
    ('A', 20,  2.5,  TRUE,  'bravo'),
    ('A', 30,  3.5,  FALSE, 'charlie'),
    ('B', 40,  4.5,  TRUE,  'delta'),
    ('B', 50,  5.5,  FALSE, 'echo'),
    ('B', NULL, 6.5,  NULL,  'foxtrot'),
    ('C', 60,  NULL, TRUE,  'golf'),
    ('C', 70,  8.5,  TRUE,  'hotel');

-- -----------------------------------------------------------------------------
-- TODO [P1] count, sum, avg, min, max
-- -----------------------------------------------------------------------------

-- count(*) vs count(expr) — NULL handling
SELECT count(*) AS cnt_all, count(val) AS cnt_val FROM agg_test;

-- sum
SELECT sum(val) AS sum_val FROM agg_test;
SELECT category, sum(val) AS sum_by_cat FROM agg_test GROUP BY category ORDER BY category;

-- avg
SELECT avg(val) AS avg_val FROM agg_test;
SELECT category, avg(val) AS avg_by_cat FROM agg_test GROUP BY category ORDER BY category;

-- min / max
SELECT min(val) AS min_val, max(val) AS max_val FROM agg_test;
SELECT min(name) AS min_name, max(name) AS max_name FROM agg_test;

-- -----------------------------------------------------------------------------
-- TODO [P2] bool_and, bool_or, every, array_agg, string_agg,
--           json_agg, jsonb_agg, json_object_agg, jsonb_object_agg
-- -----------------------------------------------------------------------------

-- bool_and / bool_or / every
SELECT bool_and(flag) AS band, bool_or(flag) AS bor FROM agg_test;
SELECT category, every(flag) AS every_flag FROM agg_test GROUP BY category ORDER BY category;

-- array_agg
SELECT array_agg(name ORDER BY name) AS names_arr FROM agg_test;
SELECT category, array_agg(val ORDER BY val) AS vals FROM agg_test GROUP BY category ORDER BY category;

-- string_agg
SELECT string_agg(name, ', ' ORDER BY name) AS names_csv FROM agg_test;
SELECT category, string_agg(name, '|' ORDER BY name) AS names
    FROM agg_test GROUP BY category ORDER BY category;

-- json_agg / jsonb_agg
SELECT json_agg(name) AS json_names FROM agg_test;
SELECT jsonb_agg(val) AS jsonb_vals FROM agg_test WHERE val IS NOT NULL;

-- json_object_agg / jsonb_object_agg
SELECT json_object_agg(name, val) AS json_obj FROM agg_test WHERE val IS NOT NULL;
SELECT jsonb_object_agg(name, score) AS jsonb_obj FROM agg_test WHERE score IS NOT NULL;

-- -----------------------------------------------------------------------------
-- TODO [P3] bit_and, bit_or, bit_xor, any_value,
--           stddev, variance, mode, percentile_cont, percentile_disc
-- -----------------------------------------------------------------------------

-- bit_and / bit_or / bit_xor
SELECT bit_and(val) AS band, bit_or(val) AS bor, bit_xor(val) AS bxor
    FROM agg_test WHERE val IS NOT NULL;

-- any_value (PostgreSQL 16+)
SELECT category, any_value(name) AS any_name
    FROM agg_test GROUP BY category ORDER BY category;

-- stddev / stddev_pop / stddev_samp
SELECT stddev(val) AS sd, stddev_pop(val) AS sd_pop, stddev_samp(val) AS sd_samp
    FROM agg_test;

-- variance / var_pop / var_samp
SELECT variance(val) AS var, var_pop(val) AS var_pop, var_samp(val) AS var_samp
    FROM agg_test;

-- mode() WITHIN GROUP (ORDER BY ...)
SELECT mode() WITHIN GROUP (ORDER BY category) AS mode_cat FROM agg_test;

-- percentile_cont / percentile_disc
SELECT
    percentile_cont(0.5) WITHIN GROUP (ORDER BY val) AS median_cont,
    percentile_disc(0.5) WITHIN GROUP (ORDER BY val) AS median_disc
FROM agg_test;

SELECT
    percentile_cont(ARRAY[0.25, 0.5, 0.75]) WITHIN GROUP (ORDER BY val) AS quartiles
FROM agg_test;

-- -----------------------------------------------------------------------------
-- TODO [P4] corr, covar_pop, covar_samp, regr_* functions
-- -----------------------------------------------------------------------------

SELECT
    corr(val, score) AS correlation,
    covar_pop(val, score) AS covar_p,
    covar_samp(val, score) AS covar_s
FROM agg_test;

SELECT
    regr_slope(val, score) AS slope,
    regr_intercept(val, score) AS intercept,
    regr_count(val, score) AS cnt,
    regr_r2(val, score) AS r2,
    regr_avgx(val, score) AS avgx,
    regr_avgy(val, score) AS avgy,
    regr_sxx(val, score) AS sxx,
    regr_sxy(val, score) AS sxy,
    regr_syy(val, score) AS syy
FROM agg_test;

-- Cleanup
DROP TABLE IF EXISTS agg_test;
