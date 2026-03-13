-- =============================================================================
-- Section 4.3: Date/Time Functions
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TODO [P1] now, current_timestamp, current_date, extract, date_part,
--           date_trunc
-- -----------------------------------------------------------------------------

-- now() / current_timestamp
SELECT now() AS now_val;
SELECT current_timestamp AS current_ts;

-- current_date
SELECT current_date AS today;

-- extract(field FROM source)
SELECT extract(YEAR FROM TIMESTAMP '2024-06-15 10:30:45') AS yr;
SELECT extract(MONTH FROM TIMESTAMP '2024-06-15 10:30:45') AS mo;
SELECT extract(DAY FROM TIMESTAMP '2024-06-15 10:30:45') AS dy;
SELECT extract(HOUR FROM TIMESTAMP '2024-06-15 10:30:45') AS hr;
SELECT extract(MINUTE FROM TIMESTAMP '2024-06-15 10:30:45') AS mi;
SELECT extract(SECOND FROM TIMESTAMP '2024-06-15 10:30:45') AS sec;
SELECT extract(DOW FROM TIMESTAMP '2024-06-15 10:30:45') AS dow;
SELECT extract(DOY FROM TIMESTAMP '2024-06-15 10:30:45') AS doy;
SELECT extract(EPOCH FROM TIMESTAMP '2024-06-15 10:30:45') AS epoch;

-- date_part(text, source)
SELECT date_part('year', TIMESTAMP '2024-06-15 10:30:45') AS yr;
SELECT date_part('month', TIMESTAMP '2024-06-15 10:30:45') AS mo;

-- date_trunc(field, source)
SELECT date_trunc('year', TIMESTAMP '2024-06-15 10:30:45') AS trunc_yr;
SELECT date_trunc('month', TIMESTAMP '2024-06-15 10:30:45') AS trunc_mo;
SELECT date_trunc('day', TIMESTAMP '2024-06-15 10:30:45') AS trunc_dy;
SELECT date_trunc('hour', TIMESTAMP '2024-06-15 10:30:45') AS trunc_hr;

-- -----------------------------------------------------------------------------
-- TODO [P2] current_time, age, make_date, make_timestamp, make_timestamptz,
--           make_interval, to_timestamp(epoch), to_char, to_date,
--           to_timestamp(s,fmt), clock_timestamp, statement_timestamp,
--           transaction_timestamp
-- -----------------------------------------------------------------------------

-- current_time
SELECT current_time AS cur_time;

-- age(timestamp, timestamp) / age(timestamp)
SELECT age(TIMESTAMP '2024-06-15', TIMESTAMP '2000-01-01') AS age_diff;
SELECT age(TIMESTAMP '2020-01-01') AS age_from_now;

-- make_date / make_timestamp / make_timestamptz
SELECT make_date(2024, 6, 15) AS mk_date;
SELECT make_timestamp(2024, 6, 15, 10, 30, 45) AS mk_ts;
SELECT make_timestamptz(2024, 6, 15, 10, 30, 45, 'UTC') AS mk_tstz;

-- make_interval
SELECT make_interval(years := 1, months := 2, days := 3) AS mk_interval;

-- to_timestamp(epoch double precision)
SELECT to_timestamp(0) AS epoch_zero;
SELECT to_timestamp(1718448645) AS epoch_val;

-- to_char(timestamp, format)
SELECT to_char(TIMESTAMP '2024-06-15 10:30:45', 'YYYY-MM-DD HH24:MI:SS') AS formatted_ts;
SELECT to_char(TIMESTAMP '2024-06-15', 'Day, DD Mon YYYY') AS formatted_date;

-- to_date(text, format)
SELECT to_date('2024-06-15', 'YYYY-MM-DD') AS parsed_date;
SELECT to_date('15/06/2024', 'DD/MM/YYYY') AS parsed_date_eu;

-- to_timestamp(text, format)
SELECT to_timestamp('2024-06-15 10:30:45', 'YYYY-MM-DD HH24:MI:SS') AS parsed_ts;

-- clock_timestamp / statement_timestamp / transaction_timestamp
SELECT clock_timestamp() AS clock_ts;
SELECT statement_timestamp() AS stmt_ts;
SELECT transaction_timestamp() AS txn_ts;

-- -----------------------------------------------------------------------------
-- TODO [P3] date_bin, isfinite, OVERLAPS
-- -----------------------------------------------------------------------------

-- date_bin(stride, source, origin)
SELECT date_bin(
    '15 minutes'::interval,
    TIMESTAMP '2024-06-15 10:37:00',
    TIMESTAMP '2024-06-15 00:00:00'
) AS binned_ts;

-- isfinite
SELECT isfinite(TIMESTAMP '2024-06-15') AS finite_ts;
SELECT isfinite('infinity'::timestamp) AS infinite_ts;
SELECT isfinite(INTERVAL '1 day') AS finite_interval;

-- OVERLAPS
SELECT (DATE '2024-01-01', DATE '2024-06-30')
    OVERLAPS
    (DATE '2024-03-01', DATE '2024-12-31') AS overlaps_true;

SELECT (DATE '2024-01-01', DATE '2024-02-28')
    OVERLAPS
    (DATE '2024-03-01', DATE '2024-12-31') AS overlaps_false;

-- -----------------------------------------------------------------------------
-- TODO [P4] justify_days, justify_hours, justify_interval
-- -----------------------------------------------------------------------------

SELECT justify_days(INTERVAL '35 days') AS just_days;
SELECT justify_hours(INTERVAL '50 hours') AS just_hours;
SELECT justify_interval(INTERVAL '1 month -1 hour') AS just_interval;
