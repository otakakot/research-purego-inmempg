-- ============================================================================
-- Section 3.5: JSON Operators
-- ============================================================================
-- TODO: Verify JSON/JSONB operator support in pure-Go implementation
-- Priority levels noted per operator group

-- ----------------------------------------------------------------------------
-- P2: -> (element access as JSON) and ->> (element access as text)
-- TODO: Verify both integer index and text key access
-- ----------------------------------------------------------------------------

-- Object field access
SELECT '{"a": 1, "b": 2}'::jsonb -> 'a' AS arrow_key;
SELECT '{"a": 1, "b": 2}'::jsonb ->> 'a' AS arrow_text_key;

-- Nested object access
SELECT '{"a": {"b": 1}}'::jsonb -> 'a' -> 'b' AS arrow_nested;
SELECT '{"a": {"b": 1}}'::jsonb -> 'a' ->> 'b' AS arrow_nested_text;

-- Array index access
SELECT '[10, 20, 30]'::jsonb -> 0 AS arrow_idx_first;
SELECT '[10, 20, 30]'::jsonb -> 2 AS arrow_idx_last;
SELECT '[10, 20, 30]'::jsonb -> -1 AS arrow_idx_neg;
SELECT '[10, 20, 30]'::jsonb ->> 1 AS arrow_idx_text;

-- NULL / missing key
SELECT '{"a": 1}'::jsonb -> 'missing' AS arrow_missing;
SELECT '{"a": null}'::jsonb -> 'a' AS arrow_json_null;
SELECT '{"a": null}'::jsonb ->> 'a' AS arrow_text_null;

-- ----------------------------------------------------------------------------
-- P2: #> (path access as JSON) and #>> (path access as text)
-- TODO: Verify path-based access with text array
-- ----------------------------------------------------------------------------

SELECT '{"a": {"b": {"c": 42}}}'::jsonb #> '{a,b,c}' AS path_deep;
SELECT '{"a": {"b": {"c": 42}}}'::jsonb #>> '{a,b,c}' AS path_deep_text;

SELECT '{"a": [10, 20, 30]}'::jsonb #> '{a,1}' AS path_array;
SELECT '{"a": [10, 20, 30]}'::jsonb #>> '{a,1}' AS path_array_text;

SELECT '{"a": 1}'::jsonb #> '{missing}' AS path_missing;

-- ----------------------------------------------------------------------------
-- P2: @> (contains) and <@ (contained by)
-- TODO: Verify containment operators for JSONB
-- ----------------------------------------------------------------------------

SELECT '{"a": 1, "b": 2}'::jsonb @> '{"a": 1}'::jsonb AS contains_true;
SELECT '{"a": 1}'::jsonb @> '{"a": 1, "b": 2}'::jsonb AS contains_false;
SELECT '{"a": 1, "b": 2}'::jsonb @> '{}'::jsonb AS contains_empty;

SELECT '[1, 2, 3]'::jsonb @> '[1, 3]'::jsonb AS contains_array;
SELECT '[1, 2]'::jsonb @> '[1, 2, 3]'::jsonb AS contains_array_false;

-- Contained by (<@ is reverse of @>)
SELECT '{"a": 1}'::jsonb <@ '{"a": 1, "b": 2}'::jsonb AS contained_by_true;
SELECT '{"a": 1, "b": 2}'::jsonb <@ '{"a": 1}'::jsonb AS contained_by_false;

-- ----------------------------------------------------------------------------
-- P2: ? (key exists)
-- TODO: Verify key existence operator
-- ----------------------------------------------------------------------------

SELECT '{"a": 1, "b": 2}'::jsonb ? 'a' AS has_key_true;
SELECT '{"a": 1, "b": 2}'::jsonb ? 'c' AS has_key_false;
SELECT '{"a": null}'::jsonb ? 'a' AS has_key_null_val;

-- Top-level string in array
SELECT '["foo", "bar"]'::jsonb ? 'foo' AS has_elem_true;
SELECT '["foo", "bar"]'::jsonb ? 'baz' AS has_elem_false;

-- ----------------------------------------------------------------------------
-- P3: ?| (any key exists) and ?& (all keys exist)
-- TODO: Verify multi-key existence operators
-- ----------------------------------------------------------------------------

SELECT '{"a": 1, "b": 2, "c": 3}'::jsonb ?| array['a', 'x'] AS any_key_true;
SELECT '{"a": 1, "b": 2}'::jsonb ?| array['x', 'y'] AS any_key_false;

SELECT '{"a": 1, "b": 2, "c": 3}'::jsonb ?& array['a', 'b'] AS all_keys_true;
SELECT '{"a": 1, "b": 2}'::jsonb ?& array['a', 'x'] AS all_keys_false;

-- ----------------------------------------------------------------------------
-- P3: @? (jsonpath exists) and @@ (jsonpath predicate)
-- TODO: Verify jsonpath support (PostgreSQL 12+)
-- ----------------------------------------------------------------------------

SELECT '{"a": 1, "b": 2}'::jsonb @? '$.a' AS jsonpath_exists_true;
SELECT '{"a": 1}'::jsonb @? '$.c' AS jsonpath_exists_false;
SELECT '[1, 2, 3]'::jsonb @? '$[*] ? (@ > 2)' AS jsonpath_filter;

SELECT '{"a": 1}'::jsonb @@ '$.a == 1' AS jsonpath_pred_true;
SELECT '{"a": 1}'::jsonb @@ '$.a == 2' AS jsonpath_pred_false;
SELECT '[1, 2, 3, 4, 5]'::jsonb @@ '$[*] > 3' AS jsonpath_pred_array;

-- ----------------------------------------------------------------------------
-- P3: #- (delete path)
-- TODO: Verify path deletion operator
-- ----------------------------------------------------------------------------

SELECT '{"a": 1, "b": 2}'::jsonb #- '{a}' AS delete_key;
SELECT '{"a": {"b": 1, "c": 2}}'::jsonb #- '{a,b}' AS delete_nested;
SELECT '[0, 1, 2, 3]'::jsonb #- '{1}' AS delete_array_idx;

-- Delete non-existent path (should return unchanged)
SELECT '{"a": 1}'::jsonb #- '{missing}' AS delete_missing;
