-- =============================================================================
-- Section 9.2: Information Schema
-- =============================================================================

-- Setup
CREATE TABLE info_parent (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE info_child (
    id        SERIAL PRIMARY KEY,
    parent_id INT NOT NULL REFERENCES info_parent(id),
    value     INT CHECK (value > 0),
    CONSTRAINT fk_parent FOREIGN KEY (parent_id) REFERENCES info_parent(id)
        ON DELETE CASCADE
);

CREATE VIEW info_view AS SELECT id, name FROM info_parent;

CREATE SEQUENCE info_seq START 1;

-- =============================================================================
-- TODO [P1]: information_schema.tables — list tables
-- =============================================================================
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- =============================================================================
-- TODO [P1]: information_schema.columns — column details
-- =============================================================================
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'info_parent'
ORDER BY ordinal_position;

-- =============================================================================
-- TODO [P2]: information_schema.table_constraints
-- =============================================================================
SELECT constraint_name, constraint_type, table_name
FROM information_schema.table_constraints
WHERE table_schema = 'public'
ORDER BY table_name, constraint_type;

-- =============================================================================
-- TODO [P2]: information_schema.key_column_usage
-- =============================================================================
SELECT constraint_name, table_name, column_name, ordinal_position
FROM information_schema.key_column_usage
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

-- =============================================================================
-- TODO [P2]: information_schema.referential_constraints
-- =============================================================================
SELECT constraint_name, unique_constraint_name, delete_rule, update_rule
FROM information_schema.referential_constraints
WHERE constraint_schema = 'public';

-- =============================================================================
-- TODO [P2]: information_schema.constraint_column_usage
-- =============================================================================
SELECT constraint_name, table_name, column_name
FROM information_schema.constraint_column_usage
WHERE table_schema = 'public'
ORDER BY constraint_name;

-- =============================================================================
-- TODO [P2]: information_schema.schemata
-- =============================================================================
SELECT schema_name
FROM information_schema.schemata
ORDER BY schema_name;

-- =============================================================================
-- TODO [P2]: information_schema.views
-- =============================================================================
SELECT table_name, view_definition
FROM information_schema.views
WHERE table_schema = 'public';

-- =============================================================================
-- TODO [P2]: information_schema.sequences
-- =============================================================================
SELECT sequence_name, data_type, start_value, increment
FROM information_schema.sequences
WHERE sequence_schema = 'public';

-- =============================================================================
-- TODO [P3]: information_schema.routines — functions/procedures
-- =============================================================================
SELECT routine_name, routine_type, data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
LIMIT 10;

-- =============================================================================
-- TODO [P3]: information_schema.parameters — routine parameters
-- =============================================================================
SELECT specific_name, parameter_name, data_type, ordinal_position
FROM information_schema.parameters
WHERE specific_schema = 'public'
LIMIT 10;

-- =============================================================================
-- TODO [P3]: information_schema.check_constraints
-- =============================================================================
SELECT constraint_name, check_clause
FROM information_schema.check_constraints
WHERE constraint_schema = 'public';

-- =============================================================================
-- TODO [P3]: information_schema.domains
-- =============================================================================
CREATE DOMAIN positive_int AS INT CHECK (VALUE > 0);
SELECT domain_name, data_type
FROM information_schema.domains
WHERE domain_schema = 'public';
DROP DOMAIN positive_int;

-- =============================================================================
-- TODO [P3]: information_schema.triggers
-- =============================================================================
SELECT trigger_name, event_manipulation, event_object_table, action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public';

-- Cleanup
DROP VIEW info_view;
DROP SEQUENCE info_seq;
DROP TABLE info_child;
DROP TABLE info_parent;
