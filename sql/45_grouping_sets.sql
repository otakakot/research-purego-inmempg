-- =============================================================================
-- Section 12.2: Grouping Sets
-- =============================================================================

-- Setup
CREATE TABLE sales (
    id         SERIAL PRIMARY KEY,
    department TEXT,
    category   TEXT,
    region     TEXT,
    amount     NUMERIC(10,2)
);

INSERT INTO sales (department, category, region, amount) VALUES
    ('Engineering', 'Hardware',  'East',  1500.00),
    ('Engineering', 'Hardware',  'West',  2300.00),
    ('Engineering', 'Software',  'East',  3200.00),
    ('Sales',       'Hardware',  'East',   800.00),
    ('Sales',       'Software',  'West',  1100.00),
    ('Sales',       'Software',  'East',   950.00),
    ('Marketing',   'Hardware',  'West',   600.00),
    ('Marketing',   'Software',  'East',  1400.00);

-- TODO [P2]: GROUP BY ROLLUP — hierarchical subtotals (department, category)
-- Generates: (department, category), (department), ()
SELECT department, category, SUM(amount) AS total
FROM sales
GROUP BY ROLLUP (department, category)
ORDER BY department NULLS LAST, category NULLS LAST;

-- TODO [P2]: GROUP BY CUBE — all combination subtotals (department, category)
-- Generates: (department, category), (department), (category), ()
SELECT department, category, SUM(amount) AS total
FROM sales
GROUP BY CUBE (department, category)
ORDER BY department NULLS LAST, category NULLS LAST;

-- TODO [P2]: GROUP BY GROUPING SETS — explicit grouping sets
SELECT department, category, SUM(amount) AS total
FROM sales
GROUP BY GROUPING SETS ((department), (category), ())
ORDER BY department NULLS LAST, category NULLS LAST;

-- TODO [P2]: GROUPING() function — identify which columns are aggregated
-- Returns 0 when the column is part of the grouping, 1 when aggregated away
SELECT
    department,
    category,
    GROUPING(department) AS grp_dept,
    GROUPING(category)   AS grp_cat,
    SUM(amount)           AS total
FROM sales
GROUP BY ROLLUP (department, category)
ORDER BY department NULLS LAST, category NULLS LAST;

-- TODO [P3]: Combined GROUPING SETS with regular GROUP BY (Cartesian product)
-- GROUP BY region, ROLLUP (department) produces:
--   (region, department), (region)
SELECT region, department, SUM(amount) AS total
FROM sales
GROUP BY region, ROLLUP (department)
ORDER BY region, department NULLS LAST;

-- TODO [P3]: Nested ROLLUP/CUBE within GROUPING SETS
SELECT department, category, region, SUM(amount) AS total
FROM sales
GROUP BY GROUPING SETS (
    ROLLUP (department, category),
    (region)
)
ORDER BY department NULLS LAST, category NULLS LAST, region NULLS LAST;

-- Cleanup
DROP TABLE sales;
