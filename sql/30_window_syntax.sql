-- =============================================================================
-- Section 5.6: Window Function Syntax
-- =============================================================================

-- Setup
CREATE TABLE sales (
    id       SERIAL PRIMARY KEY,
    region   TEXT,
    month    INT,
    revenue  NUMERIC(10, 2)
);

INSERT INTO sales (region, month, revenue) VALUES
    ('East',  1, 1000), ('East',  2, 1500), ('East',  3, 1200),
    ('West',  1, 800),  ('West',  2, 900),  ('West',  3, 1100),
    ('North', 1, 600),  ('North', 2, 700),  ('North', 3, NULL);

-- TODO [P2]: OVER (PARTITION BY ... ORDER BY ...) — partitioned window
SELECT region, month, revenue,
       SUM(revenue) OVER (PARTITION BY region ORDER BY month) AS running_total
FROM sales;

-- TODO [P2]: OVER (ORDER BY ...) — global ordered window
SELECT id, revenue,
       ROW_NUMBER() OVER (ORDER BY revenue DESC NULLS LAST) AS rn
FROM sales;

-- TODO [P2]: ROWS BETWEEN — explicit frame with ROWS
SELECT region, month, revenue,
       AVG(revenue) OVER (
           PARTITION BY region
           ORDER BY month
           ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
       ) AS moving_avg
FROM sales;

-- TODO [P3]: RANGE BETWEEN — frame based on value range
SELECT region, month, revenue,
       SUM(revenue) OVER (
           PARTITION BY region
           ORDER BY month
           RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS range_sum
FROM sales;

-- TODO [P3]: GROUPS BETWEEN — frame based on peer groups
SELECT region, month, revenue,
       SUM(revenue) OVER (
           ORDER BY month
           GROUPS BETWEEN 1 PRECEDING AND 1 FOLLOWING
       ) AS group_sum
FROM sales;

-- TODO [P3]: Named window — WINDOW w AS (...)
SELECT region, month, revenue,
       SUM(revenue)   OVER w AS running_sum,
       COUNT(revenue) OVER w AS running_count
FROM sales
WINDOW w AS (PARTITION BY region ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW);

-- TODO [P4]: EXCLUDE specification — ROWS ... EXCLUDE CURRENT ROW
SELECT region, month, revenue,
       AVG(revenue) OVER (
           PARTITION BY region
           ORDER BY month
           ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
           EXCLUDE CURRENT ROW
       ) AS avg_neighbours
FROM sales;

-- TODO [P4]: EXCLUDE TIES
SELECT region, month, revenue,
       SUM(revenue) OVER (
           ORDER BY month
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           EXCLUDE TIES
       ) AS sum_excl_ties
FROM sales;

-- Cleanup
DROP TABLE sales;
