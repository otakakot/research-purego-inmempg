-- =============================================================================
-- Section 12.17: XML Functions
-- =============================================================================
-- Note: 06_data_types.sql covers basic XML type storage.
--       This file covers XML functions.

-- =============================================================================
-- Setup
-- =============================================================================

CREATE TABLE xml_test (
    id    serial PRIMARY KEY,
    name  text,
    price numeric(10,2),
    qty   int
);
INSERT INTO xml_test (name, price, qty) VALUES
    ('Widget', 9.99, 100),
    ('Gadget', 24.99, 50),
    ('Doohickey', 4.50, 200);

CREATE TABLE xml_docs (
    id  serial PRIMARY KEY,
    doc xml
);
INSERT INTO xml_docs (doc) VALUES
    ('<catalog><book id="1"><title>SQL</title><author>Joe</author></book><book id="2"><title>Go</title><author>Rob</author></book></catalog>'),
    ('<inventory><item qty="10">Alpha</item><item qty="20">Beta</item></inventory>');

-- =============================================================================
-- TODO [P3]: xmlelement() — create XML element
-- =============================================================================

SELECT xmlelement(name product, 'Widget') AS simple_elem;
SELECT xmlelement(name product, xmlelement(name name, 'Widget'), xmlelement(name price, 9.99)) AS nested_elem;

-- =============================================================================
-- TODO [P3]: xmlattributes() — add attributes
-- =============================================================================

SELECT xmlelement(name product, xmlattributes(1 AS id, 'Widget' AS name), 'content') AS elem_with_attrs;

-- =============================================================================
-- TODO [P3]: xmlforest() — create XML forest from columns
-- =============================================================================

SELECT xmlforest(name, price, qty) FROM xml_test;

-- =============================================================================
-- TODO [P3]: xmlconcat() — concatenate XML values
-- =============================================================================

SELECT xmlconcat(
    xmlelement(name a, 'one'),
    xmlelement(name b, 'two'),
    xmlelement(name c, 'three')
) AS concatenated;

-- =============================================================================
-- TODO [P3]: xmlagg() — aggregate XML
-- =============================================================================

SELECT xmlelement(name products,
    xmlagg(xmlelement(name product, xmlattributes(id AS id), name))
) AS product_list
FROM xml_test;

-- =============================================================================
-- TODO [P3]: xmlparse() — parse string to XML (DOCUMENT / CONTENT)
-- =============================================================================

SELECT xmlparse(DOCUMENT '<root><child>hello</child></root>') AS parsed_doc;
SELECT xmlparse(CONTENT 'text <b>bold</b> more') AS parsed_content;

-- =============================================================================
-- TODO [P3]: xmlserialize() — XML to string
-- =============================================================================

SELECT xmlserialize(DOCUMENT xmlparse(DOCUMENT '<root/>') AS text) AS serialized_doc;
SELECT xmlserialize(CONTENT '<a>1</a><b>2</b>'::xml AS text) AS serialized_content;

-- =============================================================================
-- TODO [P3]: xpath() — evaluate XPath expression
-- =============================================================================

SELECT xpath('/catalog/book/title/text()', doc) AS titles FROM xml_docs WHERE id = 1;
SELECT xpath('/catalog/book[@id="2"]/author/text()', doc) AS author FROM xml_docs WHERE id = 1;
SELECT xpath('//item/text()', doc) AS items FROM xml_docs WHERE id = 2;

-- =============================================================================
-- TODO [P3]: xpath_exists() — check XPath existence
-- =============================================================================

SELECT xpath_exists('/catalog/book', doc) AS has_books FROM xml_docs WHERE id = 1;
SELECT xpath_exists('/catalog/movie', doc) AS has_movies FROM xml_docs WHERE id = 1;

-- =============================================================================
-- TODO [P4]: xmltable() — extract tabular data from XML
-- =============================================================================

-- SELECT * FROM XMLTABLE(
--     '/catalog/book' PASSING (SELECT doc FROM xml_docs WHERE id = 1)
--     COLUMNS
--         book_id int    PATH '@id',
--         title   text   PATH 'title',
--         author  text   PATH 'author'
-- );

-- =============================================================================
-- TODO [P4]: table_to_xml() / query_to_xml() — convert table/query to XML
-- =============================================================================

-- SELECT table_to_xml('xml_test', true, false, '') AS table_xml;
-- SELECT query_to_xml('SELECT * FROM xml_test WHERE qty > 50', true, false, '') AS query_xml;

-- =============================================================================
-- TODO [P4]: xml_is_well_formed() — validate XML
-- =============================================================================

-- SELECT xml_is_well_formed('<root><child/></root>') AS valid_xml;
-- SELECT xml_is_well_formed('<root><child></root>') AS invalid_xml;
-- SELECT xml_is_well_formed_document('<root/>') AS valid_doc;
-- SELECT xml_is_well_formed_content('text <b>bold</b>') AS valid_content;

-- =============================================================================
-- Cleanup
-- =============================================================================

DROP TABLE xml_docs;
DROP TABLE xml_test;
