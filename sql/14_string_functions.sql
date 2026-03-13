-- =============================================================================
-- Section 4.2: String Functions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TODO [P1] length, char_length, lower, upper, trim, ltrim, rtrim, substring,
--           position, replace, concat, concat_ws
-- -----------------------------------------------------------------------------

-- length / char_length
SELECT length('hello') AS len_hello, char_length('hello') AS charlen_hello;
SELECT length('日本語') AS len_multibyte, char_length('日本語') AS charlen_multibyte;

-- lower / upper
SELECT lower('Hello World') AS lower_hw, upper('Hello World') AS upper_hw;

-- trim / ltrim / rtrim
SELECT trim('  hello  ') AS trim_both;
SELECT trim(leading ' ' from '  hello  ') AS trim_leading;
SELECT trim(trailing ' ' from '  hello  ') AS trim_trailing;
SELECT ltrim('xxhello', 'x') AS ltrim_x, rtrim('helloxx', 'x') AS rtrim_x;

-- substring(string FROM start FOR count)
SELECT substring('PostgreSQL' FROM 1 FOR 8) AS substr_1_8;
SELECT substring('PostgreSQL' FROM 8) AS substr_from8;

-- position(substring IN string)
SELECT position('gre' IN 'PostgreSQL') AS pos_gre;
SELECT position('xyz' IN 'PostgreSQL') AS pos_missing;

-- replace(string, from, to)
SELECT replace('Hello World', 'World', 'PostgreSQL') AS replaced;

-- concat / concat_ws
SELECT concat('Hello', ' ', 'World') AS concat_hw;
SELECT concat_ws(', ', 'one', 'two', 'three') AS concat_ws_csv;
SELECT concat_ws('-', 2024, 1, 15) AS concat_ws_date;

-- -----------------------------------------------------------------------------
-- TODO [P2] octet_length, split_part, left, right, repeat, reverse, lpad,
--           rpad, initcap, starts_with, string_to_array, array_to_string,
--           regexp_match, regexp_matches, regexp_replace, regexp_split_to_array,
--           format, md5, encode, decode, quote_ident, quote_literal, chr, ascii,
--           strpos, translate, to_hex
-- -----------------------------------------------------------------------------

-- octet_length
SELECT octet_length('hello') AS oct_ascii, octet_length('日本語') AS oct_utf8;

-- split_part
SELECT split_part('one.two.three', '.', 2) AS split_2nd;

-- left / right
SELECT left('PostgreSQL', 4) AS left_4, right('PostgreSQL', 3) AS right_3;

-- repeat
SELECT repeat('ab', 3) AS repeat_ab3;

-- reverse
SELECT reverse('hello') AS rev_hello;

-- lpad / rpad
SELECT lpad('42', 5, '0') AS lpad_42, rpad('hi', 6, '!') AS rpad_hi;

-- initcap
SELECT initcap('hello world foo') AS initcap_hw;

-- starts_with
SELECT starts_with('PostgreSQL', 'Post') AS sw_true;
SELECT starts_with('PostgreSQL', 'post') AS sw_false;

-- string_to_array / array_to_string
SELECT string_to_array('one,two,three', ',') AS str_to_arr;
SELECT array_to_string(ARRAY['a','b','c'], '-') AS arr_to_str;

-- regexp_match: first match only
SELECT regexp_match('abc123def456', '\d+') AS re_match;

-- regexp_matches: all matches (with 'g' flag)
SELECT regexp_matches('abc123def456', '\d+', 'g') AS re_matches;

-- regexp_replace
SELECT regexp_replace('Hello 123 World 456', '\d+', '#', 'g') AS re_replace;

-- regexp_split_to_array
SELECT regexp_split_to_array('one1two2three', '\d') AS re_split_arr;

-- format
SELECT format('Hello, %s! You are %s years old.', 'Alice', 30) AS formatted;
SELECT format('Value: %10s', 'test') AS fmt_padded;

-- md5
SELECT md5('hello') AS md5_hello;

-- encode / decode
SELECT encode('hello'::bytea, 'base64') AS enc_b64;
SELECT encode('hello'::bytea, 'hex') AS enc_hex;
SELECT convert_from(decode('aGVsbG8=', 'base64'), 'UTF8') AS dec_b64;

-- quote_ident / quote_literal
SELECT quote_ident('simple') AS qi_simple, quote_ident('has space') AS qi_space;
SELECT quote_literal('it''s') AS ql_apos;

-- chr / ascii
SELECT chr(65) AS chr_65, ascii('A') AS ascii_A;

-- strpos
SELECT strpos('PostgreSQL', 'gre') AS strpos_gre;

-- translate
SELECT translate('12345abcde', '135ace', 'XYZ') AS translated;

-- to_hex
SELECT to_hex(255) AS hex_255, to_hex(4096) AS hex_4096;

-- -----------------------------------------------------------------------------
-- TODO [P3] regexp_split_to_table
-- -----------------------------------------------------------------------------

SELECT * FROM regexp_split_to_table('one1two2three', '\d');
