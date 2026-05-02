-- ============================================================================
-- Section 12.4: Range Type Operations
-- ============================================================================
-- TODO: Verify range operator and function support in pure-Go implementation
-- Note: 06_data_types.sql covers basic range type creation/storage (2.13.x).
--       This file focuses on operators, functions, and advanced features.

-- ----------------------------------------------------------------------------
-- Setup
-- ----------------------------------------------------------------------------

DROP TABLE IF EXISTS reservations;

CREATE TABLE reservations (
    id        SERIAL PRIMARY KEY,
    room      TEXT NOT NULL,
    during    tsrange NOT NULL
);

INSERT INTO reservations (room, during) VALUES
    ('Room A', '[2024-01-15 09:00, 2024-01-15 12:00)'),
    ('Room A', '[2024-01-15 13:00, 2024-01-15 17:00)'),
    ('Room B', '[2024-01-15 10:00, 2024-01-15 11:30)'),
    ('Room B', '[2024-01-15 14:00, 2024-01-15 16:00)'),
    ('Room C', '[2024-01-15 08:00, 2024-01-15 18:00)');

-- ============================================================================
-- P2: Range Operators
-- ============================================================================

-- ----------------------------------------------------------------------------
-- P2: @> (contains element / contains range)
-- TODO: Verify range containment operators
-- ----------------------------------------------------------------------------

-- Contains element
SELECT int4range(1, 10) @> 5 AS contains_elem_true;
SELECT int4range(1, 10) @> 10 AS contains_elem_false_exclusive;
SELECT int4range(1, 10) @> 0 AS contains_elem_false;

-- Contains range
SELECT int4range(1, 10) @> int4range(3, 7) AS contains_range_true;
SELECT int4range(2, 4) @> int4range(2, 3) AS contains_range_true2;
SELECT int4range(1, 5) @> int4range(1, 10) AS contains_range_false;

-- Timestamp range contains element
SELECT '[2024-01-15 09:00, 2024-01-15 12:00)'::tsrange @> '2024-01-15 10:00'::timestamp AS ts_contains_true;

-- ----------------------------------------------------------------------------
-- P2: <@ (contained by - reverse of @>)
-- TODO: Verify contained-by operator
-- ----------------------------------------------------------------------------

SELECT int4range(2, 4) <@ int4range(1, 7) AS range_contained_true;
SELECT 42 <@ int4range(1, 100) AS elem_contained_true;
SELECT 42 <@ int4range(1, 7) AS elem_contained_false;

-- ----------------------------------------------------------------------------
-- P2: && (overlap)
-- TODO: Verify range overlap operator
-- ----------------------------------------------------------------------------

SELECT int4range(1, 5) && int4range(3, 8) AS overlap_true;
SELECT int4range(1, 5) && int4range(5, 8) AS overlap_false_adjacent;
SELECT int4range(1, 5) && int4range(6, 8) AS overlap_false;
SELECT int8range(3, 7) && int8range(4, 12) AS overlap_int8_true;

-- Overlap query on table
SELECT r1.room, r2.room, r1.during, r2.during
  FROM reservations r1
  JOIN reservations r2 ON r1.during && r2.during AND r1.id < r2.id;

-- ----------------------------------------------------------------------------
-- P2: << (strictly left of) and >> (strictly right of)
-- TODO: Verify strict ordering operators
-- ----------------------------------------------------------------------------

SELECT int8range(1, 10) << int8range(100, 110) AS left_of_true;
SELECT int8range(1, 10) << int8range(5, 15) AS left_of_false;
SELECT int8range(50, 60) >> int8range(20, 30) AS right_of_true;
SELECT int8range(50, 60) >> int8range(55, 70) AS right_of_false;

-- ----------------------------------------------------------------------------
-- P2: &< (does not extend to the right of) and &> (does not extend to the left of)
-- TODO: Verify bound-limiting operators
-- ----------------------------------------------------------------------------

SELECT int8range(1, 20) &< int8range(18, 20) AS not_right_of_true;
SELECT int8range(1, 20) &< int8range(5, 10) AS not_right_of_false;
SELECT int8range(7, 20) &> int8range(5, 10) AS not_left_of_true;
SELECT int8range(1, 20) &> int8range(5, 10) AS not_left_of_false;

-- ----------------------------------------------------------------------------
-- P2: -|- (adjacent)
-- TODO: Verify adjacency operator
-- ----------------------------------------------------------------------------

SELECT int4range(1, 5) -|- int4range(5, 10) AS adjacent_true;
SELECT numrange(1.1, 2.2) -|- numrange(2.2, 3.3) AS adjacent_num_true;
SELECT int4range(1, 5) -|- int4range(6, 10) AS adjacent_false;

-- ----------------------------------------------------------------------------
-- P2: + (union), * (intersection), - (difference)
-- TODO: Verify range arithmetic operators
-- ----------------------------------------------------------------------------

