-- =============================================================================
-- Section 5.2: JOIN
-- =============================================================================

-- Setup: two related tables
CREATE TABLE departments (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE employees (
    id      SERIAL PRIMARY KEY,
    name    TEXT NOT NULL,
    dept_id INT REFERENCES departments(id),
    manager_id INT
);

INSERT INTO departments (name) VALUES ('Engineering'), ('Sales'), ('HR');

INSERT INTO employees (name, dept_id, manager_id) VALUES
    ('Alice',   1, NULL),
    ('Bob',     1, 1),
    ('Charlie', 2, 1),
    ('Diana',   NULL, 2),
    ('Eve',     3, 1);

-- TODO [P1]: INNER JOIN — rows matching in both tables
SELECT e.name AS employee, d.name AS department
FROM employees e
INNER JOIN departments d ON e.dept_id = d.id;

-- TODO [P1]: LEFT JOIN — all left rows, NULLs for non-matching right
SELECT e.name AS employee, d.name AS department
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.id;

-- TODO [P1]: RIGHT JOIN — all right rows, NULLs for non-matching left
SELECT e.name AS employee, d.name AS department
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.id;

-- TODO [P1]: CROSS JOIN — cartesian product
SELECT e.name AS employee, d.name AS department
FROM employees e
CROSS JOIN departments d;

-- TODO [P1]: Self join — join a table to itself
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;

-- TODO [P2]: FULL OUTER JOIN — all rows from both sides
SELECT e.name AS employee, d.name AS department
FROM employees e
FULL OUTER JOIN departments d ON e.dept_id = d.id;

-- TODO [P2]: NATURAL JOIN — implicit join on same-named columns
-- Both tables share column "name" so this tests the behaviour (may match unexpectedly)
CREATE TABLE dept_lookup (id INT, name TEXT);
INSERT INTO dept_lookup VALUES (1, 'Engineering'), (2, 'Sales');

SELECT * FROM departments NATURAL JOIN dept_lookup;

DROP TABLE dept_lookup;

-- TODO [P2]: JOIN ... USING — join on shared column name
CREATE TABLE emp_dept (emp_id INT, dept_id INT);
INSERT INTO emp_dept VALUES (1, 1), (2, 1), (3, 2);

SELECT e.name, d.name AS department
FROM employees e
JOIN emp_dept ed ON e.id = ed.emp_id
JOIN departments d USING (id)
WHERE d.id = ed.dept_id;

DROP TABLE emp_dept;

-- TODO [P3]: LATERAL JOIN — correlated subquery in FROM
SELECT d.name AS department, top_emp.name AS top_employee
FROM departments d
LEFT JOIN LATERAL (
    SELECT e.name
    FROM employees e
    WHERE e.dept_id = d.id
    ORDER BY e.id
    LIMIT 1
) top_emp ON TRUE;

-- Cleanup
DROP TABLE employees;
DROP TABLE departments;
