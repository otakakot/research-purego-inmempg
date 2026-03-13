-- ============================================================================
-- 06_data_types.sql — Section 2: Data Types
-- Tests data type support for pure-Go in-memory PostgreSQL implementation.
-- Each test creates a table with the type, inserts data, and selects it back.
-- ============================================================================

-- ============================================================================
-- Cleanup: Drop all test tables from previous runs
-- ============================================================================
DROP TABLE IF EXISTS test_dt_smallint;
DROP TABLE IF EXISTS test_dt_integer;
DROP TABLE IF EXISTS test_dt_bigint;
DROP TABLE IF EXISTS test_dt_numeric;
DROP TABLE IF EXISTS test_dt_real;
DROP TABLE IF EXISTS test_dt_double;
DROP TABLE IF EXISTS test_dt_smallserial;
DROP TABLE IF EXISTS test_dt_serial;
DROP TABLE IF EXISTS test_dt_bigserial;
DROP TABLE IF EXISTS test_dt_money;

DROP TABLE IF EXISTS test_dt_text;
DROP TABLE IF EXISTS test_dt_varchar;
DROP TABLE IF EXISTS test_dt_char;
DROP TABLE IF EXISTS test_dt_name;

DROP TABLE IF EXISTS test_dt_bytea;

DROP TABLE IF EXISTS test_dt_date;
DROP TABLE IF EXISTS test_dt_time;
DROP TABLE IF EXISTS test_dt_timetz;
DROP TABLE IF EXISTS test_dt_timestamp;
DROP TABLE IF EXISTS test_dt_timestamptz;
DROP TABLE IF EXISTS test_dt_interval;

DROP TABLE IF EXISTS test_dt_boolean;

DROP TABLE IF EXISTS test_dt_json;
DROP TABLE IF EXISTS test_dt_jsonb;
DROP TABLE IF EXISTS test_dt_jsonpath;

DROP TABLE IF EXISTS test_dt_uuid;

DROP TABLE IF EXISTS test_dt_int_array;
DROP TABLE IF EXISTS test_dt_text_array;

DROP TABLE IF EXISTS test_dt_inet;
DROP TABLE IF EXISTS test_dt_cidr;
DROP TABLE IF EXISTS test_dt_macaddr;
DROP TABLE IF EXISTS test_dt_macaddr8;

DROP TABLE IF EXISTS test_dt_point;
DROP TABLE IF EXISTS test_dt_line;
DROP TABLE IF EXISTS test_dt_lseg;
DROP TABLE IF EXISTS test_dt_box;
DROP TABLE IF EXISTS test_dt_path;
DROP TABLE IF EXISTS test_dt_polygon;
DROP TABLE IF EXISTS test_dt_circle;

DROP TABLE IF EXISTS test_dt_bit;
DROP TABLE IF EXISTS test_dt_varbit;

DROP TABLE IF EXISTS test_dt_tsvector;
DROP TABLE IF EXISTS test_dt_tsquery;

DROP TABLE IF EXISTS test_dt_int4range;
DROP TABLE IF EXISTS test_dt_int8range;
DROP TABLE IF EXISTS test_dt_numrange;
DROP TABLE IF EXISTS test_dt_tsrange;
DROP TABLE IF EXISTS test_dt_tstzrange;
DROP TABLE IF EXISTS test_dt_daterange;

DROP TABLE IF EXISTS test_dt_xml;
DROP TABLE IF EXISTS test_dt_pg_lsn;
DROP TABLE IF EXISTS test_dt_pg_snapshot;
DROP TABLE IF EXISTS test_dt_oid;
DROP TABLE IF EXISTS test_dt_regclass;
DROP TABLE IF EXISTS test_dt_regtype;
DROP TABLE IF EXISTS test_dt_regproc;
DROP TABLE IF EXISTS test_dt_void;
DROP TABLE IF EXISTS test_dt_record;
DROP TYPE  IF EXISTS test_dt_mood;
DROP TABLE IF EXISTS test_dt_enum;

