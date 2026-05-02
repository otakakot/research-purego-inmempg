-- =============================================================================
-- Section 4.8: JSON Functions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TODO [P2] to_json, to_jsonb, json_build_object, jsonb_build_object,
--           json_build_array, jsonb_build_array, json_typeof, json_array_length,
--           json_array_elements, json_each, json_each_text, json_object_keys,
--           json_extract_path, jsonb_set, jsonb_insert, jsonb_strip_nulls,
--           row_to_json
-- -----------------------------------------------------------------------------

-- to_json / to_jsonb
SELECT to_json('hello'::TEXT) AS json_str;
SELECT to_json(42) AS json_int;
SELECT to_json(ARRAY[1,2,3]) AS json_arr;
SELECT to_jsonb('hello'::TEXT) AS jsonb_str;

-- json_build_object / jsonb_build_object
SELECT json_build_object('name', 'Alice', 'age', 30) AS jobj;
SELECT jsonb_build_object('key', 'value', 'num', 42) AS jbobj;

-- json_build_array / jsonb_build_array
SELECT json_build_array(1, 'two', 3.0, TRUE, NULL) AS jarr;
SELECT jsonb_build_array(1, 'two', 3.0) AS jbarr;

-- json_typeof
SELECT json_typeof('123'::JSON) AS t_num;
SELECT json_typeof('"hello"'::JSON) AS t_str;
SELECT json_typeof('true'::JSON) AS t_bool;
SELECT json_typeof('null'::JSON) AS t_null;
SELECT json_typeof('[1,2]'::JSON) AS t_arr;
SELECT json_typeof('{"a":1}'::JSON) AS t_obj;

-- json_array_length
SELECT json_array_length('[1,2,3,4,5]'::JSON) AS arr_len;

-- json_array_elements
SELECT * FROM json_array_elements('[1, "two", true, null]'::JSON);

-- json_each / json_each_text
SELECT * FROM json_each('{"a":1,"b":"hello","c":true}'::JSON);
SELECT * FROM json_each_text('{"a":1,"b":"hello","c":true}'::JSON);

-- json_object_keys
SELECT * FROM json_object_keys('{"name":"Alice","age":30,"city":"NYC"}'::JSON);

-- json_extract_path / json_extract_path_text
SELECT json_extract_path('{"a":{"b":{"c":42}}}'::JSON, 'a', 'b', 'c') AS nested_val;
SELECT json_extract_path_text('{"a":{"b":"hello"}}'::JSON, 'a', 'b') AS nested_text;

-- -> and ->> operators
SELECT '{"name":"Alice","age":30}'::JSON -> 'name' AS json_arrow;
SELECT '{"name":"Alice","age":30}'::JSON ->> 'name' AS json_arrow_text;
SELECT '[10,20,30]'::JSON -> 1 AS json_arr_idx;
SELECT '[10,20,30]'::JSON ->> 1 AS json_arr_idx_text;

-- jsonb operators: @>, <@, ?, ?|, ?&
SELECT '{"a":1,"b":2}'::JSONB @> '{"a":1}'::JSONB AS contains;
SELECT '{"a":1}'::JSONB <@ '{"a":1,"b":2}'::JSONB AS contained_by;
SELECT '{"a":1,"b":2}'::JSONB ? 'a' AS has_key;
SELECT '{"a":1,"b":2}'::JSONB ?| ARRAY['a','c'] AS has_any;
SELECT '{"a":1,"b":2}'::JSONB ?& ARRAY['a','b'] AS has_all;

-- jsonb_set
SELECT jsonb_set('{"a":1,"b":2}'::JSONB, '{b}', '99') AS jb_set;
SELECT jsonb_set('{"a":{"b":1}}'::JSONB, '{a,c}', '"new"', TRUE) AS jb_set_create;

-- jsonb_insert
SELECT jsonb_insert('{"a":[1,2]}'::JSONB, '{a,1}', '99') AS jb_insert;

-- jsonb_strip_nulls
SELECT jsonb_strip_nulls('{"a":1,"b":null,"c":3}'::JSONB) AS stripped;

-- row_to_json
SELECT row_to_json(t) FROM (SELECT 1 AS id, 'Alice' AS name, 30 AS age) t;

-- -----------------------------------------------------------------------------
-- TODO [P3] json_populate_record, json_to_record, jsonb_path_exists,
--           jsonb_path_query, jsonb_pretty
-- -----------------------------------------------------------------------------

-- json_to_record
SELECT * FROM json_to_record('{"id":1,"name":"Alice","age":30}'::JSON)
    AS t(id INT, name TEXT, age INT);

-- jsonb_path_exists (SQL/JSON path)
SELECT jsonb_path_exists('{"a":{"b":42}}'::JSONB, '$.a.b') AS path_exists;

-- jsonb_path_query
SELECT * FROM jsonb_path_query('[1,2,3,4,5]'::JSONB, '$[*] ? (@ > 3)');

-- jsonb_pretty
SELECT jsonb_pretty('{"a":1,"b":{"c":[1,2,3]}}'::JSONB) AS pretty;

-- json_populate_record
DROP TABLE IF EXISTS json_rec_test;
CREATE TABLE json_rec_test (id INT, name TEXT, active BOOLEAN);
SELECT * FROM json_populate_record(NULL::json_rec_test,
    '{"id":1,"name":"Alice","active":true}'::JSON);
DROP TABLE IF EXISTS json_rec_test;

-- -----------------------------------------------------------------------------
-- TODO [P3] jsonb_path_query_array, jsonb_path_query_first, jsonb_path_match
-- -----------------------------------------------------------------------------

-- jsonb_path_query_array — returns all matches as a JSON array
SELECT jsonb_path_query_array('[1,2,3,4,5]'::JSONB, '$[*] ? (@ > 2)') AS matches;
-- expect [3, 4, 5]

-- jsonb_path_query_first — returns first match
SELECT jsonb_path_query_first('[1,2,3,4,5]'::JSONB, '$[*] ? (@ > 2)') AS first_match;
-- expect 3

-- jsonb_path_match — returns boolean for predicate
SELECT jsonb_path_match('{"a":10}'::JSONB, '$.a > 5') AS is_gt_5;
-- expect true

-- jsonb_path_query with nested objects
SELECT * FROM jsonb_path_query(
    '{"items":[{"name":"a","price":10},{"name":"b","price":20},{"name":"c","price":5}]}'::JSONB,
    '$.items[*] ? (@.price > 8)'
);

-- jsonb_path_exists with variables (PASSING clause)
SELECT jsonb_path_exists(
    '{"prices":[5,10,15,20]}'::JSONB,
    '$.prices[*] ? (@ > $min)',
    '{"min": 12}'
) AS has_expensive;

-- -----------------------------------------------------------------------------
-- TODO [P3] jsonb_object_agg — aggregate key-value pairs
-- -----------------------------------------------------------------------------

SELECT jsonb_object_agg(k, v) FROM (VALUES ('a', 1), ('b', 2), ('c', 3)) AS t(k, v);

-- jsonb_agg with ORDER BY (PG 16+ for ordered set)
SELECT jsonb_agg(v ORDER BY v DESC) FROM (VALUES (1), (3), (2)) AS t(v);
