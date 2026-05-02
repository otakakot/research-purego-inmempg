-- =============================================================================
-- Section 12.12: Two-Phase Commit
-- =============================================================================
-- Note: Requires max_prepared_transactions > 0 in postgresql.conf

-- =============================================================================
-- TODO [P4]: PREPARE TRANSACTION — prepare a transaction for two-phase commit
-- =============================================================================

-- BEGIN;
-- CREATE TABLE tpc_test (id serial PRIMARY KEY, val text);
-- INSERT INTO tpc_test (val) VALUES ('prepared');
-- PREPARE TRANSACTION 'test_txid_001';

-- =============================================================================
-- TODO [P4]: COMMIT PREPARED — commit a previously prepared transaction
-- =============================================================================

-- COMMIT PREPARED 'test_txid_001';
-- SELECT * FROM tpc_test;

-- =============================================================================
-- TODO [P4]: ROLLBACK PREPARED — rollback a previously prepared transaction
-- =============================================================================

-- BEGIN;
-- INSERT INTO tpc_test (val) VALUES ('will_be_rolled_back');
-- PREPARE TRANSACTION 'test_txid_002';
-- ROLLBACK PREPARED 'test_txid_002';
-- SELECT * FROM tpc_test;  -- should not contain 'will_be_rolled_back'

-- =============================================================================
-- TODO [P4]: pg_prepared_xacts — system view for prepared transactions
-- =============================================================================

-- SELECT * FROM pg_prepared_xacts;

-- =============================================================================
-- Cleanup
-- =============================================================================

-- DROP TABLE IF EXISTS tpc_test;
