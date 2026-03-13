-- =============================================================================
-- Section 5.5: Common Table Expressions (CTE)
-- =============================================================================

-- Setup
CREATE TABLE tree_nodes (
    id        INT PRIMARY KEY,
    parent_id INT,
    label     TEXT
);

INSERT INTO tree_nodes VALUES
    (1, NULL, 'root'),
    (2, 1,    'child-1'),
    (3, 1,    'child-2'),
    (4, 2,    'grandchild-1'),
    (5, 3,    'grandchild-2');

-- TODO [P2]: Basic CTE — WITH ... AS
WITH active_roots AS (
    SELECT * FROM tree_nodes WHERE parent_id IS NULL
)
SELECT * FROM active_roots;

-- TODO [P2]: WITH RECURSIVE — traverse tree hierarchy
WITH RECURSIVE tree AS (
    SELECT id, parent_id, label, 0 AS depth
    FROM tree_nodes
    WHERE parent_id IS NULL
    UNION ALL
    SELECT tn.id, tn.parent_id, tn.label, t.depth + 1
    FROM tree_nodes tn
    JOIN tree t ON tn.parent_id = t.id
)
SELECT * FROM tree ORDER BY depth, id;

-- TODO [P3]: WITH ... AS MATERIALIZED — force CTE materialization
WITH cte AS MATERIALIZED (
    SELECT id, label FROM tree_nodes WHERE parent_id IS NOT NULL
)
SELECT * FROM cte WHERE id > 2;

-- TODO [P3]: WITH ... AS NOT MATERIALIZED — allow inline optimisation
WITH cte AS NOT MATERIALIZED (
    SELECT id, label FROM tree_nodes
)
SELECT * FROM cte WHERE id = 1;

-- TODO [P3]: CTE with DML — INSERT inside CTE, RETURNING consumed
CREATE TABLE archive_nodes (id INT, label TEXT);

WITH moved AS (
    DELETE FROM tree_nodes WHERE id = 5 RETURNING id, label
)
INSERT INTO archive_nodes SELECT * FROM moved;

SELECT * FROM archive_nodes;

DROP TABLE archive_nodes;

-- Re-insert deleted row for subsequent tests
INSERT INTO tree_nodes VALUES (5, 3, 'grandchild-2');

-- TODO [P3]: SEARCH DEPTH FIRST — depth-first ordering
WITH RECURSIVE search_tree AS (
    SELECT id, parent_id, label, 0 AS depth
    FROM tree_nodes WHERE parent_id IS NULL
    UNION ALL
    SELECT tn.id, tn.parent_id, tn.label, st.depth + 1
    FROM tree_nodes tn
    JOIN search_tree st ON tn.parent_id = st.id
) SEARCH DEPTH FIRST BY id SET ordercol
SELECT * FROM search_tree ORDER BY ordercol;

-- TODO [P3]: SEARCH BREADTH FIRST — breadth-first ordering
WITH RECURSIVE search_tree AS (
    SELECT id, parent_id, label, 0 AS depth
    FROM tree_nodes WHERE parent_id IS NULL
    UNION ALL
    SELECT tn.id, tn.parent_id, tn.label, st.depth + 1
    FROM tree_nodes tn
    JOIN search_tree st ON tn.parent_id = st.id
) SEARCH BREADTH FIRST BY id SET ordercol
SELECT * FROM search_tree ORDER BY ordercol;

-- TODO [P3]: CYCLE detection — prevent infinite loops
CREATE TABLE graph_edges (src INT, dst INT);
INSERT INTO graph_edges VALUES (1, 2), (2, 3), (3, 1);

WITH RECURSIVE traverse AS (
    SELECT src, dst, FALSE AS is_cycle, ARRAY[src] AS path
    FROM graph_edges WHERE src = 1
    UNION ALL
    SELECT e.src, e.dst, e.dst = ANY(t.path), t.path || e.src
    FROM graph_edges e
    JOIN traverse t ON e.src = t.dst
    WHERE NOT t.is_cycle
) CYCLE dst SET is_cycle USING path
SELECT * FROM traverse;

DROP TABLE graph_edges;

-- Cleanup
DROP TABLE tree_nodes;
