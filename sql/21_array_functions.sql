-- =============================================================================
-- Section 4.9: Array Functions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TODO [P2] array_length, array_dims, array_lower, array_upper, array_append,
--           array_prepend, array_cat, array_remove, array_replace,
--           array_position, array_positions, unnest, cardinality
-- -----------------------------------------------------------------------------

-- array_length(array, dimension)
SELECT array_length(ARRAY[1,2,3,4,5], 1) AS arr_len;
SELECT array_length(ARRAY[[1,2],[3,4],[5,6]], 1) AS arr_len_dim1;
SELECT array_length(ARRAY[[1,2],[3,4],[5,6]], 2) AS arr_len_dim2;

-- array_dims
SELECT array_dims(ARRAY[1,2,3]) AS dims_1d;
SELECT array_dims(ARRAY[[1,2],[3,4]]) AS dims_2d;

-- array_lower / array_upper
SELECT array_lower(ARRAY[10,20,30], 1) AS lower_bound;
SELECT array_upper(ARRAY[10,20,30], 1) AS upper_bound;

-- array_append
SELECT array_append(ARRAY[1,2,3], 4) AS appended;

-- array_prepend
SELECT array_prepend(0, ARRAY[1,2,3]) AS prepended;

-- array_cat
SELECT array_cat(ARRAY[1,2], ARRAY[3,4]) AS concatenated;

-- array_remove
SELECT array_remove(ARRAY[1,2,3,2,1], 2) AS removed_twos;

-- array_replace
SELECT array_replace(ARRAY[1,2,3,2,1], 2, 99) AS replaced;

-- array_position / array_positions
SELECT array_position(ARRAY['a','b','c','b'], 'b') AS first_b;
SELECT array_positions(ARRAY['a','b','c','b'], 'b') AS all_b;

-- unnest
SELECT unnest(ARRAY[10,20,30]) AS val;
SELECT unnest(ARRAY['x','y','z']) AS letter;

-- unnest with multiple arrays (parallel unnest)
SELECT * FROM unnest(ARRAY[1,2,3], ARRAY['a','b','c']) AS t(num, letter);

-- cardinality
SELECT cardinality(ARRAY[1,2,3,4,5]) AS card_1d;
SELECT cardinality(ARRAY[[1,2],[3,4],[5,6]]) AS card_2d;

-- Array operators: || (concatenation), @> (contains), <@ (contained by)
SELECT ARRAY[1,2] || ARRAY[3,4] AS concat_op;
SELECT ARRAY[1,2,3] @> ARRAY[1,3] AS contains;
SELECT ARRAY[1,3] <@ ARRAY[1,2,3] AS contained_by;
SELECT ARRAY[1,2,3] && ARRAY[3,4,5] AS overlap;

-- Array subscript access
SELECT (ARRAY[10,20,30])[2] AS second_elem;
SELECT (ARRAY[[1,2],[3,4]])[2][1] AS elem_2_1;

-- Array slice
SELECT (ARRAY[10,20,30,40,50])[2:4] AS slice_2_4;
