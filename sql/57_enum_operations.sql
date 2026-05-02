-- =============================================================================
-- Section 12.14: Enum Type Operations
-- =============================================================================
-- Note: 06_data_types.sql and 01_ddl.sql cover basic CREATE TYPE ... AS ENUM.
--       This file covers enum-specific functions and operations.

-- =============================================================================
-- Setup
-- =============================================================================

CREATE TYPE enum_color AS ENUM ('red', 'orange', 'yellow', 'green', 'blue', 'violet');
CREATE TABLE enum_test (id serial PRIMARY KEY, color enum_color);
INSERT INTO enum_test (color) VALUES ('red'), ('green'), ('blue'), ('yellow'), ('violet'), ('orange');

-- =============================================================================
-- TODO [P3]: enum_first() / enum_last() / enum_range()
-- =============================================================================

SELECT enum_first(NULL::enum_color) AS first_val;
SELECT enum_last(NULL::enum_color)  AS last_val;
SELECT enum_range(NULL::enum_color) AS all_values;
SELECT enum_range('orange'::enum_color, 'green'::enum_color) AS partial_range;

-- =============================================================================
-- TODO [P3]: Enum comparison operators (ordering based on declaration order)
-- =============================================================================

SELECT 'red'::enum_color < 'blue'::enum_color    AS red_before_blue;
SELECT 'violet'::enum_color > 'green'::enum_color AS violet_after_green;
SELECT 'green'::enum_color = 'green'::enum_color  AS equals;
SELECT 'red'::enum_color <> 'blue'::enum_color    AS not_equal;

-- Order by enum preserves declaration order
SELECT * FROM enum_test ORDER BY color;

-- =============================================================================
-- TODO [P3]: ALTER TYPE ... ADD VALUE 'new_val'
-- =============================================================================

ALTER TYPE enum_color ADD VALUE 'indigo';
INSERT INTO enum_test (color) VALUES ('indigo');
SELECT * FROM enum_test ORDER BY color;

-- =============================================================================
-- TODO [P3]: ALTER TYPE ... ADD VALUE 'val' BEFORE/AFTER 'existing'
-- =============================================================================

ALTER TYPE enum_color ADD VALUE 'cyan' BEFORE 'blue';
ALTER TYPE enum_color ADD VALUE 'lime' AFTER 'green';
INSERT INTO enum_test (color) VALUES ('cyan'), ('lime');
SELECT enum_range(NULL::enum_color) AS all_values_after_add;

-- =============================================================================
-- TODO [P3]: ALTER TYPE ... RENAME VALUE 'old' TO 'new' (PG 10+)
-- =============================================================================

ALTER TYPE enum_color RENAME VALUE 'violet' TO 'purple';
SELECT * FROM enum_test ORDER BY color;

-- =============================================================================
-- TODO [P3]: Enum in arrays
-- =============================================================================

SELECT ARRAY['red', 'green', 'blue']::enum_color[] AS color_array;
SELECT * FROM enum_test WHERE color = ANY(ARRAY['red', 'blue']::enum_color[]);

-- =============================================================================
-- TODO [P3]: Casting enum to/from text
-- =============================================================================

SELECT 'red'::enum_color::text AS enum_to_text;
SELECT 'green'::text::enum_color AS text_to_enum;
SELECT color::text, length(color::text) FROM enum_test ORDER BY color;

-- =============================================================================
-- Cleanup
-- =============================================================================

DROP TABLE enum_test;
DROP TYPE enum_color;