-- ============================================================================
-- 2.1 Numeric Types
-- ============================================================================

-- TODO: 2.1.1 smallint/int2 (2 bytes) — P1
CREATE TABLE test_dt_smallint (id serial PRIMARY KEY, val smallint);
INSERT INTO test_dt_smallint (val) VALUES (0), (-32768), (32767);
SELECT * FROM test_dt_smallint;

-- TODO: 2.1.2 integer/int/int4 (4 bytes) — P1
CREATE TABLE test_dt_integer (id serial PRIMARY KEY, val integer);
INSERT INTO test_dt_integer (val) VALUES (0), (-2147483648), (2147483647);
SELECT * FROM test_dt_integer;

-- TODO: 2.1.3 bigint/int8 (8 bytes) — P1
CREATE TABLE test_dt_bigint (id serial PRIMARY KEY, val bigint);
INSERT INTO test_dt_bigint (val) VALUES (0), (-9223372036854775808), (9223372036854775807);
SELECT * FROM test_dt_bigint;

-- TODO: 2.1.4 numeric(p,s)/decimal — P2
CREATE TABLE test_dt_numeric (id serial PRIMARY KEY, val numeric(10,2));
INSERT INTO test_dt_numeric (val) VALUES (0.00), (12345678.99), (-12345678.99);
SELECT * FROM test_dt_numeric;

-- TODO: 2.1.5 real/float4 (4 bytes) — P1
CREATE TABLE test_dt_real (id serial PRIMARY KEY, val real);
INSERT INTO test_dt_real (val) VALUES (0.0), (3.14), (-3.14), ('NaN'), ('Infinity'), ('-Infinity');
SELECT * FROM test_dt_real;

-- TODO: 2.1.6 double precision/float8/float (8 bytes) — P1
CREATE TABLE test_dt_double (id serial PRIMARY KEY, val double precision);
INSERT INTO test_dt_double (val) VALUES (0.0), (3.141592653589793), (-3.141592653589793), ('NaN'), ('Infinity'), ('-Infinity');
SELECT * FROM test_dt_double;

-- TODO: 2.1.7 smallserial/serial2 — P2
CREATE TABLE test_dt_smallserial (id smallserial PRIMARY KEY, val text);
INSERT INTO test_dt_smallserial (val) VALUES ('first'), ('second'), ('third');
SELECT * FROM test_dt_smallserial;

-- TODO: 2.1.8 serial/serial4 — P1
CREATE TABLE test_dt_serial (id serial PRIMARY KEY, val text);
INSERT INTO test_dt_serial (val) VALUES ('first'), ('second'), ('third');
SELECT * FROM test_dt_serial;

-- TODO: 2.1.9 bigserial/serial8 — P1
CREATE TABLE test_dt_bigserial (id bigserial PRIMARY KEY, val text);
INSERT INTO test_dt_bigserial (val) VALUES ('first'), ('second'), ('third');
SELECT * FROM test_dt_bigserial;

-- TODO: 2.1.10 money — P4
CREATE TABLE test_dt_money (id serial PRIMARY KEY, val money);
INSERT INTO test_dt_money (val) VALUES ('$0.00'), ('$1,234.56'), ('-$99.99');
SELECT * FROM test_dt_money;

-- ============================================================================
-- 2.2 String Types
-- ============================================================================

-- TODO: 2.2.1 text — P1
CREATE TABLE test_dt_text (id serial PRIMARY KEY, val text);
INSERT INTO test_dt_text (val) VALUES (''), ('hello world'), ('日本語テスト'), (NULL);
SELECT * FROM test_dt_text;

-- TODO: 2.2.2 varchar(n)/character varying(n) — P1
CREATE TABLE test_dt_varchar (id serial PRIMARY KEY, val varchar(100));
INSERT INTO test_dt_varchar (val) VALUES (''), ('hello world'), ('日本語テスト'), (NULL);
SELECT * FROM test_dt_varchar;

