-- =============================================================================
-- Section 11.4: Row Level Security (RLS)
-- =============================================================================

-- Setup
CREATE TABLE rls_documents (
    id       SERIAL PRIMARY KEY,
    owner    TEXT NOT NULL,
    title    TEXT NOT NULL,
    content  TEXT
);

INSERT INTO rls_documents (owner, title, content) VALUES
    ('alice', 'Alice Doc 1', 'Secret A1'),
    ('alice', 'Alice Doc 2', 'Secret A2'),
    ('bob',   'Bob Doc 1',   'Secret B1'),
    ('bob',   'Bob Doc 2',   'Secret B2');

-- =============================================================================
-- TODO [P3]: Enable RLS on a table
-- =============================================================================

ALTER TABLE rls_documents ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- TODO [P3]: CREATE POLICY — restrict SELECT to own rows
-- =============================================================================

CREATE POLICY doc_select_policy ON rls_documents
    FOR SELECT
    USING (owner = current_user);

-- =============================================================================
-- TODO [P3]: CREATE POLICY — restrict INSERT to own rows
-- =============================================================================

CREATE POLICY doc_insert_policy ON rls_documents
    FOR INSERT
    WITH CHECK (owner = current_user);

-- =============================================================================
-- TODO [P3]: CREATE POLICY — restrict UPDATE to own rows
-- =============================================================================

CREATE POLICY doc_update_policy ON rls_documents
    FOR UPDATE
    USING (owner = current_user)
    WITH CHECK (owner = current_user);

-- =============================================================================
-- TODO [P3]: CREATE POLICY — restrict DELETE to own rows
-- =============================================================================

CREATE POLICY doc_delete_policy ON rls_documents
    FOR DELETE
    USING (owner = current_user);

-- Verify policies exist
SELECT polname, polcmd, polroles::regrole[], polqual, polwithcheck
FROM pg_policy
WHERE polrelid = 'rls_documents'::regclass;

-- =============================================================================
-- TODO [P3]: ALTER POLICY — modify existing policy
-- =============================================================================

ALTER POLICY doc_select_policy ON rls_documents
    USING (owner = current_user OR owner = 'public_user');

-- =============================================================================
-- TODO [P3]: DROP POLICY
-- =============================================================================

DROP POLICY doc_delete_policy ON rls_documents;

-- Verify policy was dropped
SELECT polname FROM pg_policy WHERE polrelid = 'rls_documents'::regclass;

-- Disable RLS
ALTER TABLE rls_documents DISABLE ROW LEVEL SECURITY;

-- Cleanup
DROP POLICY doc_update_policy ON rls_documents;
DROP POLICY doc_insert_policy ON rls_documents;
DROP POLICY doc_select_policy ON rls_documents;
DROP TABLE rls_documents;
