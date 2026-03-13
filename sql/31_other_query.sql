-- =============================================================================
-- Section 5.7: Other Query Features
-- =============================================================================

-- Setup
CREATE TABLE items (
    id    SERIAL PRIMARY KEY,
    name  TEXT NOT NULL,
    tag   TEXT,
    price NUMERIC(10, 2)
);

INSERT INTO items (name, tag, price) VALUES
    ('Alpha',   'hot',  10.00),
    ('Beta',    'cold', 20.00),
    ('Gamma',   'hot',  30.00),
    ('Delta',   NULL,   15.00),
    ('Epsilon', 'warm', 25.00);

-- TODO [P1]: Type cast (::) — explicit type conversion
SELECT '42'::INT AS int_val, 3.14::TEXT AS text_val, NOW()::DATE AS today;

-- TODO [P1]: IN (value_list) — check membership in a list
SELECT * FROM items WHERE tag IN ('hot', 'warm');

-- TODO [P1]: BETWEEN — range check
SELECT * FROM items WHERE price BETWEEN 15 AND 25;

-- TODO [P1]: LIKE — pattern matching (case-sensitive)
SELECT * FROM items WHERE name LIKE 'A%';

-- TODO [P1]: ILIKE — pattern matching (case-insensitive)
SELECT * FROM items WHERE name ILIKE 'a%';

-- TODO [P2]: VALUES — standalone row constructor
VALUES (1, 'a'), (2, 'b'), (3, 'c');

-- TODO [P2]: TABLE tablename — shorthand for SELECT * FROM
TABLE items;

-- TODO [P2]: FOR UPDATE — row-level lock in SELECT
SELECT * FROM items WHERE id = 1 FOR UPDATE;

-- TODO [P2]: FOR SHARE — shared row-level lock
SELECT * FROM items WHERE id = 2 FOR SHARE;

-- TODO [P2]: SIMILAR TO — SQL-standard regex-like pattern
SELECT * FROM items WHERE name SIMILAR TO '(Alpha|Beta)%';

-- TODO [P2]: RETURNING * — return affected rows from DML
UPDATE items SET price = price + 1 WHERE tag = 'hot' RETURNING *;

-- TODO [P3]: FOR NO KEY UPDATE — weaker exclusive lock
SELECT * FROM items WHERE id = 3 FOR NO KEY UPDATE;

-- TODO [P3]: FOR KEY SHARE — weakest shared lock
SELECT * FROM items WHERE id = 4 FOR KEY SHARE;

-- Cleanup
DROP TABLE items;
