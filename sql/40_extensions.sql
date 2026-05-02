-- =============================================================================
-- Section 11.2: Extensions
-- =============================================================================

-- =============================================================================
-- TODO [P2]: uuid-ossp — UUID generation
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

SELECT uuid_generate_v4() AS random_uuid;
SELECT uuid_generate_v1() AS time_uuid;

CREATE TABLE ext_uuid_test (
    id   UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT
);
INSERT INTO ext_uuid_test (name) VALUES ('test');
SELECT * FROM ext_uuid_test;

DROP TABLE ext_uuid_test;
DROP EXTENSION IF EXISTS "uuid-ossp";

-- =============================================================================
-- TODO [P3]: pgcrypto — cryptographic functions
-- =============================================================================

-- CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- SELECT digest('hello', 'sha256') AS sha256_hash;
-- SELECT gen_random_bytes(16) AS random_bytes;
-- SELECT crypt('mypassword', gen_salt('bf')) AS bcrypt_hash;
-- DROP EXTENSION IF EXISTS pgcrypto;

-- =============================================================================
-- TODO [P3]: hstore — key-value store type
-- =============================================================================

-- CREATE EXTENSION IF NOT EXISTS hstore;
-- SELECT 'key1=>val1, key2=>val2'::hstore AS kv;
-- SELECT 'key1=>val1, key2=>val2'::hstore -> 'key1' AS val;
-- DROP EXTENSION IF EXISTS hstore;

-- =============================================================================
-- TODO [P3]: pg_trgm — trigram text similarity
-- =============================================================================

-- CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- SELECT similarity('hello', 'helo') AS sim;
-- SELECT show_trgm('hello') AS trigrams;
-- DROP EXTENSION IF EXISTS pg_trgm;

-- =============================================================================
-- TODO [P3]: btree_gist / btree_gin — B-tree operator classes for GiST/GIN
-- =============================================================================

-- CREATE EXTENSION IF NOT EXISTS btree_gist;
-- CREATE EXTENSION IF NOT EXISTS btree_gin;
-- DROP EXTENSION IF EXISTS btree_gin;
-- DROP EXTENSION IF EXISTS btree_gist;

-- =============================================================================
-- TODO [P3]: citext — case-insensitive text type
-- =============================================================================

-- CREATE EXTENSION IF NOT EXISTS citext;
-- CREATE TABLE ext_citext_test (name CITEXT);
-- INSERT INTO ext_citext_test VALUES ('Hello'), ('HELLO'), ('hello');
-- SELECT DISTINCT name FROM ext_citext_test;  -- should return 1 row
-- DROP TABLE ext_citext_test;
-- DROP EXTENSION IF EXISTS citext;

-- =============================================================================
-- TODO [P3]: pgvector — vector similarity search
-- =============================================================================

-- CREATE EXTENSION IF NOT EXISTS vector;
-- CREATE TABLE ext_vector_test (
--     id    SERIAL PRIMARY KEY,
--     embedding VECTOR(3)
-- );
-- INSERT INTO ext_vector_test (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
-- SELECT * FROM ext_vector_test ORDER BY embedding <-> '[1,2,3]' LIMIT 1;
-- DROP TABLE ext_vector_test;
-- DROP EXTENSION IF EXISTS vector;

-- =============================================================================
-- TODO [P4]: tablefunc — crosstab / pivot queries
-- =============================================================================

-- CREATE EXTENSION IF NOT EXISTS tablefunc;
-- DROP EXTENSION IF EXISTS tablefunc;

-- =============================================================================
-- TODO [P4]: unaccent — text search dictionary removing accents
-- =============================================================================

-- CREATE EXTENSION IF NOT EXISTS unaccent;
-- SELECT unaccent('Hëllo Wörld') AS result;
-- DROP EXTENSION IF EXISTS unaccent;

-- List installed extensions
SELECT extname, extversion FROM pg_extension ORDER BY extname;