SELECT numrange(5, 15) + numrange(10, 20) AS range_union;
SELECT int8range(5, 15) * int8range(10, 20) AS range_intersection;
SELECT int8range(5, 15) - int8range(10, 20) AS range_difference;

-- Empty intersection
SELECT int4range(1, 5) * int4range(6, 10) AS empty_intersection;

-- ============================================================================
-- P2: Range Functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- P2: lower() and upper() - extract bounds
-- TODO: Verify bound extraction functions
-- ----------------------------------------------------------------------------

SELECT lower(numrange(1.1, 2.2)) AS lower_val;
SELECT upper(numrange(1.1, 2.2)) AS upper_val;
SELECT lower(int8range(15, 25)) AS lower_int8;
SELECT upper(int8range(15, 25)) AS upper_int8;

-- NULL for empty / unbounded
SELECT lower('empty'::int4range) AS lower_empty;
SELECT upper('(,10)'::int4range) AS upper_unbounded_lower;
SELECT lower('(,10)'::int4range) AS lower_unbounded;

-- ----------------------------------------------------------------------------
-- P2: isempty()
-- TODO: Verify empty range detection
-- ----------------------------------------------------------------------------

SELECT isempty(numrange(1, 5)) AS not_empty;
SELECT isempty('empty'::int4range) AS is_empty;
SELECT isempty(int4range(5, 5)) AS empty_same_bounds;

-- ----------------------------------------------------------------------------
-- P2: lower_inc(), upper_inc() - bound inclusivity
-- TODO: Verify inclusivity check functions
-- ----------------------------------------------------------------------------

SELECT lower_inc(numrange(1.1, 2.2)) AS lower_inc_default;
SELECT upper_inc(numrange(1.1, 2.2)) AS upper_inc_default;
SELECT lower_inc('[1,5]'::int4range) AS lower_inc_inclusive;
SELECT upper_inc('[1,5]'::int4range) AS upper_inc_inclusive;

-- ----------------------------------------------------------------------------
-- P2: lower_inf(), upper_inf() - infinite bounds
-- TODO: Verify infinite bound detection
-- ----------------------------------------------------------------------------

SELECT lower_inf('(,)'::daterange) AS lower_inf_true;
SELECT upper_inf('(,)'::daterange) AS upper_inf_true;
SELECT lower_inf('[1,5)'::int4range) AS lower_inf_false;
SELECT upper_inf('[1,5)'::int4range) AS upper_inf_false;

-- ----------------------------------------------------------------------------
-- P2: range_merge() - smallest range containing both
-- TODO: Verify range_merge function
-- ----------------------------------------------------------------------------

SELECT range_merge('[1,2)'::int4range, '[3,4)'::int4range) AS merged;
SELECT range_merge(numrange(1.0, 5.0), numrange(8.0, 10.0)) AS merged_num;

-- ============================================================================
-- P2: Range Constructors - different bound types
-- ============================================================================

-- ----------------------------------------------------------------------------
-- P2: Constructor with explicit bound types
-- TODO: Verify all four bound-type combinations
-- ----------------------------------------------------------------------------

-- [) default - lower inclusive, upper exclusive
SELECT int4range(1, 10) AS default_bounds;
SELECT int4range(1, 10, '[)') AS explicit_default;

-- (] lower exclusive, upper inclusive
SELECT numrange(1.0, 14.0, '(]') AS open_closed;

-- [] both inclusive
SELECT int4range(1, 10, '[]') AS closed_closed;

-- () both exclusive
SELECT int4range(1, 10, '()') AS open_open;

-- NULL bounds for unbounded
SELECT numrange(NULL, 5.0) AS unbounded_lower;
SELECT numrange(5.0, NULL) AS unbounded_upper;
SELECT numrange(NULL, NULL) AS unbounded_both;

-- ============================================================================
-- P3: All Built-in Range Types
-- ============================================================================

-- ----------------------------------------------------------------------------
-- P3: Verify each built-in range type with operators
-- TODO: Verify all six built-in range types work with operators
-- ----------------------------------------------------------------------------

SELECT int4range(1, 100) @> 50 AS int4range_test;
SELECT int8range(1, 1000000000) @> 500000000::bigint AS int8range_test;
SELECT numrange(1.5, 9.5) @> 5.0 AS numrange_test;
SELECT tsrange('2024-01-01', '2024-12-31') @> '2024-06-15'::timestamp AS tsrange_test;
SELECT tstzrange('2024-01-01 00:00+00', '2024-12-31 23:59+00') @> '2024-06-15 12:00+00'::timestamptz AS tstzrange_test;
SELECT daterange('2024-01-01', '2024-12-31') @> '2024-06-15'::date AS daterange_test;

