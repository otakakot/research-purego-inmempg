-- =============================================================================
-- Section 4.7: Type Cast Functions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TODO [P1] CAST(expr AS type), expr::type
-- -----------------------------------------------------------------------------

-- CAST syntax
SELECT CAST(42 AS TEXT) AS int_to_text;
SELECT CAST('3.14' AS NUMERIC) AS text_to_num;
SELECT CAST('2024-06-15' AS DATE) AS text_to_date;
SELECT CAST('2024-06-15 10:30:00' AS TIMESTAMP) AS text_to_ts;
SELECT CAST(TRUE AS INTEGER) AS bool_to_int;
SELECT CAST(1 AS BOOLEAN) AS int_to_bool;

-- :: shorthand syntax
SELECT 42::TEXT AS int_to_text;
SELECT '3.14'::NUMERIC AS text_to_num;
SELECT '2024-06-15'::DATE AS text_to_date;
SELECT '2024-06-15 10:30:00'::TIMESTAMP AS text_to_ts;
SELECT 42::FLOAT8 AS int_to_float;
SELECT 3.14::INTEGER AS float_to_int;

-- Cast within expressions
SELECT 'Total: ' || 42::TEXT AS concatenated;
SELECT length(12345::TEXT) AS digit_count;

-- Array casts
SELECT '{1,2,3}'::INT[] AS text_to_int_arr;
SELECT ARRAY[1,2,3]::TEXT[] AS int_arr_to_text;

-- -----------------------------------------------------------------------------
-- TODO [P2] to_char, to_number, to_date, to_timestamp
-- -----------------------------------------------------------------------------

-- to_char(numeric, format)
SELECT to_char(1234567.89, '9,999,999.99') AS fmt_num;
SELECT to_char(0.5, '990.00%') AS fmt_pct;
SELECT to_char(42, '000099') AS fmt_padded;

-- to_char(timestamp, format)
SELECT to_char(TIMESTAMP '2024-06-15 10:30:45', 'YYYY-MM-DD') AS fmt_date;
SELECT to_char(TIMESTAMP '2024-06-15 10:30:45', 'HH12:MI:SS AM') AS fmt_time;
SELECT to_char(TIMESTAMP '2024-06-15', 'Day') AS fmt_day_name;
SELECT to_char(TIMESTAMP '2024-06-15', 'Mon DD, YYYY') AS fmt_short;

-- to_number(text, format)
SELECT to_number('1,234,567.89', '9,999,999.99') AS parsed_num;
SELECT to_number('$1,000.50', 'L9,999.99') AS parsed_currency;

-- to_date(text, format)
SELECT to_date('2024-06-15', 'YYYY-MM-DD') AS parsed_date;
SELECT to_date('15/06/2024', 'DD/MM/YYYY') AS parsed_date_eu;
SELECT to_date('June 15, 2024', 'Month DD, YYYY') AS parsed_date_long;

-- to_timestamp(text, format)
SELECT to_timestamp('2024-06-15 10:30:45', 'YYYY-MM-DD HH24:MI:SS') AS parsed_ts;
SELECT to_timestamp('15-Jun-2024 03:30 PM', 'DD-Mon-YYYY HH12:MI AM') AS parsed_ts2;
