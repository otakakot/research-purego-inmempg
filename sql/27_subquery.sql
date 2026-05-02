-- =============================================================================
-- Section 5.3: Subqueries
-- =============================================================================

-- Setup
CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    amount      NUMERIC(10, 2),
    created_at  DATE DEFAULT CURRENT_DATE
);

CREATE TABLE customers (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

INSERT INTO customers (name) VALUES ('Alice'), ('Bob'), ('Charlie');
INSERT INTO orders (customer_id, amount) VALUES
    (1, 100.00), (1, 250.00),
    (2, 50.00),
    (3, 300.00), (3, 75.00);

-- TODO [P1]: Scalar subquery — single value in SELECT list
SELECT name,
       (SELECT SUM(amount) FROM orders o WHERE o.customer_id = c.id) AS total_spent
FROM customers c;

-- TODO [P1]: IN subquery — filter by a set of values
SELECT * FROM customers
WHERE id IN (SELECT customer_id FROM orders WHERE amount > 100);

-- TODO [P1]: NOT IN subquery
SELECT * FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders WHERE amount > 200);

-- TODO [P1]: EXISTS subquery — check for row existence
SELECT * FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);

-- TODO [P1]: NOT EXISTS subquery
SELECT * FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id AND o.amount > 500);

-- TODO [P1]: Subquery in FROM clause (derived table)
SELECT sub.customer_id, sub.order_count
FROM (
    SELECT customer_id, COUNT(*) AS order_count
    FROM orders
    GROUP BY customer_id
) sub
WHERE sub.order_count > 1;

-- TODO [P2]: ANY / SOME — compare against any row
SELECT * FROM orders WHERE amount > ANY (SELECT amount FROM orders WHERE customer_id = 1);

-- TODO [P2]: ALL — compare against all rows
SELECT * FROM orders WHERE amount >= ALL (SELECT amount FROM orders WHERE customer_id = 2);

-- TODO [P2]: Correlated subquery — references outer query per row
SELECT c.name,
       (SELECT MAX(o.amount) FROM orders o WHERE o.customer_id = c.id) AS max_order
FROM customers c;

-- Cleanup
DROP TABLE orders;
DROP TABLE customers;
