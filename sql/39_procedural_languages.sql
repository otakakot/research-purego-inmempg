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
