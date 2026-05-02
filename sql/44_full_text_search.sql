-- ============================================================================
-- Section 12: Full Text Search
-- ============================================================================
-- TODO: Verify full text search support in pure-Go implementation
-- Priority levels noted per feature group

-- Setup: create documents table with tsvector column
CREATE TABLE documents (
    id    SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    body  TEXT NOT NULL,
    tsv   tsvector
);

INSERT INTO documents (title, body) VALUES
    ('PostgreSQL Full Text Search', 'PostgreSQL provides powerful full text search capabilities with tsvector and tsquery types'),
    ('Database Indexing', 'Indexes improve query performance by allowing the database engine to find rows quickly'),
    ('Search Engine Design', 'A search engine processes queries and ranks documents by relevance to the user'),
    ('Natural Language Processing', 'NLP techniques include tokenization stemming and parsing of natural language text'),
    ('Advanced Query Optimization', 'The query optimizer analyzes SQL statements and chooses the most efficient execution plan');

UPDATE documents SET tsv = to_tsvector('english', title || ' ' || body);

-- ----------------------------------------------------------------------------
-- P2: tsvector/tsquery basics - creating and matching with @@
-- TODO: Verify @@ match operator for tsvector and tsquery
-- ----------------------------------------------------------------------------

-- Literal tsvector @@ literal tsquery
SELECT 'a fat cat sat on a mat and ate a fat rat'::tsvector @@ 'cat & rat'::tsquery AS match_literal_true;
SELECT 'a fat cat sat on a mat'::tsvector @@ 'cat & dog'::tsquery AS match_literal_false;

-- Reversed argument order (tsquery @@ tsvector)
SELECT 'fat & cow'::tsquery @@ 'a fat cat sat on a mat and ate a fat rat'::tsvector AS match_reversed;

-- Text @@ tsquery (implicit to_tsvector)
SELECT 'fat cats ate fat rats' @@ to_tsquery('fat & rat') AS match_text_implicit;

-- ----------------------------------------------------------------------------
-- P2: to_tsvector() and to_tsquery() - text to tsvector/tsquery conversion
-- TODO: Verify normalization and stemming behavior
-- ----------------------------------------------------------------------------

SELECT to_tsvector('english', 'The Fat Rats') AS tsvector_english;
SELECT to_tsvector('english', 'PostgreSQL provides full text search') AS tsvector_sentence;

SELECT to_tsquery('english', 'The & Fat & Rats') AS tsquery_english;
SELECT to_tsquery('english', 'search & engine') AS tsquery_multi;

-- Match using conversion functions (stemming makes 'rats' match 'rat')
SELECT to_tsvector('fat cats ate fat rats') @@ to_tsquery('fat & rat') AS match_stemmed;
SELECT to_tsvector('english', 'PostgreSQL full text search') @@ to_tsquery('english', 'search') AS match_single;

-- ----------------------------------------------------------------------------
-- P2: plainto_tsquery(), phraseto_tsquery(), websearch_to_tsquery()
-- TODO: Verify alternative tsquery constructors
-- ----------------------------------------------------------------------------

-- plainto_tsquery: all words ANDed, punctuation ignored
SELECT plainto_tsquery('english', 'The Fat Rats') AS plain_query;
SELECT to_tsvector('english', 'fat cats and rats') @@ plainto_tsquery('english', 'fat rats') AS plain_match;

-- phraseto_tsquery: words must appear in sequence (FOLLOWED BY)
SELECT phraseto_tsquery('english', 'The Fat Rats') AS phrase_query;
SELECT phraseto_tsquery('english', 'The Cat and Rats') AS phrase_with_stopword;

-- websearch_to_tsquery: web-search-like syntax with quotes, or, dash
SELECT websearch_to_tsquery('english', '"fat rat" or cat dog') AS websearch_query;
SELECT websearch_to_tsquery('english', 'cat -dog') AS websearch_negation;

-- ----------------------------------------------------------------------------
-- P2: tsquery operators - && (AND), || (OR), !! (NOT), <-> (phrase)
-- TODO: Verify tsquery combining operators
-- ----------------------------------------------------------------------------

-- AND (&&)
SELECT 'fat | rat'::tsquery && 'cat'::tsquery AS tsquery_and;
SELECT to_tsvector('english', 'fat cat') @@ (to_tsquery('fat') && to_tsquery('cat')) AS and_match_true;
SELECT to_tsvector('english', 'fat cat') @@ (to_tsquery('fat') && to_tsquery('dog')) AS and_match_false;

-- OR (||)
SELECT 'fat | rat'::tsquery || 'cat'::tsquery AS tsquery_or;
SELECT to_tsvector('english', 'the dog barks') @@ (to_tsquery('cat') || to_tsquery('dog')) AS or_match_true;

-- NOT (!!)
SELECT !! 'cat'::tsquery AS tsquery_not;
SELECT to_tsvector('english', 'fat dog') @@ (to_tsquery('fat') && !! to_tsquery('cat')) AS not_match_true;

-- FOLLOWED BY (<->)
SELECT to_tsquery('fat') <-> to_tsquery('rat') AS tsquery_phrase;
SELECT to_tsvector('english', 'fat rat') @@ (to_tsquery('fat') <-> to_tsquery('rat')) AS phrase_match_true;
SELECT to_tsvector('english', 'rat fat') @@ (to_tsquery('fat') <-> to_tsquery('rat')) AS phrase_match_false;

-- ----------------------------------------------------------------------------
-- P2: tsvector concatenation with ||
-- TODO: Verify tsvector concatenation and position adjustment
-- ----------------------------------------------------------------------------

