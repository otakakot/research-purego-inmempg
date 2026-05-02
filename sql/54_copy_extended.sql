-- =============================================================================
-- Section 12.11: COPY Extended
-- Verification tests for pure-Go in-memory PostgreSQL implementation
-- =============================================================================

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_copy_ext CASCADE;

-- =====================
-- Setup: create test table with sample data
-- =====================
CREATE TABLE test_copy_ext (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    category   VARCHAR(50),
    price      NUMERIC(10, 2),
    in_stock   BOOLEAN DEFAULT TRUE,
    note       TEXT
);

INSERT INTO test_copy_ext (name, category, price, in_stock, note) VALUES
    ('Widget A',  'hardware',  9.99,  TRUE,  'basic widget'),
    ('Widget B',  'hardware',  19.99, TRUE,  'premium widget'),
    ('Gadget X',  'electronics', 49.99, FALSE, NULL),
    ('Gadget Y',  'electronics', 99.99, TRUE,  'high-end gadget'),
    ('Tool Z',    'tools',     14.50, TRUE,  'multi-purpose');

-- =====================
-- [P2] COPY ... TO STDOUT — basic CSV export
-- =====================
COPY test_copy_ext TO STDOUT WITH (FORMAT csv);

-- =====================
-- [P2] COPY ... TO STDOUT WITH (FORMAT CSV, HEADER) — CSV with headers
-- =====================
COPY test_copy_ext TO STDOUT WITH (FORMAT csv, HEADER);

-- =====================
-- [P2] COPY (SELECT query) TO STDOUT — copy from query result
-- =====================
COPY (SELECT id, name, price FROM test_copy_ext WHERE in_stock = TRUE ORDER BY price)
    TO STDOUT WITH (FORMAT csv, HEADER);

-- =====================
-- [P3] COPY ... WITH (DELIMITER, NULL, QUOTE, ESCAPE) — custom format options
-- =====================
COPY test_copy_ext TO STDOUT WITH (
    FORMAT csv,
    DELIMITER '|',
    NULL '<NULL>',
    QUOTE '"',
    ESCAPE '\'
);

-- =====================
-- [P3] COPY ... WITH (FORMAT TEXT) — tab-delimited text format
-- =====================
COPY test_copy_ext TO STDOUT WITH (FORMAT text);

-- =====================
-- [P3] COPY ... WITH (FORMAT BINARY) — binary format
-- =====================
-- Note: binary output is not human-readable; commented out to avoid garbled output.
-- COPY test_copy_ext TO STDOUT WITH (FORMAT binary);

-- =====================
-- [P3] COPY ... WHERE (PG 12+) — filter rows during COPY FROM
-- =====================
-- Note: WHERE clause is only supported with COPY FROM, not COPY TO.
-- Use a query-based COPY TO filter rows for export:
COPY (SELECT * FROM test_copy_ext WHERE category = 'electronics')
    TO STDOUT WITH (FORMAT csv, HEADER);

-- =====================
-- [P3] COPY ... FROM STDIN — load data (with inline data example)
-- =====================
-- Note: psql feeds the lines between COPY and \. as stdin data.
-- Using tab-delimited TEXT format (default) for reliable \. termination.
COPY test_copy_ext (name, category, price, in_stock, note) FROM STDIN;
Doohickey	misc	5.25	true	imported via STDIN
Thingamajig	misc	3.75	false	\N
\.

SELECT * FROM test_copy_ext WHERE category = 'misc' ORDER BY name;

-- =====================
-- [P4] COPY ... WITH (FORCE_QUOTE, FORCE_NOT_NULL) — column-level options
-- =====================
COPY test_copy_ext TO STDOUT WITH (
    FORMAT csv,
    HEADER,
    FORCE_QUOTE (name, note)
);

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_copy_ext CASCADE;
