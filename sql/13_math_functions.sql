-- =============================================================================
-- Section 4.1: Math Functions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TODO [P1] abs, ceil/ceiling, floor, round, greatest, least
-- -----------------------------------------------------------------------------

-- abs(x): absolute value
SELECT abs(-42) AS abs_neg, abs(42) AS abs_pos, abs(0) AS abs_zero;

-- ceil / ceiling: smallest integer >= x
SELECT ceil(4.2) AS ceil_pos, ceil(-4.8) AS ceil_neg;
SELECT ceiling(4.2) AS ceiling_pos, ceiling(-4.8) AS ceiling_neg;

-- floor: largest integer <= x
SELECT floor(4.8) AS floor_pos, floor(-4.2) AS floor_neg;

-- round(x): round to nearest integer
SELECT round(4.5) AS round_half, round(4.4) AS round_down, round(-4.5) AS round_neg_half;

-- round(x, s): round to s decimal places
SELECT round(3.14159, 2) AS round_2dp, round(3.14159, 4) AS round_4dp;

-- greatest / least
SELECT greatest(1, 5, 3, 9, 2) AS greatest_int;
SELECT least(1, 5, 3, 9, 2) AS least_int;
SELECT greatest('apple', 'banana', 'cherry') AS greatest_text;
SELECT least('apple', 'banana', 'cherry') AS least_text;

-- -----------------------------------------------------------------------------
-- TODO [P2] trunc, mod, power, sqrt, log, ln, exp, sign, pi, random, setseed,
--           div
-- -----------------------------------------------------------------------------

-- trunc(x): truncate toward zero
SELECT trunc(4.8) AS trunc_pos, trunc(-4.8) AS trunc_neg;

-- trunc(x, s): truncate to s decimal places
SELECT trunc(3.14159, 2) AS trunc_2dp;

-- mod(x, y): remainder
SELECT mod(10, 3) AS mod_10_3, mod(-10, 3) AS mod_neg;

-- power(a, b)
SELECT power(2, 10) AS pow_2_10, power(9, 0.5) AS pow_sqrt9;

-- sqrt(x)
SELECT sqrt(144) AS sqrt_144, sqrt(2) AS sqrt_2;

-- log(base, x) and log10
SELECT log(10, 1000) AS log10_1000;
SELECT log(2, 8) AS log2_8;

-- ln(x): natural logarithm
SELECT ln(1) AS ln_1, ln(exp(1.0)) AS ln_e;

-- exp(x)
SELECT exp(0) AS exp_0, exp(1) AS exp_1;

-- sign(x)
SELECT sign(-5) AS sign_neg, sign(0) AS sign_zero, sign(5) AS sign_pos;

-- pi()
SELECT pi() AS pi_value;

-- random(): returns value in [0, 1)
SELECT random() AS rand_val;

-- setseed(x): seed for random, x in [-1, 1]
SELECT setseed(0.42);
SELECT random() AS seeded_rand;

-- div(x, y): integer quotient (truncated toward zero)
SELECT div(10, 3) AS div_10_3, div(-10, 3) AS div_neg;

-- -----------------------------------------------------------------------------
-- TODO [P4] gcd, lcm, trigonometric functions
-- -----------------------------------------------------------------------------

-- gcd / lcm
SELECT gcd(12, 8) AS gcd_12_8, lcm(12, 8) AS lcm_12_8;

-- trigonometric functions
SELECT sin(0) AS sin_0, cos(0) AS cos_0, tan(0) AS tan_0;
SELECT asin(1) AS asin_1, acos(1) AS acos_1, atan(1) AS atan_1;
SELECT atan2(1, 1) AS atan2_1_1;
