-- =============================================================================
-- Section 5.4: Set Operations
-- =============================================================================

-- Setup
CREATE TABLE set_a (val INT);
CREATE TABLE set_b (val INT);

INSERT INTO set_a VALUES (1), (2), (3), (3), (4);
INSERT INTO set_b VALUES (3), (4), (5), (5), (6);

-- TODO [P1]: UNION — combine results, remove duplicates
SELECT val FROM set_a
UNION
SELECT val FROM set_b;

-- TODO [P1]: UNION ALL — combine results, keep duplicates
SELECT val FROM set_a
UNION ALL
SELECT val FROM set_b;

-- TODO [P2]: INTERSECT — rows present in both
SELECT val FROM set_a
INTERSECT
SELECT val FROM set_b;

-- TODO [P2]: EXCEPT — rows in first but not in second
SELECT val FROM set_a
EXCEPT
SELECT val FROM set_b;

-- TODO [P3]: INTERSECT ALL — preserve duplicate counts
SELECT val FROM set_a
INTERSECT ALL
SELECT val FROM set_b;

-- TODO [P3]: EXCEPT ALL — preserve duplicate counts
SELECT val FROM set_a
EXCEPT ALL
SELECT val FROM set_b;

-- Cleanup
DROP TABLE set_a;
DROP TABLE set_b;
