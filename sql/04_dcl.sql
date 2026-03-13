-- =============================================================================
-- Section 1.4: Data Control Language (DCL)
-- Verification tests for pure-Go in-memory PostgreSQL implementation
-- =============================================================================

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_dcl CASCADE;
REASSIGN OWNED BY test_role_user TO CURRENT_USER;
DROP OWNED BY test_role_user;
DROP ROLE IF EXISTS test_role_user;
DROP ROLE IF EXISTS test_role_admin;
DROP ROLE IF EXISTS test_role_readonly;
DROP ROLE IF EXISTS test_role_group;

-- =====================
-- Setup
-- =====================
CREATE TABLE test_dcl (
    id    SERIAL PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT INTO test_dcl (value) VALUES ('row1'), ('row2'), ('row3');

-- =====================
-- [P3] CREATE ROLE / CREATE USER
-- =====================
CREATE ROLE test_role_readonly;

CREATE ROLE test_role_admin WITH LOGIN PASSWORD 'admin_pass';

CREATE USER test_role_user WITH PASSWORD 'user_pass';

CREATE ROLE test_role_group WITH NOLOGIN;

-- =====================
-- [P3] ALTER ROLE — modify role attributes
-- =====================
ALTER ROLE test_role_readonly WITH LOGIN;

ALTER ROLE test_role_user WITH CREATEDB;

ALTER ROLE test_role_admin WITH SUPERUSER;

ALTER ROLE test_role_admin WITH NOSUPERUSER;

ALTER ROLE test_role_user SET search_path TO public;

-- =====================
-- [P3] GRANT — table-level privileges
-- =====================
GRANT SELECT ON test_dcl TO test_role_readonly;

GRANT SELECT, INSERT, UPDATE, DELETE ON test_dcl TO test_role_user;

GRANT ALL PRIVILEGES ON test_dcl TO test_role_admin;

-- =====================
-- [P3] GRANT — schema-level privileges
-- =====================
GRANT USAGE ON SCHEMA public TO test_role_readonly;

GRANT CREATE ON SCHEMA public TO test_role_user;

-- =====================
-- [P3] GRANT — sequence privileges
-- =====================
GRANT USAGE, SELECT ON SEQUENCE test_dcl_id_seq TO test_role_user;

-- =====================
-- [P3] GRANT — role membership (role to role)
-- =====================
GRANT test_role_group TO test_role_user;

-- =====================
-- [P3] REVOKE — table-level privileges
-- =====================
REVOKE INSERT, UPDATE, DELETE ON test_dcl FROM test_role_user;

-- Verify: test_role_user should now only have SELECT (via remaining grants)

-- =====================
-- [P3] REVOKE — role membership
-- =====================
REVOKE test_role_group FROM test_role_user;

-- =====================
-- [P3] REVOKE — all privileges
-- =====================
REVOKE ALL PRIVILEGES ON test_dcl FROM test_role_admin;

-- =====================
-- [P3] GRANT with GRANT OPTION
-- =====================
GRANT SELECT ON test_dcl TO test_role_admin WITH GRANT OPTION;

-- =====================
-- [P3] REVOKE with CASCADE
-- =====================
REVOKE SELECT ON test_dcl FROM test_role_admin CASCADE;

-- =====================
-- [P3] SET ROLE
-- =====================
-- SET ROLE changes the current role for privilege checks within the session
SET ROLE test_role_readonly;

-- Verify current role
SELECT current_user, session_user;

-- Reset back to original role
RESET ROLE;

SELECT current_user, session_user;

-- =====================
-- [P3] Default privileges
-- =====================
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO test_role_readonly;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE SELECT ON TABLES FROM test_role_readonly;

-- =====================
-- [P3] Verify privilege catalog
-- =====================
SELECT grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'test_dcl'
ORDER BY grantee, privilege_type;

-- =====================
-- [P3] DROP ROLE
-- =====================
REVOKE ALL ON test_dcl FROM test_role_readonly;
REVOKE ALL ON test_dcl FROM test_role_user;
REVOKE ALL ON SCHEMA public FROM test_role_readonly;
REVOKE ALL ON SCHEMA public FROM test_role_user;
REVOKE USAGE, SELECT ON SEQUENCE test_dcl_id_seq FROM test_role_user;

DROP ROLE test_role_readonly;
DROP ROLE test_role_admin;
DROP ROLE test_role_user;
DROP ROLE test_role_group;

-- =====================
-- Cleanup
-- =====================
DROP TABLE IF EXISTS test_dcl CASCADE;
