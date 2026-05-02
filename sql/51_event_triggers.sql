-- =============================================================================
-- Section 12.8: Event Triggers
-- Verification tests for pure-Go in-memory PostgreSQL implementation
-- Note: Event triggers require superuser privileges to create and manage.
-- =============================================================================

-- =====================
-- Setup: Audit log table for event trigger testing
-- =====================
CREATE TABLE ddl_audit_log (
    id SERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    object_type TEXT,
    object_name TEXT,
    command_tag TEXT,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    current_user_name TEXT DEFAULT CURRENT_USER
);

-- =====================
-- [P4] Event trigger function using pg_event_trigger_ddl_commands()
-- =====================
CREATE OR REPLACE FUNCTION fn_log_ddl_commands()
RETURNS event_trigger AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT * FROM pg_event_trigger_ddl_commands()
    LOOP
        INSERT INTO ddl_audit_log (event_type, object_type, object_name, command_tag)
        VALUES ('ddl_command_end', r.object_type, r.object_identity, r.command_tag);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================
-- [P4] CREATE EVENT TRIGGER — ON ddl_command_end
-- =====================
CREATE EVENT TRIGGER trg_log_ddl_end
    ON ddl_command_end
    EXECUTE FUNCTION fn_log_ddl_commands();

-- Test: create and drop a table to verify audit logging
CREATE TABLE evt_trigger_test (id INT);
SELECT * FROM ddl_audit_log ORDER BY id;

DROP TABLE evt_trigger_test;

-- =====================
-- [P4] Event trigger ON sql_drop with pg_event_trigger_dropped_objects()
-- =====================
CREATE OR REPLACE FUNCTION fn_log_dropped_objects()
RETURNS event_trigger AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        INSERT INTO ddl_audit_log (event_type, object_type, object_name, command_tag)
        VALUES ('sql_drop', r.object_type, r.object_identity, tg_tag);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER trg_log_sql_drop
    ON sql_drop
    EXECUTE FUNCTION fn_log_dropped_objects();

-- Test: drop triggers the sql_drop event trigger
CREATE TABLE evt_drop_test (id INT);
DROP TABLE evt_drop_test;
SELECT * FROM ddl_audit_log WHERE event_type = 'sql_drop' ORDER BY id;

-- =====================
-- [P4] Filtering with WHEN (TAG IN (...))
-- =====================
CREATE EVENT TRIGGER trg_log_create_table_only
    ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE')
    EXECUTE FUNCTION fn_log_ddl_commands();

-- =====================
-- [P4] ALTER EVENT TRIGGER — ENABLE/DISABLE
-- =====================
ALTER EVENT TRIGGER trg_log_ddl_end DISABLE;
ALTER EVENT TRIGGER trg_log_ddl_end ENABLE;
ALTER EVENT TRIGGER trg_log_ddl_end ENABLE REPLICA;
ALTER EVENT TRIGGER trg_log_ddl_end ENABLE ALWAYS;

-- =====================
-- [P4] DROP EVENT TRIGGER
-- =====================
DROP EVENT TRIGGER trg_log_create_table_only;
DROP EVENT TRIGGER trg_log_sql_drop;
DROP EVENT TRIGGER trg_log_ddl_end;

-- =====================
-- Cleanup
-- =====================
DROP FUNCTION fn_log_ddl_commands();
DROP FUNCTION fn_log_dropped_objects();
DROP TABLE ddl_audit_log;
