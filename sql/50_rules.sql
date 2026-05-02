-- =============================================================================
-- Section 12.7: Rules
-- =============================================================================

-- Pre-cleanup
DROP VIEW IF EXISTS rules_orders_view CASCADE;
DROP TABLE IF EXISTS rules_orders CASCADE;
DROP TABLE IF EXISTS rules_orders_archive CASCADE;
DROP TABLE IF EXISTS rules_orders_log CASCADE;

-- Setup
CREATE TABLE rules_orders (
    id       SERIAL PRIMARY KEY,
    product  TEXT NOT NULL,
    quantity INT  NOT NULL,
    status   TEXT NOT NULL DEFAULT 'active'
);

CREATE TABLE rules_orders_archive (
    id            INT  NOT NULL,
    product       TEXT NOT NULL,
    quantity      INT  NOT NULL,
    archived_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE rules_orders_log (
    order_id   INT  NOT NULL,
    action     TEXT NOT NULL,
    logged_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE VIEW rules_orders_view AS
    SELECT id, product, quantity, status FROM rules_orders;

INSERT INTO rules_orders (product, quantity) VALUES
    ('Widget A', 10),
    ('Widget B', 20),
    ('Widget C', 5);

-- =============================================================================
-- TODO [P4]: CREATE RULE — basic ON INSERT rule with DO INSTEAD
-- =============================================================================

CREATE RULE rules_insert_redirect AS
    ON INSERT TO rules_orders_archive
    DO INSTEAD
        INSERT INTO rules_orders (product, quantity)
        VALUES (NEW.product, NEW.quantity);

-- =============================================================================
-- TODO [P4]: ON UPDATE rule — DO ALSO (additional action)
-- =============================================================================

CREATE RULE rules_update_log AS
    ON UPDATE TO rules_orders
    DO ALSO
        INSERT INTO rules_orders_log (order_id, action)
        VALUES (OLD.id, 'updated');

-- =============================================================================
-- TODO [P4]: ON DELETE rule — redirect deletes
-- =============================================================================

CREATE RULE rules_delete_archive AS
    ON DELETE TO rules_orders
    DO ALSO
        INSERT INTO rules_orders_archive (id, product, quantity)
        VALUES (OLD.id, OLD.product, OLD.quantity);

-- =============================================================================
-- TODO [P4]: Conditional rule with WHERE clause
-- =============================================================================

CREATE RULE rules_prevent_large_qty AS
    ON INSERT TO rules_orders
    WHERE (NEW.quantity > 1000)
    DO INSTEAD NOTHING;

-- =============================================================================
-- TODO [P4]: NOTHING rule — silently discard operations
-- =============================================================================

CREATE RULE rules_discard_deletes AS
    ON DELETE TO rules_orders_archive
    DO INSTEAD NOTHING;

-- =============================================================================
-- TODO [P4]: Updatable view via rules — ON INSERT/UPDATE/DELETE TO view
-- =============================================================================

CREATE RULE rules_view_insert AS
    ON INSERT TO rules_orders_view
    DO INSTEAD
        INSERT INTO rules_orders (product, quantity, status)
        VALUES (NEW.product, NEW.quantity, COALESCE(NEW.status, 'active'));

CREATE RULE rules_view_update AS
    ON UPDATE TO rules_orders_view
    DO INSTEAD
        UPDATE rules_orders
        SET product  = NEW.product,
            quantity = NEW.quantity,
            status   = NEW.status
        WHERE id = OLD.id;

CREATE RULE rules_view_delete AS
    ON DELETE TO rules_orders_view
    DO INSTEAD
        DELETE FROM rules_orders WHERE id = OLD.id;

-- =============================================================================
-- TODO [P4]: DROP RULE
-- =============================================================================

DROP RULE rules_prevent_large_qty ON rules_orders;

-- Verify remaining rules
SELECT rulename, tablename, definition
FROM pg_rules
WHERE tablename IN ('rules_orders', 'rules_orders_archive', 'rules_orders_view');

-- Cleanup
DROP RULE rules_view_delete ON rules_orders_view;
DROP RULE rules_view_update ON rules_orders_view;
DROP RULE rules_view_insert ON rules_orders_view;
DROP RULE rules_discard_deletes ON rules_orders_archive;
DROP RULE rules_delete_archive ON rules_orders;
DROP RULE rules_update_log ON rules_orders;
DROP RULE rules_insert_redirect ON rules_orders_archive;
DROP VIEW rules_orders_view;
DROP TABLE rules_orders_log;
DROP TABLE rules_orders_archive;
DROP TABLE rules_orders;
