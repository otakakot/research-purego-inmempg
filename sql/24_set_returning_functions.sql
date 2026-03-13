-- =============================================================================
-- Section 4.12: Set-Returning Functions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TODO [P2] generate_series for integers and timestamps
-- -----------------------------------------------------------------------------

-- generate_series(start, stop) — integer, inclusive
SELECT * FROM generate_series(1, 5);

-- generate_series(start, stop, step) — integer with step
SELECT * FROM generate_series(0, 20, 5);

-- generate_series with negative step (descending)
SELECT * FROM generate_series(5, 1, -1);

-- generate_series in a SELECT expression
SELECT g AS num, g * g AS square FROM generate_series(1, 10) AS g;

-- generate_series with timestamps
SELECT * FROM generate_series(
    TIMESTAMP '2024-01-01',
    TIMESTAMP '2024-01-07',
    INTERVAL '1 day'
);

-- generate_series with timestamps and hourly interval
SELECT * FROM generate_series(
    TIMESTAMP '2024-06-15 00:00:00',
    TIMESTAMP '2024-06-15 06:00:00',
    INTERVAL '2 hours'
);

-- Practical: generate a date series and use it for a calendar-like query
SELECT
    d::DATE AS date,
    extract(DOW FROM d) AS day_of_week,
    to_char(d, 'Day') AS day_name
FROM generate_series(
    DATE '2024-06-10',
    DATE '2024-06-16',
    INTERVAL '1 day'
) AS d;

-- -----------------------------------------------------------------------------
-- TODO [P3] generate_subscripts
-- -----------------------------------------------------------------------------

-- generate_subscripts(array, dimension)
SELECT generate_subscripts(ARRAY[10,20,30,40], 1) AS idx;

-- Practical: iterate over array elements with indices
SELECT
    idx,
    (ARRAY['alpha','bravo','charlie','delta'])[idx] AS elem
FROM generate_subscripts(ARRAY['alpha','bravo','charlie','delta'], 1) AS idx;

-- generate_subscripts with 2D array
SELECT generate_subscripts(ARRAY[[1,2],[3,4],[5,6]], 1) AS row_idx;
SELECT generate_subscripts(ARRAY[[1,2],[3,4],[5,6]], 2) AS col_idx;
