-- =============================================================================
-- Section 12.5: JSON Path Expressions (SQL/JSON)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TODO [P2] jsonb_path_query, jsonb_path_query_array, jsonb_path_query_first,
--           jsonb_path_exists, jsonb_path_match — core jsonpath functions
-- -----------------------------------------------------------------------------

-- JSON path basics: $, $.key, $.key.nested, $[0], $[*]
SELECT jsonb_path_query('{"a": 1, "b": 2}'::JSONB, '$') AS root;
SELECT jsonb_path_query('{"a": 1, "b": 2}'::JSONB, '$.a') AS dot_key;
SELECT jsonb_path_query('{"a": {"b": {"c": 42}}}'::JSONB, '$.a.b.c') AS nested;
SELECT jsonb_path_query('[10, 20, 30]'::JSONB, '$[0]') AS first_elem;
SELECT * FROM jsonb_path_query('[10, 20, 30]'::JSONB, '$[*]');

-- jsonb_path_query — returns all matching items as a set
SELECT * FROM jsonb_path_query(
    '{"items": [{"name": "a", "price": 10}, {"name": "b", "price": 25}, {"name": "c", "price": 5}]}'::JSONB,
    '$.items[*].name'
);

SELECT * FROM jsonb_path_query(
    '{"x": [1, 2, 3, 4, 5]}'::JSONB,
    '$.x[*] ? (@ > 3)'
);

-- jsonb_path_query_array — returns all matches as a single JSON array
SELECT jsonb_path_query_array('[1, 2, 3, 4, 5]'::JSONB, '$[*] ? (@ > 2)') AS matches;
-- expect [3, 4, 5]

SELECT jsonb_path_query_array(
    '{"items": [{"name": "a", "price": 10}, {"name": "b", "price": 25}]}'::JSONB,
    '$.items[*].price'
) AS all_prices;
-- expect [10, 25]

-- jsonb_path_query_first — returns only the first match
SELECT jsonb_path_query_first('[1, 2, 3, 4, 5]'::JSONB, '$[*] ? (@ > 2)') AS first_match;
-- expect 3

SELECT jsonb_path_query_first(
    '{"items": [{"name": "a"}, {"name": "b"}, {"name": "c"}]}'::JSONB,
    '$.items[*].name'
) AS first_name;
-- expect "a"

-- jsonb_path_exists — test whether a path returns any item
SELECT jsonb_path_exists('{"a": {"b": 42}}'::JSONB, '$.a.b') AS path_exists;
-- expect true

SELECT jsonb_path_exists('{"a": 1}'::JSONB, '$.b') AS missing_key;
-- expect false

SELECT jsonb_path_exists('[1, 2, 3, 4, 5]'::JSONB, '$[*] ? (@ > 10)') AS has_gt_10;
-- expect false

-- @? operator (equivalent to jsonb_path_exists)
SELECT '{"a": [1, 2, 3, 4, 5]}'::JSONB @? '$.a[*] ? (@ > 2)' AS op_exists;
-- expect true

-- jsonb_path_match — evaluate a boolean predicate expression
SELECT jsonb_path_match('{"a": 10}'::JSONB, '$.a > 5') AS is_gt_5;
-- expect true

SELECT jsonb_path_match('{"a": 10}'::JSONB, '$.a < 5') AS is_lt_5;
-- expect false

SELECT jsonb_path_match(
    '{"a": [1, 2, 3, 4, 5]}'::JSONB,
    'exists($.a[*] ? (@ >= 3))'
) AS has_gte_3;
-- expect true

-- @@ operator (equivalent to jsonb_path_match)
SELECT '{"a": [1, 2, 3, 4, 5]}'::JSONB @@ '$.a[*] > 2' AS op_match;
-- expect true

-- -----------------------------------------------------------------------------
-- TODO [P3] filter expressions, recursive descent, path methods, path variables
-- -----------------------------------------------------------------------------

-- Filter expressions: ? (@ > 5), ? (@.key == "value"), ? (@ like_regex "pattern")
SELECT * FROM jsonb_path_query(
    '[1, 2, 3, 7, 8, 10]'::JSONB,
    '$[*] ? (@ > 5)'
);

SELECT * FROM jsonb_path_query(
    '{"users": [{"name": "Alice", "age": 30}, {"name": "Bob", "age": 25}]}'::JSONB,
    '$.users[*] ? (@.name == "Alice")'
);

SELECT * FROM jsonb_path_query(
    '["apple", "banana", "apricot", "cherry"]'::JSONB,
    '$[*] ? (@ like_regex "^ap")'
);

