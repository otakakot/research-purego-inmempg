-- =============================================================================
-- Section 11.1: Procedural Languages
-- =============================================================================

-- =============================================================================
-- TODO [P2]: SQL function — pure SQL user-defined function
-- =============================================================================

CREATE FUNCTION add_numbers(a INT, b INT)
RETURNS INT
LANGUAGE SQL
AS $$
    SELECT a + b;
$$;

SELECT add_numbers(3, 7) AS result;  -- expect 10

-- SQL function returning a table
CREATE FUNCTION get_even_numbers(max_val INT)
RETURNS TABLE (n INT)
LANGUAGE SQL
AS $$
    SELECT generate_series(2, max_val, 2);
$$;

SELECT * FROM get_even_numbers(10);

DROP FUNCTION get_even_numbers(INT);
DROP FUNCTION add_numbers(INT, INT);

-- =============================================================================
-- TODO [P3]: PL/pgSQL — procedural language with control flow
-- =============================================================================

CREATE FUNCTION factorial(n INT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    result BIGINT := 1;
    i INT;
BEGIN
    FOR i IN 1..n LOOP
        result := result * i;
    END LOOP;
    RETURN result;
END;
$$;

SELECT factorial(5) AS result;  -- expect 120
SELECT factorial(0) AS result;  -- expect 1

-- PL/pgSQL with IF/ELSE
CREATE FUNCTION classify_score(score INT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    IF score >= 90 THEN
        RETURN 'excellent';
    ELSIF score >= 70 THEN
        RETURN 'good';
    ELSIF score >= 50 THEN
        RETURN 'pass';
    ELSE
        RETURN 'fail';
    END IF;
END;
$$;

SELECT classify_score(95), classify_score(75), classify_score(40);

-- PL/pgSQL with EXCEPTION handling
CREATE FUNCTION safe_divide(a NUMERIC, b NUMERIC)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN a / b;
EXCEPTION
    WHEN division_by_zero THEN
        RETURN NULL;
END;
$$;

SELECT safe_divide(10, 3), safe_divide(10, 0);

DROP FUNCTION safe_divide(NUMERIC, NUMERIC);
DROP FUNCTION classify_score(INT);
DROP FUNCTION factorial(INT);

-- =============================================================================
-- TODO [P3]: CREATE PROCEDURE + CALL — stored procedure (PG 11+)
-- =============================================================================

CREATE TABLE proc_test (id SERIAL PRIMARY KEY, val INT DEFAULT 0);
INSERT INTO proc_test (val) VALUES (10), (20), (30);

CREATE PROCEDURE increment_all(step INT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE proc_test SET val = val + step;
END;
$$;

CALL increment_all(5);
SELECT * FROM proc_test;  -- expect 15, 25, 35

DROP PROCEDURE increment_all(INT);
DROP TABLE proc_test;

-- =============================================================================
-- TODO [P3]: OUT / INOUT parameters
-- =============================================================================

CREATE FUNCTION get_min_max(arr INT[], OUT min_val INT, OUT max_val INT)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT MIN(v), MAX(v) INTO min_val, max_val FROM unnest(arr) AS v;
END;
$$;

SELECT * FROM get_min_max(ARRAY[3,1,4,1,5,9]);  -- expect min_val=1, max_val=9

CREATE FUNCTION double_val(INOUT val INT)
LANGUAGE plpgsql
AS $$
BEGIN
    val := val * 2;
END;
$$;

SELECT double_val(21);  -- expect 42

DROP FUNCTION double_val(INT);
DROP FUNCTION get_min_max(INT[]);

-- =============================================================================
-- TODO [P3]: SECURITY DEFINER / INVOKER
-- =============================================================================

CREATE FUNCTION secure_func()
RETURNS TEXT
LANGUAGE SQL
SECURITY DEFINER
AS $$
    SELECT current_user::TEXT;
$$;

SELECT secure_func();
DROP FUNCTION secure_func();

-- =============================================================================
-- TODO [P3]: PARALLEL SAFE / UNSAFE / RESTRICTED
-- =============================================================================

CREATE FUNCTION parallel_safe_add(a INT, b INT)
RETURNS INT
LANGUAGE SQL
PARALLEL SAFE
AS $$
    SELECT a + b;
$$;

SELECT parallel_safe_add(1, 2);
DROP FUNCTION parallel_safe_add(INT, INT);

-- =============================================================================
-- TODO [P3]: Dynamic SQL with EXECUTE
-- =============================================================================

CREATE FUNCTION dynamic_query(tbl TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    cnt BIGINT;
BEGIN
    EXECUTE format('SELECT COUNT(*) FROM %I', tbl) INTO cnt;
    RETURN cnt;
END;
$$;

CREATE TABLE dyn_test (id INT);
INSERT INTO dyn_test VALUES (1), (2), (3);
SELECT dynamic_query('dyn_test');  -- expect 3

DROP TABLE dyn_test;
DROP FUNCTION dynamic_query(TEXT);

-- =============================================================================
-- TODO [P3]: PERFORM — execute a query discarding results (PL/pgSQL)
-- =============================================================================

CREATE FUNCTION perform_test()
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pg_sleep(0);  -- discard result
END;
$$;

SELECT perform_test();
DROP FUNCTION perform_test();

-- =============================================================================
-- TODO [P3]: GET STACKED DIAGNOSTICS — detailed exception info
-- =============================================================================

CREATE FUNCTION diag_test(val INT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    msg TEXT;
    detail TEXT;
BEGIN
    PERFORM val / 0;
    RETURN 'ok';
EXCEPTION
    WHEN division_by_zero THEN
        GET STACKED DIAGNOSTICS
            msg = MESSAGE_TEXT,
            detail = PG_EXCEPTION_DETAIL;
        RETURN 'caught: ' || msg;
END;
$$;

SELECT diag_test(1);  -- expect 'caught: division by zero'
DROP FUNCTION diag_test(INT);

-- =============================================================================
-- TODO [P4]: PL/Python — test CREATE EXTENSION (may not be available)
-- =============================================================================

-- CREATE EXTENSION IF NOT EXISTS plpythonu;
-- CREATE FUNCTION py_hello(name TEXT)
-- RETURNS TEXT
-- LANGUAGE plpythonu
-- AS $$
--     return "Hello, " + name
-- $$;
-- SELECT py_hello('world');
-- DROP FUNCTION py_hello(TEXT);

-- =============================================================================
-- TODO [P4]: PL/Perl — test CREATE EXTENSION (may not be available)
-- =============================================================================

-- CREATE EXTENSION IF NOT EXISTS plperl;
-- CREATE FUNCTION perl_hello(name TEXT)
-- RETURNS TEXT
-- LANGUAGE plperl
-- AS $$
--     my $name = $_[0];
--     return "Hello, $name";
-- $$;
-- SELECT perl_hello('world');
-- DROP FUNCTION perl_hello(TEXT);
