-- =============================================================================
-- Section 1.2: Data Manipulation Language (DML)
-- Verification tests for pure-Go in-memory PostgreSQL implementation
-- =============================================================================

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_dml_orders CASCADE;
DROP TABLE IF EXISTS test_dml_products CASCADE;
DROP TABLE IF EXISTS test_dml_users CASCADE;
DROP TABLE IF EXISTS test_select_into CASCADE;

-- =====================
-- Setup: create test tables
-- =====================
CREATE TABLE test_dml_users (
    id         SERIAL PRIMARY KEY,
    username   VARCHAR(100) NOT NULL UNIQUE,
    email      VARCHAR(255) NOT NULL,
    age        INTEGER,
    is_active  BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE test_dml_products (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL UNIQUE,
    price      NUMERIC(10, 2) NOT NULL,
    stock      INTEGER DEFAULT 0
);

CREATE TABLE test_dml_orders (
    id         SERIAL PRIMARY KEY,
    user_id    INTEGER REFERENCES test_dml_users(id),
    product_id INTEGER REFERENCES test_dml_products(id),
    quantity   INTEGER NOT NULL,
    total      NUMERIC(10, 2),
    ordered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================
-- [P1] INSERT — basic single-row and multi-row inserts
-- =====================
INSERT INTO test_dml_users (username, email, age) VALUES ('alice', 'alice@example.com', 30);
INSERT INTO test_dml_users (username, email, age) VALUES ('bob', 'bob@example.com', 25);
INSERT INTO test_dml_users (username, email, age) VALUES ('carol', 'carol@example.com', 28);

INSERT INTO test_dml_products (name, price, stock) VALUES
    ('Widget', 9.99, 100),
    ('Gadget', 24.99, 50),
    ('Doohickey', 4.50, 200);

-- =====================
-- [P1] SELECT — basic queries
-- =====================

-- Select all rows
SELECT * FROM test_dml_users;

-- Select with WHERE
SELECT username, email FROM test_dml_users WHERE age > 26;

-- Select with ORDER BY
SELECT * FROM test_dml_users ORDER BY age DESC;

-- Select with LIMIT / OFFSET
SELECT * FROM test_dml_users ORDER BY id LIMIT 2 OFFSET 1;

-- Select with aggregate functions
SELECT COUNT(*) AS total_users FROM test_dml_users;
SELECT AVG(age) AS avg_age, MIN(age) AS min_age, MAX(age) AS max_age FROM test_dml_users;

-- Select with GROUP BY / HAVING
SELECT is_active, COUNT(*) AS cnt
FROM test_dml_users
GROUP BY is_active
HAVING COUNT(*) > 0;

-- Select with DISTINCT
SELECT DISTINCT is_active FROM test_dml_users;

-- Select with subquery
SELECT * FROM test_dml_users WHERE age = (SELECT MAX(age) FROM test_dml_users);

-- Select with JOIN
INSERT INTO test_dml_orders (user_id, product_id, quantity, total) VALUES (1, 1, 2, 19.98);
INSERT INTO test_dml_orders (user_id, product_id, quantity, total) VALUES (1, 2, 1, 24.99);
INSERT INTO test_dml_orders (user_id, product_id, quantity, total) VALUES (2, 3, 5, 22.50);

SELECT u.username, p.name AS product, o.quantity, o.total
FROM test_dml_orders o
JOIN test_dml_users u ON o.user_id = u.id
JOIN test_dml_products p ON o.product_id = p.id
ORDER BY u.username, p.name;

-- Select with LEFT JOIN
SELECT u.username, o.id AS order_id
FROM test_dml_users u
LEFT JOIN test_dml_orders o ON u.id = o.user_id
ORDER BY u.username;

-- Select with CASE expression
SELECT username,
       CASE WHEN age >= 28 THEN 'senior' ELSE 'junior' END AS category
FROM test_dml_users;

-- Select with EXISTS
SELECT username FROM test_dml_users u
WHERE EXISTS (SELECT 1 FROM test_dml_orders o WHERE o.user_id = u.id);

-- Select with IN
SELECT * FROM test_dml_users WHERE username IN ('alice', 'carol');

-- Select with BETWEEN
SELECT * FROM test_dml_users WHERE age BETWEEN 25 AND 29;

-- Select with LIKE / ILIKE
SELECT * FROM test_dml_users WHERE email LIKE '%@example.com';
SELECT * FROM test_dml_users WHERE username ILIKE 'A%';

-- Select with COALESCE / NULLIF
SELECT COALESCE(NULL, 'fallback') AS coalesce_test;
SELECT NULLIF(1, 1) AS nullif_null, NULLIF(1, 2) AS nullif_value;

-- Select with CTE (Common Table Expression)
WITH active_users AS (
    SELECT * FROM test_dml_users WHERE is_active = TRUE
)
SELECT username FROM active_users ORDER BY username;

-- Select with UNION / INTERSECT / EXCEPT
SELECT username FROM test_dml_users WHERE age > 27
UNION
SELECT username FROM test_dml_users WHERE username = 'bob';

SELECT username FROM test_dml_users WHERE age > 24
INTERSECT
SELECT username FROM test_dml_users WHERE is_active = TRUE;

SELECT username FROM test_dml_users
EXCEPT
SELECT username FROM test_dml_users WHERE age < 28;

-- =====================
-- [P1] UPDATE — basic updates
-- =====================
UPDATE test_dml_users SET age = 31 WHERE username = 'alice';

SELECT username, age FROM test_dml_users WHERE username = 'alice';  -- expect 31

-- Update multiple columns
UPDATE test_dml_products SET price = 11.99, stock = stock - 5 WHERE name = 'Widget';

SELECT name, price, stock FROM test_dml_products WHERE name = 'Widget';  -- expect 11.99, 95

-- Update with subquery
UPDATE test_dml_orders
SET total = quantity * (SELECT price FROM test_dml_products WHERE test_dml_products.id = test_dml_orders.product_id)
WHERE user_id = 1;

SELECT * FROM test_dml_orders WHERE user_id = 1;

-- =====================
-- [P1] DELETE — basic deletes
-- =====================
INSERT INTO test_dml_users (username, email, age) VALUES ('dave', 'dave@example.com', 40);
SELECT COUNT(*) FROM test_dml_users;  -- expect 4

DELETE FROM test_dml_users WHERE username = 'dave';
SELECT COUNT(*) FROM test_dml_users;  -- expect 3

-- Delete with subquery
DELETE FROM test_dml_orders WHERE user_id = (SELECT id FROM test_dml_users WHERE username = 'bob');
SELECT COUNT(*) FROM test_dml_orders;

-- =====================
-- [P2] INSERT ... ON CONFLICT (UPSERT)
-- =====================
INSERT INTO test_dml_products (name, price, stock) VALUES ('Widget', 12.99, 200)
ON CONFLICT (name) DO UPDATE SET price = EXCLUDED.price, stock = EXCLUDED.stock;

SELECT name, price, stock FROM test_dml_products WHERE name = 'Widget';  -- expect 12.99, 200

-- ON CONFLICT DO NOTHING
INSERT INTO test_dml_products (name, price, stock) VALUES ('Widget', 99.99, 999)
ON CONFLICT (name) DO NOTHING;

SELECT name, price, stock FROM test_dml_products WHERE name = 'Widget';  -- still 12.99, 200

-- =====================
-- [P2] INSERT ... RETURNING
-- =====================
INSERT INTO test_dml_users (username, email, age) VALUES ('eve', 'eve@example.com', 22)
RETURNING id, username;

-- =====================
-- [P2] UPDATE ... RETURNING
-- =====================
UPDATE test_dml_users SET age = 23 WHERE username = 'eve'
RETURNING id, username, age;

-- =====================
-- [P2] DELETE ... RETURNING
-- =====================
DELETE FROM test_dml_users WHERE username = 'eve'
RETURNING id, username;

-- =====================
-- [P3] MERGE (PostgreSQL 15+)
-- =====================
-- Re-insert a row for merge testing
INSERT INTO test_dml_products (name, price, stock) VALUES ('Thingamajig', 7.99, 30);

MERGE INTO test_dml_products AS target
USING (VALUES ('Widget', 14.99, 150), ('NewItem', 3.99, 500)) AS source(name, price, stock)
ON target.name = source.name
WHEN MATCHED THEN
    UPDATE SET price = source.price, stock = source.stock
WHEN NOT MATCHED THEN
    INSERT (name, price, stock) VALUES (source.name, source.price, source.stock);

SELECT name, price, stock FROM test_dml_products ORDER BY name;

-- =====================
-- [P2] COPY — export and import (uses STDOUT/STDIN for testing)
-- =====================
-- COPY to stdout (verify the command is accepted)
COPY test_dml_users TO STDOUT WITH (FORMAT csv, HEADER);

-- COPY from inline data using the COPY ... FROM STDIN pattern
-- Note: actual STDIN interaction depends on client; this tests parser acceptance
COPY test_dml_products (name, price, stock) FROM STDIN WITH (FORMAT csv);
TestCopy,1.99,10
\.

SELECT * FROM test_dml_products WHERE name = 'TestCopy';

-- =====================
-- [P2] SELECT INTO
-- =====================
SELECT id, username, email
INTO test_select_into
FROM test_dml_users
WHERE is_active = TRUE;

SELECT * FROM test_select_into;

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_select_into;
DROP TABLE IF EXISTS test_dml_orders CASCADE;
DROP TABLE IF EXISTS test_dml_products CASCADE;
DROP TABLE IF EXISTS test_dml_users CASCADE;
