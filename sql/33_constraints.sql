-- =============================================================================
-- Section 7: Constraints
-- =============================================================================

-- TODO [P1]: NOT NULL constraint
CREATE TABLE con_notnull (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);
INSERT INTO con_notnull (name) VALUES ('valid');
-- Should fail:
-- INSERT INTO con_notnull (name) VALUES (NULL);
DROP TABLE con_notnull;

-- TODO [P1]: UNIQUE constraint
CREATE TABLE con_unique (
    id    SERIAL PRIMARY KEY,
    email TEXT UNIQUE
);
INSERT INTO con_unique (email) VALUES ('a@b.com');
-- Should fail:
-- INSERT INTO con_unique (email) VALUES ('a@b.com');
DROP TABLE con_unique;

-- TODO [P1]: PRIMARY KEY constraint
CREATE TABLE con_pk (
    id INT PRIMARY KEY,
    val TEXT
);
INSERT INTO con_pk VALUES (1, 'one');
-- Should fail:
-- INSERT INTO con_pk VALUES (1, 'dup');
DROP TABLE con_pk;

-- TODO [P1]: DEFAULT value
CREATE TABLE con_default (
    id         SERIAL PRIMARY KEY,
    status     TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO con_default DEFAULT VALUES;
SELECT * FROM con_default;
DROP TABLE con_default;

-- TODO [P2]: CHECK constraint
CREATE TABLE con_check (
    id    SERIAL PRIMARY KEY,
    age   INT CHECK (age >= 0 AND age <= 150),
    score INT,
    CONSTRAINT positive_score CHECK (score > 0)
);
INSERT INTO con_check (age, score) VALUES (25, 100);
-- Should fail:
-- INSERT INTO con_check (age, score) VALUES (-1, 100);
-- INSERT INTO con_check (age, score) VALUES (25, -5);
DROP TABLE con_check;

-- TODO [P2]: FOREIGN KEY with ON DELETE/ON UPDATE actions
CREATE TABLE fk_parent (
    id   SERIAL PRIMARY KEY,
    name TEXT
);
CREATE TABLE fk_child_cascade (
    id        SERIAL PRIMARY KEY,
    parent_id INT REFERENCES fk_parent(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE fk_child_setnull (
    id        SERIAL PRIMARY KEY,
    parent_id INT REFERENCES fk_parent(id) ON DELETE SET NULL
);
CREATE TABLE fk_child_restrict (
    id        SERIAL PRIMARY KEY,
    parent_id INT REFERENCES fk_parent(id) ON DELETE RESTRICT
);

INSERT INTO fk_parent (name) VALUES ('parent1'), ('parent2');
INSERT INTO fk_child_cascade  (parent_id) VALUES (1);
INSERT INTO fk_child_setnull  (parent_id) VALUES (1);
INSERT INTO fk_child_restrict (parent_id) VALUES (2);

-- Test CASCADE: child row should be deleted
DELETE FROM fk_parent WHERE id = 1;
SELECT * FROM fk_child_cascade;  -- expect empty
SELECT * FROM fk_child_setnull;  -- expect parent_id = NULL

-- Test RESTRICT: should fail while child references it
-- DELETE FROM fk_parent WHERE id = 2;

DROP TABLE fk_child_restrict;
DROP TABLE fk_child_setnull;
DROP TABLE fk_child_cascade;
DROP TABLE fk_parent;

-- TODO [P2]: GENERATED ALWAYS AS IDENTITY
CREATE TABLE con_identity (
    id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT
);
INSERT INTO con_identity (name) VALUES ('Alice'), ('Bob');
SELECT * FROM con_identity;
-- Should fail (cannot override ALWAYS):
-- INSERT INTO con_identity (id, name) VALUES (99, 'Hack');
DROP TABLE con_identity;

-- TODO [P3]: GENERATED ALWAYS AS (expr) STORED — computed column
CREATE TABLE con_generated (
    id     SERIAL PRIMARY KEY,
    qty    INT,
    price  NUMERIC(10, 2),
    total  NUMERIC(10, 2) GENERATED ALWAYS AS (qty * price) STORED
);
INSERT INTO con_generated (qty, price) VALUES (5, 19.99);
SELECT * FROM con_generated;  -- total should be 99.95
DROP TABLE con_generated;

-- TODO [P3]: EXCLUDE USING — exclusion constraint (requires btree_gist)
-- CREATE EXTENSION IF NOT EXISTS btree_gist;
-- CREATE TABLE con_exclude (
--     id       SERIAL PRIMARY KEY,
--     room     INT,
--     period   TSTZRANGE,
--     EXCLUDE USING gist (room WITH =, period WITH &&)
-- );
-- INSERT INTO con_exclude (room, period) VALUES
--     (1, '[2024-01-01, 2024-01-02)');
-- -- Should fail (overlapping):
-- -- INSERT INTO con_exclude (room, period) VALUES
-- --     (1, '[2024-01-01 12:00, 2024-01-03)');
-- DROP TABLE con_exclude;

-- TODO [P3]: DEFERRABLE / INITIALLY DEFERRED — defer constraint checking
CREATE TABLE con_defer_parent (
    id INT PRIMARY KEY
);
CREATE TABLE con_defer_child (
    id        INT PRIMARY KEY,
    parent_id INT REFERENCES con_defer_parent(id) DEFERRABLE INITIALLY DEFERRED
);

BEGIN;
-- Insert child before parent — allowed because constraint is deferred
INSERT INTO con_defer_child VALUES (1, 10);
INSERT INTO con_defer_parent VALUES (10);
COMMIT;

SELECT * FROM con_defer_child;
SELECT * FROM con_defer_parent;

DROP TABLE con_defer_child;
DROP TABLE con_defer_parent;
