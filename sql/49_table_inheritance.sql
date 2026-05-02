-- =============================================================================
-- Section 12.6: Table Inheritance
-- =============================================================================

-- Setup: parent and child tables with sample data

CREATE TABLE persons (
    id    SERIAL PRIMARY KEY,
    name  TEXT NOT NULL,
    email TEXT
);

CREATE TABLE employees (
    salary  NUMERIC(10, 2),
    dept    TEXT
) INHERITS (persons);

CREATE TABLE managers (
    level TEXT
) INHERITS (persons);

INSERT INTO persons (name, email) VALUES
    ('Alice',   'alice@example.com'),
    ('Bob',     'bob@example.com');

INSERT INTO employees (name, email, salary, dept) VALUES
    ('Charlie', 'charlie@example.com', 60000, 'Engineering'),
    ('Diana',   'diana@example.com',   75000, 'Sales');

INSERT INTO managers (name, email, level) VALUES
    ('Eve', 'eve@example.com', 'Senior');

-- =============================================================================
-- TODO [P4]: Basic inheritance — child inherits parent columns
-- =============================================================================

-- employees and managers inherit id, name, email from persons
SELECT * FROM employees ORDER BY name;

-- =============================================================================
-- TODO [P4]: Query parent includes child rows
-- =============================================================================

-- querying the parent table returns rows from parent + all children
SELECT * FROM persons ORDER BY name;

-- =============================================================================
-- TODO [P4]: ONLY keyword — exclude inherited rows
-- =============================================================================

-- ONLY restricts the query to the parent table itself
SELECT * FROM ONLY persons ORDER BY name;

-- =============================================================================
-- TODO [P4]: tableoid::regclass — identify source table per row
-- =============================================================================

SELECT tableoid::regclass AS source_table, id, name, email
FROM persons
ORDER BY source_table, name;

-- =============================================================================
-- TODO [P4]: Multiple inheritance — inherit from two parents
-- =============================================================================

CREATE TABLE contactable (
    phone TEXT
);

CREATE TABLE contact_employees (
    title TEXT
) INHERITS (persons, contactable);

INSERT INTO contact_employees (name, email, phone, title) VALUES
    ('Frank', 'frank@example.com', '555-0100', 'Lead');

SELECT tableoid::regclass AS source_table, * FROM persons ORDER BY name;

-- =============================================================================
-- TODO [P4]: Detach inheritance — ALTER TABLE ... NO INHERIT
-- =============================================================================

ALTER TABLE managers NO INHERIT persons;

-- managers rows no longer appear in persons query
SELECT tableoid::regclass AS source_table, * FROM persons ORDER BY name;

-- =============================================================================
-- TODO [P4]: Attach inheritance — ALTER TABLE ... INHERIT
-- =============================================================================

ALTER TABLE managers INHERIT persons;

-- managers rows appear again
SELECT tableoid::regclass AS source_table, * FROM persons ORDER BY name;

-- =============================================================================
-- TODO [P4]: Constraint behavior — child inherits CHECK constraints
-- =============================================================================

DROP TABLE IF EXISTS checked_parent CASCADE;

CREATE TABLE checked_parent (
    id   SERIAL PRIMARY KEY,
    val  INT NOT NULL,
    CONSTRAINT val_positive CHECK (val > 0)
);

CREATE TABLE checked_child (
    extra TEXT
) INHERITS (checked_parent);

-- Succeeds: satisfies inherited CHECK
INSERT INTO checked_child (val, extra) VALUES (10, 'ok');

-- Fails: violates inherited CHECK (val > 0)
-- INSERT INTO checked_child (val, extra) VALUES (-1, 'bad');

SELECT tableoid::regclass AS source_table, * FROM checked_parent;

-- =============================================================================
-- TODO [P4]: UPDATE/DELETE with ONLY — affect only parent rows
-- =============================================================================

UPDATE ONLY persons SET email = 'updated@example.com' WHERE name = 'Alice';

-- Only the parent row is updated; child rows are unchanged
SELECT tableoid::regclass AS source_table, name, email
FROM persons
ORDER BY source_table, name;

DELETE FROM ONLY persons WHERE name = 'Bob';

SELECT tableoid::regclass AS source_table, name, email
FROM persons
ORDER BY source_table, name;

-- Cleanup
DROP TABLE contact_employees;
DROP TABLE contactable;
DROP TABLE checked_child;
DROP TABLE checked_parent;
DROP TABLE managers;
DROP TABLE employees;
DROP TABLE persons;