-- TODO: 2.2.3 char(n)/character(n) — P2
CREATE TABLE test_dt_char (id serial PRIMARY KEY, val char(10));
INSERT INTO test_dt_char (val) VALUES ('abc'), ('1234567890'), ('');
SELECT * FROM test_dt_char;

-- TODO: 2.2.4 name — P2
CREATE TABLE test_dt_name (id serial PRIMARY KEY, val name);
INSERT INTO test_dt_name (val) VALUES ('my_table'), ('pg_catalog'), ('a_long_identifier_name');
SELECT * FROM test_dt_name;

-- ============================================================================
-- 2.3 Binary
-- ============================================================================

-- TODO: 2.3.1 bytea — P2
CREATE TABLE test_dt_bytea (id serial PRIMARY KEY, val bytea);
INSERT INTO test_dt_bytea (val) VALUES ('\x'), ('\xDEADBEEF'), ('\x00010203');
SELECT * FROM test_dt_bytea;

-- ============================================================================
-- 2.4 Date/Time Types
-- ============================================================================

-- TODO: 2.4.1 date — P1
CREATE TABLE test_dt_date (id serial PRIMARY KEY, val date);
INSERT INTO test_dt_date (val) VALUES ('2024-01-01'), ('1970-01-01'), ('9999-12-31');
SELECT * FROM test_dt_date;

-- TODO: 2.4.2 time (without time zone) — P2
CREATE TABLE test_dt_time (id serial PRIMARY KEY, val time);
INSERT INTO test_dt_time (val) VALUES ('00:00:00'), ('12:30:45'), ('23:59:59.999999');
SELECT * FROM test_dt_time;

-- TODO: 2.4.3 time with time zone/timetz — P2
CREATE TABLE test_dt_timetz (id serial PRIMARY KEY, val time with time zone);
INSERT INTO test_dt_timetz (val) VALUES ('12:00:00+00'), ('08:30:00+09'), ('23:59:59-05');
SELECT * FROM test_dt_timetz;

-- TODO: 2.4.4 timestamp (without time zone) — P1
CREATE TABLE test_dt_timestamp (id serial PRIMARY KEY, val timestamp);
INSERT INTO test_dt_timestamp (val) VALUES ('2024-01-01 00:00:00'), ('1970-01-01 12:00:00'), ('2024-06-15 23:59:59.999999');
SELECT * FROM test_dt_timestamp;

-- TODO: 2.4.5 timestamp with time zone/timestamptz — P1
CREATE TABLE test_dt_timestamptz (id serial PRIMARY KEY, val timestamp with time zone);
INSERT INTO test_dt_timestamptz (val) VALUES ('2024-01-01 00:00:00+00'), ('1970-01-01 12:00:00+09'), ('2024-06-15 23:59:59-05');
SELECT * FROM test_dt_timestamptz;

-- TODO: 2.4.6 interval — P2
CREATE TABLE test_dt_interval (id serial PRIMARY KEY, val interval);
INSERT INTO test_dt_interval (val) VALUES ('1 year'), ('2 hours 30 minutes'), ('-1 day 3 hours');
SELECT * FROM test_dt_interval;

-- ============================================================================
-- 2.5 Boolean
-- ============================================================================

-- TODO: 2.5.1 boolean — P1
CREATE TABLE test_dt_boolean (id serial PRIMARY KEY, val boolean);
INSERT INTO test_dt_boolean (val) VALUES (TRUE), (FALSE), (NULL);
SELECT * FROM test_dt_boolean;

-- ============================================================================
-- 2.6 JSON Types
-- ============================================================================

-- TODO: 2.6.1 json — P2
CREATE TABLE test_dt_json (id serial PRIMARY KEY, val json);
INSERT INTO test_dt_json (val) VALUES ('{}'), ('{"key": "value"}'), ('[1, 2, 3]'), ('null');
SELECT * FROM test_dt_json;