-- Chained filter expressions
SELECT * FROM jsonb_path_query(
    '{"items": [{"name": "a", "price": 10, "qty": 5}, {"name": "b", "price": 25, "qty": 2}, {"name": "c", "price": 5, "qty": 100}]}'::JSONB,
    '$.items[*] ? (@.price > 3) ? (@.qty > 3)'
);

-- Recursive descent — $.** selects all elements at every level
SELECT * FROM jsonb_path_query('{"a": {"b": 1, "c": {"d": 2}}}'::JSONB, 'strict $.**.d');

SELECT * FROM jsonb_path_query(
    '{"x": 1, "y": {"x": 2, "z": {"x": 3}}}'::JSONB,
    'strict $.**.x'
);

-- Path arithmetic and methods
SELECT jsonb_path_query('[2]'::JSONB, '$[0] + 3') AS addition;
-- expect 5

SELECT jsonb_path_query('[8.5]'::JSONB, '$[0] / 2') AS division;

-- .type() — returns the type of JSON item
SELECT jsonb_path_query_array('[1, "two", true, null, {}, []]'::JSONB, '$[*].type()') AS types;

-- .size() — returns number of array elements
SELECT jsonb_path_query('{"arr": [1, 2, 3]}'::JSONB, '$.arr.size()') AS arr_size;
-- expect 3

-- .double() — convert string/number to double
SELECT jsonb_path_query('"3.14"'::JSONB, '$.double()') AS to_double;

-- .ceiling(), .floor(), .abs()
SELECT jsonb_path_query('3.7'::JSONB, '$.ceiling()') AS ceil_val;
-- expect 4
SELECT jsonb_path_query('3.7'::JSONB, '$.floor()') AS floor_val;
-- expect 3
SELECT jsonb_path_query('-5'::JSONB, '$.abs()') AS abs_val;
-- expect 5

-- .keyvalue() — returns key-value pairs of an object
SELECT * FROM jsonb_path_query('{"name": "Alice", "age": 30}'::JSONB, '$.keyvalue()');

-- Path variables with PASSING clause
SELECT jsonb_path_exists(
    '{"prices": [5, 10, 15, 20]}'::JSONB,
    '$.prices[*] ? (@ > $min)',
    '{"min": 12}'
) AS has_expensive;
-- expect true

SELECT * FROM jsonb_path_query(
    '{"a": [1, 2, 3, 4, 5]}'::JSONB,
    '$.a[*] ? (@ >= $min && @ <= $max)',
    '{"min": 2, "max": 4}'
);
-- expect 2, 3, 4

SELECT jsonb_path_query_array(
    '{"a": [1, 2, 3, 4, 5]}'::JSONB,
    '$.a[*] ? (@ >= $min && @ <= $max)',
    '{"min": 2, "max": 4}'
) AS range_matches;
-- expect [2, 3, 4]

-- -----------------------------------------------------------------------------
-- TODO [P4] IS JSON predicate (PG 16+), SQL/JSON standard functions (PG 17+)
-- -----------------------------------------------------------------------------

-- IS JSON predicate (PG 16+)
SELECT '{"a": 1}'  IS JSON          AS is_json;
SELECT '{"a": 1}'  IS JSON OBJECT   AS is_object;
SELECT '[1, 2, 3]' IS JSON ARRAY    AS is_array;
SELECT '123'       IS JSON SCALAR   AS is_scalar;
SELECT 'not json'  IS JSON          AS not_json;

-- IS NOT JSON
SELECT 'hello' IS NOT JSON AS is_not_json;

-- SQL/JSON standard query functions (PG 17+)
-- These may not be available in all environments; commented out for safety.

-- JSON_EXISTS — test whether a path expression yields any items
-- SELECT JSON_EXISTS(jsonb '{"key1": [1, 2, 3]}', 'strict $.key1[*] ? (@ > $x)' PASSING 2 AS x) AS jexists;

-- JSON_VALUE — extract a scalar value
-- SELECT JSON_VALUE(jsonb '"123.45"', '$' RETURNING float) AS jval;
-- SELECT JSON_VALUE(jsonb '[1, 2]', 'strict $[$off]' PASSING 1 AS off) AS jval_idx;

-- JSON_QUERY — extract a JSON object or array
-- SELECT JSON_QUERY(jsonb '[1, [2, 3], null]', 'lax $[*][$off]' PASSING 1 AS off WITH CONDITIONAL WRAPPER) AS jquery;