-- ============================================================================
-- P3: Multirange Types (PG 14+)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- P3: Multirange construction and operators
-- TODO: Verify multirange support (requires PostgreSQL 14+)
-- ----------------------------------------------------------------------------

-- Construction
SELECT int4multirange(int4range(1, 5), int4range(8, 10)) AS mr_construct;
SELECT '{[1,5), [8,10)}'::int4multirange AS mr_literal;
SELECT '{}'::int4multirange AS mr_empty;

-- Containment
SELECT '{[2,4)}'::int4multirange @> '{[2,3)}'::int4multirange AS mr_contains;
SELECT '{[2,4)}'::int4multirange @> int4range(2, 3) AS mr_contains_range;
SELECT '{[1,5), [8,12)}'::int4multirange @> 3 AS mr_contains_elem;

-- Overlap
SELECT '{[3,7)}'::int8multirange && '{[4,12)}'::int8multirange AS mr_overlap;

-- Union, intersection, difference
SELECT '{[5,10)}'::nummultirange + '{[15,20)}'::nummultirange AS mr_union;
SELECT '{[5,15)}'::int8multirange * '{[10,20)}'::int8multirange AS mr_intersection;
SELECT '{[5,20)}'::int8multirange - '{[10,15)}'::int8multirange AS mr_difference;

-- Multirange functions
SELECT lower('{[1,5), [8,12)}'::int4multirange) AS mr_lower;
SELECT upper('{[1,5), [8,12)}'::int4multirange) AS mr_upper;
SELECT isempty('{}'::int4multirange) AS mr_isempty;
SELECT range_merge('{[1,2), [3,4)}'::int4multirange) AS mr_range_merge;

-- unnest: expand multirange to set of ranges
SELECT unnest('{[1,2), [3,4)}'::int4multirange) AS mr_unnest;

-- multirange() constructor from single range
SELECT multirange('[1,5)'::int4range) AS mr_from_range;

-- ============================================================================
-- P3: GiST Index on Range Column
-- ============================================================================

-- ----------------------------------------------------------------------------
-- P3: GiST index for range operations
-- TODO: Verify GiST index creation and usage with range types
-- ----------------------------------------------------------------------------

CREATE INDEX idx_reservations_during ON reservations USING GIST (during);

-- Query that should use the GiST index
SELECT room, during
  FROM reservations
 WHERE during && '[2024-01-15 10:00, 2024-01-15 11:00)'::tsrange;

SELECT room, during
  FROM reservations
 WHERE during @> '2024-01-15 14:30'::timestamp;

-- ============================================================================
-- P3: EXCLUDE Constraint with Range Overlap
-- ============================================================================

-- ----------------------------------------------------------------------------
-- P3: Prevent overlapping ranges with EXCLUDE constraint
-- TODO: Verify EXCLUDE constraint with && operator on range columns
-- ----------------------------------------------------------------------------

DROP TABLE IF EXISTS meeting_rooms;

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE meeting_rooms (
    id      SERIAL PRIMARY KEY,
    room    TEXT NOT NULL,
    during  tsrange NOT NULL,
    EXCLUDE USING GIST (room WITH =, during WITH &&)
);

-- These should succeed (different rooms or non-overlapping times)
INSERT INTO meeting_rooms (room, during) VALUES ('Room A', '[2024-01-15 09:00, 2024-01-15 10:00)');
INSERT INTO meeting_rooms (room, during) VALUES ('Room A', '[2024-01-15 10:00, 2024-01-15 11:00)');
INSERT INTO meeting_rooms (room, during) VALUES ('Room B', '[2024-01-15 09:00, 2024-01-15 10:00)');

-- This should fail (overlaps with existing Room A reservation)
-- INSERT INTO meeting_rooms (room, during) VALUES ('Room A', '[2024-01-15 09:30, 2024-01-15 10:30)');

-- ============================================================================
-- P3: Custom Range Type
-- ============================================================================

-- ----------------------------------------------------------------------------
-- P3: CREATE TYPE ... AS RANGE
-- TODO: Verify custom range type creation
-- ----------------------------------------------------------------------------

DROP TYPE IF EXISTS floatrange CASCADE;

CREATE TYPE floatrange AS RANGE (
    subtype = float8,
    subtype_diff = float8mi
);

SELECT floatrange(1.0, 5.0) @> 3.14::float8 AS custom_contains;
SELECT floatrange(1.0, 5.0) && floatrange(4.0, 8.0) AS custom_overlap;
SELECT lower(floatrange(1.0, 5.0)) AS custom_lower;

-- ============================================================================
-- Cleanup
-- ============================================================================

DROP TABLE IF EXISTS meeting_rooms;
DROP TABLE IF EXISTS reservations;
DROP TYPE IF EXISTS floatrange CASCADE;
DROP EXTENSION IF EXISTS btree_gist;
