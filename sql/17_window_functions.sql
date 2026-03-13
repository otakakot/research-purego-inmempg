-- =============================================================================
-- Section 4.5: Window Functions
-- =============================================================================

-- Setup: create and populate test table
DROP TABLE IF EXISTS win_test;
CREATE TABLE win_test (
    id         SERIAL PRIMARY KEY,
    department TEXT NOT NULL,
    employee   TEXT NOT NULL,
    salary     INTEGER NOT NULL
);

INSERT INTO win_test (department, employee, salary) VALUES
    ('Engineering', 'Alice',   120000),
    ('Engineering', 'Bob',     110000),
    ('Engineering', 'Charlie', 120000),
    ('Sales',       'Diana',    90000),
    ('Sales',       'Eve',      85000),
    ('Sales',       'Frank',    90000),
    ('HR',          'Grace',    95000),
    ('HR',          'Heidi',   100000);

-- -----------------------------------------------------------------------------
-- TODO [P2] row_number, rank, dense_rank, ntile, lag, lead, first_value,
--           last_value, nth_value
-- -----------------------------------------------------------------------------

-- row_number()
SELECT
    employee, department, salary,
    row_number() OVER (ORDER BY salary DESC) AS rn
FROM win_test;

-- row_number() with PARTITION BY
SELECT
    employee, department, salary,
    row_number() OVER (PARTITION BY department ORDER BY salary DESC) AS rn_dept
FROM win_test;

-- rank()
SELECT
    employee, department, salary,
    rank() OVER (ORDER BY salary DESC) AS rnk
FROM win_test;

-- dense_rank()
SELECT
    employee, department, salary,
    dense_rank() OVER (ORDER BY salary DESC) AS drnk
FROM win_test;

-- ntile(n)
SELECT
    employee, salary,
    ntile(3) OVER (ORDER BY salary DESC) AS tile3
FROM win_test;

-- lag(value, offset, default)
SELECT
    employee, salary,
    lag(salary, 1) OVER (ORDER BY salary DESC) AS prev_salary,
    lag(salary, 1, 0) OVER (ORDER BY salary DESC) AS prev_salary_default
FROM win_test;

-- lead(value, offset, default)
SELECT
    employee, salary,
    lead(salary, 1) OVER (ORDER BY salary DESC) AS next_salary,
    lead(salary, 1, 0) OVER (ORDER BY salary DESC) AS next_salary_default
FROM win_test;

-- first_value / last_value
SELECT
    employee, department, salary,
    first_value(employee) OVER (
        PARTITION BY department ORDER BY salary DESC
    ) AS top_earner,
    last_value(employee) OVER (
        PARTITION BY department ORDER BY salary DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS lowest_earner
FROM win_test;

-- nth_value
SELECT
    employee, department, salary,
    nth_value(employee, 2) OVER (
        PARTITION BY department ORDER BY salary DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS second_earner
FROM win_test;

-- -----------------------------------------------------------------------------
-- TODO [P3] percent_rank, cume_dist
-- -----------------------------------------------------------------------------

-- percent_rank()
SELECT
    employee, salary,
    percent_rank() OVER (ORDER BY salary) AS pct_rank
FROM win_test;

-- cume_dist()
SELECT
    employee, salary,
    cume_dist() OVER (ORDER BY salary) AS cume
FROM win_test;

-- Cleanup
DROP TABLE IF EXISTS win_test;
