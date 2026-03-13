-- =============================================================================
-- Section 5.1: SELECT Syntax Components
-- =============================================================================

-- Setup
CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    name  TEXT NOT NULL,
    category TEXT,
    price NUMERIC(10, 2),
    stock INT
);

INSERT INTO products (name, category, price, stock) VALUES
    ('Widget A', 'gadgets', 19.99, 100),
    ('Widget B', 'gadgets', 29.99, 50),
    ('Gizmo X',  'tools',   9.99,  200),
    ('Gizmo Y',  'tools',   9.99,  NULL),
    ('Thingo',   'gadgets', 49.99, 10),
    ('Doodad',   NULL,      5.00,  300);

-- TODO [P1]: SELECT * — select all columns
SELECT * FROM products;

-- TODO [P1]: SELECT expr — select specific columns / expressions
SELECT name, price * 1.1 AS price_with_tax FROM products;

-- TODO [P1]: SELECT DISTINCT — eliminate duplicate rows
SELECT DISTINCT category FROM products;

-- TODO [P1]: FROM clause
SELECT p.name FROM products p;

-- TODO [P1]: WHERE clause — filter rows
SELECT * FROM products WHERE price > 10;

-- TODO [P1]: GROUP BY — aggregate grouping
SELECT category, COUNT(*) AS cnt, AVG(price) AS avg_price
FROM products
GROUP BY category;

-- TODO [P1]: HAVING — filter groups
SELECT category, SUM(stock) AS total_stock
FROM products
GROUP BY category
HAVING SUM(stock) > 100;

-- TODO [P1]: ORDER BY — sort results
SELECT * FROM products ORDER BY price DESC, name ASC;

-- TODO [P1]: LIMIT — restrict number of rows returned
SELECT * FROM products ORDER BY price LIMIT 3;

-- TODO [P1]: FETCH FIRST — SQL-standard alternative to LIMIT
SELECT * FROM products ORDER BY price FETCH FIRST 3 ROWS ONLY;

-- TODO [P1]: OFFSET — skip rows
SELECT * FROM products ORDER BY id OFFSET 2 LIMIT 2;

-- TODO [P1]: Table alias (AS)
SELECT p.name, p.price FROM products AS p WHERE p.stock IS NOT NULL;

-- TODO [P2]: SELECT DISTINCT ON — deduplicate by specific columns
SELECT DISTINCT ON (category) category, name, price
FROM products
ORDER BY category, price DESC;

-- TODO [P2]: ORDER BY ... NULLS FIRST
SELECT * FROM products ORDER BY stock ASC NULLS FIRST;

-- TODO [P2]: ORDER BY ... NULLS LAST
SELECT * FROM products ORDER BY stock DESC NULLS LAST;

-- Cleanup
DROP TABLE products;
