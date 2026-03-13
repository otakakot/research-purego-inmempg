-- =============================================================================
-- Section 4.11: Sequence Functions
-- =============================================================================

-- Setup: create test sequence
DROP SEQUENCE IF EXISTS test_seq;
CREATE SEQUENCE test_seq START WITH 1 INCREMENT BY 1;

-- -----------------------------------------------------------------------------
-- TODO [P1] nextval
-- -----------------------------------------------------------------------------

SELECT nextval('test_seq') AS seq_1;
SELECT nextval('test_seq') AS seq_2;
SELECT nextval('test_seq') AS seq_3;

-- -----------------------------------------------------------------------------
-- TODO [P2] currval, setval, lastval
-- -----------------------------------------------------------------------------

-- currval: returns the most recently obtained value from nextval for this sequence
SELECT currval('test_seq') AS cur_val;

-- setval: set the sequence to a specific value
SELECT setval('test_seq', 100) AS set_to_100;
SELECT nextval('test_seq') AS after_setval;

-- setval with is_called = false: next nextval returns the set value itself
SELECT setval('test_seq', 200, FALSE) AS set_to_200_not_called;
SELECT nextval('test_seq') AS should_be_200;

-- lastval: returns value most recently returned by nextval in current session
SELECT lastval() AS last_val;

-- Verify sequence works with a table
DROP TABLE IF EXISTS seq_table_test;
CREATE TABLE seq_table_test (
    id INTEGER DEFAULT nextval('test_seq'),
    name TEXT
);
INSERT INTO seq_table_test (name) VALUES ('alpha'), ('bravo'), ('charlie');
SELECT * FROM seq_table_test ORDER BY id;

-- Cleanup
DROP TABLE IF EXISTS seq_table_test;
DROP SEQUENCE IF EXISTS test_seq;