-- TODO: 2.6.2 jsonb — P2
CREATE TABLE test_dt_jsonb (id serial PRIMARY KEY, val jsonb);
INSERT INTO test_dt_jsonb (val) VALUES ('{}'), ('{"key": "value"}'), ('[1, 2, 3]'), ('null');
SELECT * FROM test_dt_jsonb;

-- TODO: 2.6.3 jsonpath — P3
CREATE TABLE test_dt_jsonpath (id serial PRIMARY KEY, val jsonpath);
INSERT INTO test_dt_jsonpath (val) VALUES ('$'), ('$.key'), ('$[0]');
SELECT * FROM test_dt_jsonpath;

-- ============================================================================
-- 2.7 UUID
-- ============================================================================

-- TODO: 2.7.1 uuid — P2
CREATE TABLE test_dt_uuid (id serial PRIMARY KEY, val uuid);
INSERT INTO test_dt_uuid (val) VALUES ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'), ('00000000-0000-0000-0000-000000000000');
SELECT * FROM test_dt_uuid;

-- ============================================================================
-- 2.8 Array Types
-- ============================================================================

-- TODO: 2.8.1 integer[] — P2
CREATE TABLE test_dt_int_array (id serial PRIMARY KEY, val integer[]);
INSERT INTO test_dt_int_array (val) VALUES ('{}'), ('{1,2,3}'), (ARRAY[4,5,6]);
SELECT * FROM test_dt_int_array;

-- TODO: 2.8.2 text[] — P2
CREATE TABLE test_dt_text_array (id serial PRIMARY KEY, val text[]);
INSERT INTO test_dt_text_array (val) VALUES ('{}'), ('{"hello","world"}'), (ARRAY['foo','bar']);
SELECT * FROM test_dt_text_array;

-- ============================================================================
-- 2.9 Network Types
-- ============================================================================

-- TODO: 2.9.1 inet — P3
CREATE TABLE test_dt_inet (id serial PRIMARY KEY, val inet);
INSERT INTO test_dt_inet (val) VALUES ('192.168.1.1'), ('192.168.1.0/24'), ('::1'), ('fe80::1/64');
SELECT * FROM test_dt_inet;

-- TODO: 2.9.2 cidr — P3
CREATE TABLE test_dt_cidr (id serial PRIMARY KEY, val cidr);
INSERT INTO test_dt_cidr (val) VALUES ('192.168.0.0/24'), ('10.0.0.0/8'), ('::1/128');
SELECT * FROM test_dt_cidr;

-- TODO: 2.9.3 macaddr — P4
CREATE TABLE test_dt_macaddr (id serial PRIMARY KEY, val macaddr);
INSERT INTO test_dt_macaddr (val) VALUES ('08:00:2b:01:02:03'), ('08-00-2b-01-02-03');
SELECT * FROM test_dt_macaddr;

-- TODO: 2.9.4 macaddr8 — P4
CREATE TABLE test_dt_macaddr8 (id serial PRIMARY KEY, val macaddr8);
INSERT INTO test_dt_macaddr8 (val) VALUES ('08:00:2b:01:02:03:04:05'), ('08-00-2b-01-02-03-04-05');
SELECT * FROM test_dt_macaddr8;

-- ============================================================================
-- 2.10 Geometric Types
-- ============================================================================

-- TODO: 2.10.1 point — P4
CREATE TABLE test_dt_point (id serial PRIMARY KEY, val point);
INSERT INTO test_dt_point (val) VALUES ('(0,0)'), ('(1.5,2.5)'), ('(-3,4)');
SELECT * FROM test_dt_point;

-- TODO: 2.10.2 line — P4
CREATE TABLE test_dt_line (id serial PRIMARY KEY, val line);
INSERT INTO test_dt_line (val) VALUES ('{1,2,3}'), ('{0,1,-1}');
SELECT * FROM test_dt_line;

