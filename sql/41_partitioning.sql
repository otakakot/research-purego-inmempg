-- =============================================================================
-- Section 11.3: Partitioning
-- =============================================================================

-- =============================================================================
-- TODO [P3]: RANGE partition — partition by value range
-- =============================================================================

CREATE TABLE sales_range (
    id       SERIAL,
    sale_date DATE NOT NULL,
    amount   NUMERIC(10, 2),
    region   TEXT
) PARTITION BY RANGE (sale_date);

CREATE TABLE sales_range_2023 PARTITION OF sales_range
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE sales_range_2024 PARTITION OF sales_range
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

-- Default partition for values not covered by named partitions
CREATE TABLE sales_range_default PARTITION OF sales_range DEFAULT;

INSERT INTO sales_range (sale_date, amount, region) VALUES
    ('2023-06-15', 100.00, 'East'),
    ('2024-03-20', 200.00, 'West'),
    ('2025-01-01', 50.00,  'North');  -- goes to default

-- Verify partition routing
SELECT tableoid::regclass AS partition, * FROM sales_range ORDER BY sale_date;

-- =============================================================================
-- TODO [P3]: LIST partition — partition by discrete values
-- =============================================================================

CREATE TABLE orders_list (
    id     SERIAL,
    region TEXT NOT NULL,
    amount NUMERIC(10, 2)
) PARTITION BY LIST (region);

CREATE TABLE orders_list_east PARTITION OF orders_list
    FOR VALUES IN ('East', 'Northeast');
CREATE TABLE orders_list_west PARTITION OF orders_list
    FOR VALUES IN ('West', 'Northwest');
CREATE TABLE orders_list_default PARTITION OF orders_list DEFAULT;

INSERT INTO orders_list (region, amount) VALUES
    ('East', 100), ('West', 200), ('South', 50);

SELECT tableoid::regclass AS partition, * FROM orders_list ORDER BY region;

-- =============================================================================
-- TODO [P3]: HASH partition — distribute rows evenly
-- =============================================================================

CREATE TABLE data_hash (
    id   INT NOT NULL,
    val  TEXT
) PARTITION BY HASH (id);

CREATE TABLE data_hash_0 PARTITION OF data_hash
    FOR VALUES WITH (MODULUS 3, REMAINDER 0);
CREATE TABLE data_hash_1 PARTITION OF data_hash
    FOR VALUES WITH (MODULUS 3, REMAINDER 1);
CREATE TABLE data_hash_2 PARTITION OF data_hash
    FOR VALUES WITH (MODULUS 3, REMAINDER 2);

INSERT INTO data_hash (id, val) VALUES
    (1, 'a'), (2, 'b'), (3, 'c'), (4, 'd'), (5, 'e'), (6, 'f');

SELECT tableoid::regclass AS partition, * FROM data_hash ORDER BY id;

-- Verify distribution across partitions
SELECT tableoid::regclass AS partition, COUNT(*)
FROM data_hash
GROUP BY tableoid
ORDER BY partition;

-- Cleanup
DROP TABLE sales_range;
DROP TABLE orders_list;
DROP TABLE data_hash;
