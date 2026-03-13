-- ============================================================================
-- Section 3.3: Arithmetic Operators
-- ============================================================================
-- TODO: Verify arithmetic operator support and edge cases
-- Priority levels noted per operator group

-- ----------------------------------------------------------------------------
-- P1: Basic arithmetic (+, -, *, /, %)
-- ----------------------------------------------------------------------------

SELECT 2 + 3 AS add_int;
SELECT 2.5 + 3.5 AS add_float;
SELECT -1 + 1 AS add_neg;

SELECT 10 - 3 AS sub_int;
SELECT 1.5 - 0.5 AS sub_float;
SELECT 0 - 5 AS sub_neg;

SELECT 4 * 5 AS mul_int;
SELECT 2.5 * 4.0 AS mul_float;
SELECT -3 * 7 AS mul_neg;

SELECT 10 / 3 AS div_int;        -- integer division
SELECT 10.0 / 3.0 AS div_float;  -- decimal division
SELECT -10 / 3 AS div_neg;

SELECT 10 % 3 AS mod_int;
SELECT -10 % 3 AS mod_neg;
SELECT 10 % -3 AS mod_neg_divisor;

-- Unary minus
SELECT -(-5) AS unary_neg;
SELECT -(3 + 4) AS unary_expr;

-- NULL propagation
SELECT 1 + NULL AS add_null;
SELECT NULL * 5 AS mul_null;
SELECT NULL / 2 AS div_null;

-- ----------------------------------------------------------------------------
-- P2: Exponentiation (^)
-- TODO: Verify ^ is power operator (not XOR as in some systems)
-- ----------------------------------------------------------------------------

SELECT 2 ^ 3 AS power_int;
SELECT 2.0 ^ 10 AS power_float;
SELECT 9 ^ 0.5 AS power_sqrt;
SELECT 2 ^ -1 AS power_neg_exp;
SELECT 0 ^ 0 AS power_zero_zero;

-- ----------------------------------------------------------------------------
-- P4: Prefix / postfix operators (|/, ||/, !, @)
-- TODO: Verify prefix operator parsing support
-- ----------------------------------------------------------------------------

-- Square root
SELECT |/ 25 AS sqrt_25;
SELECT |/ 2.0 AS sqrt_2;

-- Cube root
SELECT ||/ 27 AS cbrt_27;
SELECT ||/ 8.0 AS cbrt_8;

-- Factorial (postfix !)
SELECT 5! AS factorial_5;
SELECT 0! AS factorial_0;

-- Absolute value (@)
SELECT @ -5 AS abs_neg;
SELECT @ 5 AS abs_pos;
SELECT @ 0 AS abs_zero;
SELECT @ -3.14 AS abs_float;

-- ----------------------------------------------------------------------------
-- P2: Bitwise operators (&, |, #, ~, <<, >>)
-- TODO: Verify bitwise operator support on integer types
-- ----------------------------------------------------------------------------

-- Bitwise AND
SELECT 12 & 10 AS bit_and;    -- 1100 & 1010 = 1000 = 8
SELECT 255 & 15 AS bit_and_2; -- 00001111 = 15

-- Bitwise OR
SELECT 12 | 10 AS bit_or;     -- 1100 | 1010 = 1110 = 14
SELECT 0 | 0 AS bit_or_zero;

-- Bitwise XOR (#)
SELECT 12 # 10 AS bit_xor;    -- 1100 # 1010 = 0110 = 6
SELECT 255 # 255 AS bit_xor_self; -- 0

-- Bitwise NOT (~)
SELECT ~0 AS bit_not_zero;
SELECT ~1 AS bit_not_one;

-- Left shift
SELECT 1 << 4 AS lshift;      -- 16
SELECT 3 << 2 AS lshift_2;    -- 12

-- Right shift
SELECT 16 >> 4 AS rshift;     -- 1
SELECT 12 >> 2 AS rshift_2;   -- 3

-- Combined bitwise
SELECT (1 << 8) - 1 AS byte_mask;  -- 255
SELECT (0xFF & 0xF0) >> 4 AS high_nibble;  -- 15