SELECT 'a:1 b:2'::tsvector || 'c:1 d:2 b:3'::tsvector AS tsvector_concat;
SELECT to_tsvector('english', 'fat cat') || to_tsvector('english', 'red dog') AS tsvector_concat_normalized;

-- ----------------------------------------------------------------------------
-- P2: ts_rank() and ts_rank_cd() - ranking results
-- TODO: Verify ranking functions return meaningful scores
-- ----------------------------------------------------------------------------

SELECT ts_rank(to_tsvector('raining cats and dogs'), 'cat') AS rank_basic;
SELECT ts_rank_cd(to_tsvector('raining cats and dogs'), 'cat') AS rank_cd_basic;

-- Rank documents from setup table
SELECT id, title,
       ts_rank(tsv, to_tsquery('english', 'search')) AS rank_search
FROM documents
WHERE tsv @@ to_tsquery('english', 'search')
ORDER BY rank_search DESC;

-- Rank with normalization (divide by document length)
SELECT id, title,
       ts_rank(tsv, to_tsquery('english', 'query'), 32) AS rank_normalized
FROM documents
WHERE tsv @@ to_tsquery('english', 'query')
ORDER BY rank_normalized DESC;

-- ----------------------------------------------------------------------------
-- P2: ts_headline() - highlighting matches in text
-- TODO: Verify ts_headline returns highlighted text
-- ----------------------------------------------------------------------------

SELECT ts_headline('The fat cat ate the rat.', 'cat') AS headline_default;

SELECT ts_headline('english', body, to_tsquery('english', 'search'),
                   'StartSel=<<, StopSel=>>, MaxWords=15, MinWords=5')
       AS headline_custom
FROM documents
WHERE tsv @@ to_tsquery('english', 'search');

SELECT ts_headline('english',
                   'Full text search is a powerful feature of PostgreSQL.',
                   to_tsquery('english', 'search & powerful'),
                   'HighlightAll=true') AS headline_all;

-- ----------------------------------------------------------------------------
-- P3: setweight() and strip() - weight management
-- TODO: Verify weight assignment and stripping
-- ----------------------------------------------------------------------------

SELECT setweight('fat:2,4 cat:3 rat:5B'::tsvector, 'A') AS setweight_all;
SELECT setweight('fat:2,4 cat:3 rat:5,6B'::tsvector, 'A', '{cat,rat}') AS setweight_selective;
SELECT strip('fat:2,4 cat:3 rat:5A'::tsvector) AS stripped;

-- Weighted search: title weighted higher than body
SELECT id, title,
       ts_rank(setweight(to_tsvector('english', title), 'A') ||
               setweight(to_tsvector('english', body), 'B'),
               to_tsquery('english', 'search')) AS weighted_rank
FROM documents
ORDER BY weighted_rank DESC
LIMIT 3;

-- ----------------------------------------------------------------------------
-- P3: tsvector_to_array(), array_to_tsvector(), length(tsvector)
-- TODO: Verify tsvector array conversion and length functions
-- ----------------------------------------------------------------------------

SELECT tsvector_to_array('fat:2,4 cat:3 rat:5A'::tsvector) AS tsv_to_array;
SELECT array_to_tsvector('{fat,cat,rat}'::text[]) AS array_to_tsv;
SELECT length('fat:2,4 cat:3 rat:5A'::tsvector) AS tsv_length;

SELECT length(to_tsvector('english', 'The quick brown fox jumps over the lazy dog')) AS tsv_length_sentence;

-- ----------------------------------------------------------------------------
-- P3: ts_debug(), ts_lexize() - debugging text search
-- TODO: Verify debug functions for text search configuration testing
-- ----------------------------------------------------------------------------

SELECT * FROM ts_debug('english', 'The Brightest supernovaes');

SELECT ts_lexize('english_stem', 'stars') AS lexize_stars;
SELECT ts_lexize('english_stem', 'running') AS lexize_running;
SELECT ts_lexize('english_stem', 'the') AS lexize_stopword;

-- ----------------------------------------------------------------------------
-- P2: GIN index on tsvector column
-- TODO: Verify GIN index creation and usage for text search
-- ----------------------------------------------------------------------------

CREATE INDEX idx_documents_tsv ON documents USING GIN (tsv);

-- Query using the GIN index
SELECT id, title
FROM documents
WHERE tsv @@ to_tsquery('english', 'search & text')
ORDER BY id;

-- Expression-based GIN index (without stored tsvector column)
CREATE INDEX idx_documents_body_gin ON documents USING GIN (to_tsvector('english', body));

SELECT id, title
FROM documents
WHERE to_tsvector('english', body) @@ to_tsquery('english', 'query & performance');

-- ----------------------------------------------------------------------------
-- P3: CREATE TEXT SEARCH CONFIGURATION / DICTIONARY (basic DDL)
-- TODO: Verify text search configuration DDL support
-- ----------------------------------------------------------------------------

-- Create a custom text search configuration based on english
CREATE TEXT SEARCH CONFIGURATION test_config (COPY = english);

-- Alter mapping for a token type
ALTER TEXT SEARCH CONFIGURATION test_config
    ALTER MAPPING FOR asciiword WITH english_stem;

-- Use the custom configuration
SELECT to_tsvector('test_config', 'The quick brown foxes') AS custom_config_result;

-- Cleanup custom configuration
DROP TEXT SEARCH CONFIGURATION test_config;

-- Cleanup
DROP INDEX idx_documents_body_gin;
DROP INDEX idx_documents_tsv;
DROP TABLE documents;