-- TODO: 2.10.3 lseg — P4
CREATE TABLE test_dt_lseg (id serial PRIMARY KEY, val lseg);
INSERT INTO test_dt_lseg (val) VALUES ('[(0,0),(1,1)]'), ('[(-1,-1),(2,2)]');
SELECT * FROM test_dt_lseg;

-- TODO: 2.10.4 box — P4
CREATE TABLE test_dt_box (id serial PRIMARY KEY, val box);
INSERT INTO test_dt_box (val) VALUES ('(1,1),(0,0)'), ('(3,4),(1,2)');
SELECT * FROM test_dt_box;

-- TODO: 2.10.5 path — P4
CREATE TABLE test_dt_path (id serial PRIMARY KEY, val path);
INSERT INTO test_dt_path (val) VALUES ('((0,0),(1,1),(2,0))'), ('[(0,0),(1,0),(1,1)]');
SELECT * FROM test_dt_path;

-- TODO: 2.10.6 polygon — P4
CREATE TABLE test_dt_polygon (id serial PRIMARY KEY, val polygon);
INSERT INTO test_dt_polygon (val) VALUES ('((0,0),(1,0),(1,1),(0,1))'), ('((0,0),(2,0),(1,2))');
SELECT * FROM test_dt_polygon;

-- TODO: 2.10.7 circle — P4
CREATE TABLE test_dt_circle (id serial PRIMARY KEY, val circle);
INSERT INTO test_dt_circle (val) VALUES ('<(0,0),1>'), ('<(1,2),3.5>');
SELECT * FROM test_dt_circle;

-- ============================================================================
-- 2.11 Bit String Types
-- ============================================================================

-- TODO: 2.11.1 bit(n) — P4
CREATE TABLE test_dt_bit (id serial PRIMARY KEY, val bit(8));
INSERT INTO test_dt_bit (val) VALUES (B'00000000'), (B'11111111'), (B'10101010');
SELECT * FROM test_dt_bit;

-- TODO: 2.11.2 bit varying(n)/varbit — P4
CREATE TABLE test_dt_varbit (id serial PRIMARY KEY, val bit varying(16));
INSERT INTO test_dt_varbit (val) VALUES (B'0'), (B'101'), (B'1111000011110000');
SELECT * FROM test_dt_varbit;

-- ============================================================================
-- 2.12 Full Text Search Types
-- ============================================================================

-- TODO: 2.12.1 tsvector — P3
CREATE TABLE test_dt_tsvector (id serial PRIMARY KEY, val tsvector);
INSERT INTO test_dt_tsvector (val) VALUES ('a fat cat'), (to_tsvector('english', 'The quick brown fox'));
SELECT * FROM test_dt_tsvector;

-- TODO: 2.12.2 tsquery — P3
CREATE TABLE test_dt_tsquery (id serial PRIMARY KEY, val tsquery);
INSERT INTO test_dt_tsquery (val) VALUES ('fat & cat'), (to_tsquery('english', 'quick | fox'));
SELECT * FROM test_dt_tsquery;

-- ============================================================================
-- 2.13 Range Types
-- ============================================================================

-- TODO: 2.13.1 int4range — P3
CREATE TABLE test_dt_int4range (id serial PRIMARY KEY, val int4range);
INSERT INTO test_dt_int4range (val) VALUES ('[1,10)'), ('(0,100]'), ('empty');
SELECT * FROM test_dt_int4range;

-- TODO: 2.13.2 int8range — P3
CREATE TABLE test_dt_int8range (id serial PRIMARY KEY, val int8range);
INSERT INTO test_dt_int8range (val) VALUES ('[1,1000000000)'), ('(0,]');
SELECT * FROM test_dt_int8range;

-- TODO: 2.13.3 numrange — P3
CREATE TABLE test_dt_numrange (id serial PRIMARY KEY, val numrange);
INSERT INTO test_dt_numrange (val) VALUES ('[1.5,9.5)'), ('(0.0,)');
SELECT * FROM test_dt_numrange;

