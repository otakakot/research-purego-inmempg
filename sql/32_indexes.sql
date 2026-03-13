-- =============================================================================
-- Section 6: Indexes
-- =============================================================================

-- Setup
CREATE TABLE idx_test (
    id      SERIAL PRIMARY KEY,
    name    TEXT,
    email   TEXT,
    score   INT,
    tags    TEXT[],
    data    JSONB,
    geo     POINT,
    created DATE DEFAULT CURRENT_DATE
);

INSERT INTO idx_test (name, email, score, tags, data, geo) VALUES
    ('Alice', 'alice@example.com', 90, '{sql,go}',    '{"level":1}', '(1,2)'),
    ('Bob',   'bob@example.com',   80, '{go,rust}',   '{"level":2}', '(3,4)'),
    ('Carol', 'carol@example.com', 85, '{sql,python}','{"level":1}', '(5,6)');

-- TODO [P1]: B-tree index (default) — created automatically for PRIMARY KEY
-- Verify with a simple query that uses the PK
SELECT * FROM idx_test WHERE id = 1;

-- TODO [P2]: CREATE INDEX — explicit B-tree
CREATE INDEX idx_test_name ON idx_test (name);

-- TODO [P2]: CREATE UNIQUE INDEX
CREATE UNIQUE INDEX idx_test_email ON idx_test (email);

-- TODO [P2]: Composite index — multiple columns
CREATE INDEX idx_test_name_score ON idx_test (name, score);

-- TODO [P2]: Hash index
CREATE INDEX idx_test_name_hash ON idx_test USING hash (name);

-- TODO [P2]: GIN index — for array / JSONB containment
CREATE INDEX idx_test_tags_gin ON idx_test USING gin (tags);
CREATE INDEX idx_test_data_gin ON idx_test USING gin (data);

-- TODO [P3]: GiST index — for geometric / range types
CREATE INDEX idx_test_geo_gist ON idx_test USING gist (geo);

-- TODO [P3]: BRIN index — block range index for large ordered data
CREATE INDEX idx_test_created_brin ON idx_test USING brin (created);

-- TODO [P3]: Expression index — index on an expression
CREATE INDEX idx_test_lower_name ON idx_test (LOWER(name));

-- TODO [P3]: Partial index — index with a WHERE clause
CREATE INDEX idx_test_high_score ON idx_test (score) WHERE score > 85;

-- TODO [P3]: Covering index (INCLUDE) — include non-key columns
CREATE INDEX idx_test_name_incl ON idx_test (name) INCLUDE (email);

-- TODO [P4]: SP-GiST index
-- SP-GiST supports partitioned search trees (quad-trees, radix trees)
CREATE INDEX idx_test_geo_spgist ON idx_test USING spgist (geo);

-- TODO [P4]: Bloom index — requires bloom extension
-- CREATE EXTENSION IF NOT EXISTS bloom;
-- CREATE INDEX idx_test_bloom ON idx_test USING bloom (name, score);

-- TODO [P4]: CREATE INDEX CONCURRENTLY — non-blocking index creation
CREATE INDEX CONCURRENTLY idx_test_score_conc ON idx_test (score);

-- Verify indexes exist
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'idx_test' ORDER BY indexname;

-- Cleanup
DROP TABLE idx_test;