-- TODO: 2.13.4 tsrange — P3
CREATE TABLE test_dt_tsrange (id serial PRIMARY KEY, val tsrange);
INSERT INTO test_dt_tsrange (val) VALUES ('[2024-01-01,2024-12-31)'), ('(2024-06-01,2024-06-30]');
SELECT * FROM test_dt_tsrange;

-- TODO: 2.13.5 tstzrange — P3
CREATE TABLE test_dt_tstzrange (id serial PRIMARY KEY, val tstzrange);
INSERT INTO test_dt_tstzrange (val) VALUES ('[2024-01-01 00:00:00+00,2024-12-31 23:59:59+00)');
SELECT * FROM test_dt_tstzrange;

-- TODO: 2.13.6 daterange — P3
CREATE TABLE test_dt_daterange (id serial PRIMARY KEY, val daterange);
INSERT INTO test_dt_daterange (val) VALUES ('[2024-01-01,2024-12-31)'), ('(2024-06-01,2024-06-30]');
SELECT * FROM test_dt_daterange;

-- ============================================================================
-- 2.14 Other Types
-- ============================================================================

-- TODO: 2.14.1 xml — P4
CREATE TABLE test_dt_xml (id serial PRIMARY KEY, val xml);
INSERT INTO test_dt_xml (val) VALUES ('<root/>'), ('<doc><title>Hello</title></doc>');
SELECT * FROM test_dt_xml;

-- TODO: 2.14.2 pg_lsn — P4
CREATE TABLE test_dt_pg_lsn (id serial PRIMARY KEY, val pg_lsn);
INSERT INTO test_dt_pg_lsn (val) VALUES ('0/0'), ('16/B374D848');
SELECT * FROM test_dt_pg_lsn;

-- TODO: 2.14.3 pg_snapshot — P4
CREATE TABLE test_dt_pg_snapshot (id serial PRIMARY KEY, val pg_snapshot);
INSERT INTO test_dt_pg_snapshot (val) VALUES ('10:20:10,14,15');
SELECT * FROM test_dt_pg_snapshot;

-- TODO: 2.14.4 oid — P2
CREATE TABLE test_dt_oid (id serial PRIMARY KEY, val oid);
INSERT INTO test_dt_oid (val) VALUES (0), (1), (4294967295);
SELECT * FROM test_dt_oid;

-- TODO: 2.14.5 regclass — P2
CREATE TABLE test_dt_regclass (id serial PRIMARY KEY, val regclass);
INSERT INTO test_dt_regclass (val) VALUES ('pg_class'), ('pg_type');
SELECT * FROM test_dt_regclass;

-- TODO: 2.14.6 regtype — P2
CREATE TABLE test_dt_regtype (id serial PRIMARY KEY, val regtype);
INSERT INTO test_dt_regtype (val) VALUES ('integer'), ('text'), ('boolean');
SELECT * FROM test_dt_regtype;

-- TODO: 2.14.7 regproc — P4
CREATE TABLE test_dt_regproc (id serial PRIMARY KEY, val regproc);
INSERT INTO test_dt_regproc (val) VALUES ('now'), ('length'), ('upper');
SELECT * FROM test_dt_regproc;

-- TODO: 2.14.8 void — P2
-- void is a pseudo-type used only as function return type; test via function call
SELECT pg_sleep(0);

-- TODO: 2.14.9 record — P2
-- record is a pseudo-type; test via function returning record
SELECT row(1, 'hello', true) AS val;

-- TODO: 2.14.10 ENUM (user-defined) — P2
CREATE TYPE test_dt_mood AS ENUM ('sad', 'ok', 'happy');
CREATE TABLE test_dt_enum (id serial PRIMARY KEY, val test_dt_mood);
INSERT INTO test_dt_enum (val) VALUES ('sad'), ('ok'), ('happy');
SELECT * FROM test_dt_enum;
