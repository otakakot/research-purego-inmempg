-- =============================================================================
-- Section 12.16: Geometric Functions
-- =============================================================================
-- Note: 06_data_types.sql covers basic geometric type storage.
--       This file covers operators and functions.

-- =============================================================================
-- Pre-cleanup
-- =============================================================================

DROP TABLE IF EXISTS geom_shapes CASCADE;
DROP TABLE IF EXISTS geom_points CASCADE;

-- =============================================================================
-- Setup
-- =============================================================================

CREATE TABLE geom_points (id serial PRIMARY KEY, pt point);
INSERT INTO geom_points (pt) VALUES ('(0,0)'), ('(3,4)'), ('(1,1)'), ('(-2,5)');

CREATE TABLE geom_shapes (
    id   serial PRIMARY KEY,
    b    box,
    c    circle,
    l    lseg,
    p    path,
    pg   polygon
);
INSERT INTO geom_shapes (b, c, l, p, pg) VALUES
    ('(2,2),(0,0)', '<(1,1),3>', '[(0,0),(3,4)]', '((0,0),(1,1),(2,0))', '((0,0),(4,0),(4,3),(0,3))'),
    ('(5,5),(3,3)', '<(0,0),1>', '[(1,1),(4,5)]', '[(0,0),(2,2),(4,0)]', '((0,0),(2,0),(1,2))');

-- =============================================================================
-- TODO [P3]: Distance operator <-> (between points, etc.)
-- =============================================================================

SELECT point '(0,0)' <-> point '(3,4)' AS dist_points;
SELECT point '(1,1)' <-> lseg '[(0,0),(3,0)]' AS dist_point_lseg;
SELECT lseg '[(0,0),(1,1)]' <-> lseg '[(2,2),(3,3)]' AS dist_lsegs;

-- =============================================================================
-- TODO [P3]: Containment: @> (contains), <@ (contained by)
-- =============================================================================

SELECT box '(2,2),(0,0)' @> point '(1,1)' AS box_contains_point;
SELECT point '(1,1)' <@ box '(2,2),(0,0)' AS point_in_box;
SELECT circle '<(0,0),5>' @> point '(3,4)' AS circle_contains_point;
SELECT point '(3,4)' <@ circle '<(0,0),5>' AS point_in_circle;

-- =============================================================================
-- TODO [P3]: Intersection: ?# (intersects)
-- =============================================================================

SELECT lseg '[(0,0),(2,2)]' ?# lseg '[(0,2),(2,0)]' AS lsegs_intersect;
SELECT box '(2,2),(0,0)' ?# box '(3,3),(1,1)' AS boxes_intersect;

-- =============================================================================
-- TODO [P3]: Perpendicular/parallel: ?-| (perpendicular), ?|| (parallel)
-- =============================================================================

SELECT lseg '[(0,0),(1,0)]' ?-| lseg '[(0,0),(0,1)]' AS perpendicular;
SELECT lseg '[(0,0),(1,0)]' ?|| lseg '[(0,1),(1,1)]' AS parallel;

-- =============================================================================
-- TODO [P3]: Horizontal/vertical: ?- (horizontal), ?| (vertical)
-- =============================================================================

SELECT ?- lseg '[(0,0),(1,0)]' AS is_horizontal;
SELECT ?| lseg '[(0,0),(0,1)]' AS is_vertical;

-- =============================================================================
-- TODO [P3]: Length: @-@ (length/circumference)
-- =============================================================================

SELECT @-@ lseg '[(0,0),(3,4)]' AS lseg_length;
SELECT @-@ path '((0,0),(3,0),(3,4))' AS path_length;

-- =============================================================================
-- TODO [P3]: Center: @@ (center point)
-- =============================================================================

SELECT @@ box '(2,2),(0,0)' AS box_center;
SELECT @@ circle '<(1,2),5>' AS circle_center;

-- =============================================================================
-- TODO [P3]: Closest point: ## (closest point on second operand)
-- =============================================================================

SELECT point '(0,2)' ## lseg '[(0,0),(2,0)]' AS closest_on_lseg;
SELECT point '(3,3)' ## box '(2,2),(0,0)' AS closest_on_box;

-- =============================================================================
-- TODO [P3]: area() — area of geometric shape
-- =============================================================================

SELECT area(box '(2,2),(0,0)') AS box_area;
SELECT area(circle '<(0,0),3>') AS circle_area;
SELECT area(path '((0,0),(4,0),(4,3),(0,3))') AS closed_path_area;

-- =============================================================================
-- TODO [P3]: center() — center point of shape
-- =============================================================================

SELECT center(box '(2,2),(0,0)') AS box_ctr;
SELECT center(circle '<(1,2),5>') AS circle_ctr;

-- =============================================================================
-- TODO [P3]: diameter() / radius() — circle dimensions
-- =============================================================================

SELECT diameter(circle '<(0,0),5>') AS diam;
SELECT radius(circle '<(0,0),5>')   AS rad;

-- =============================================================================
-- TODO [P3]: height() / width() — box dimensions
-- =============================================================================

SELECT height(box '(3,5),(1,2)') AS h;
SELECT width(box '(3,5),(1,2)')  AS w;

-- =============================================================================
-- TODO [P3]: length() — length of geometric object
-- =============================================================================

SELECT length(lseg '[(0,0),(3,4)]') AS lseg_len;
SELECT length(path '((0,0),(3,0),(3,4))') AS path_len;

-- =============================================================================
-- TODO [P3]: npoints() — number of points
-- =============================================================================

SELECT npoints(path '((0,0),(1,1),(2,0),(3,1))') AS n_path;
SELECT npoints(polygon '((0,0),(1,0),(1,1),(0,1))') AS n_polygon;

-- =============================================================================
-- TODO [P3]: Geometric type conversion functions
-- =============================================================================

-- box() — convert to box
SELECT box(circle '<(0,0),1>') AS circle_to_box;
SELECT box(polygon '((0,0),(2,0),(2,2),(0,2))') AS polygon_to_box;

-- circle() — convert to circle
SELECT circle(box '(1,1),(-1,-1)') AS box_to_circle;
SELECT circle(point '(0,0)', 5.0) AS point_radius_to_circle;

-- lseg() — convert to line segment
SELECT lseg(point '(0,0)', point '(3,4)') AS points_to_lseg;
SELECT lseg(box '(2,2),(0,0)') AS box_to_lseg_diagonal;

-- path() — convert to path
SELECT path(polygon '((0,0),(1,0),(1,1),(0,1))') AS polygon_to_path;

-- point() — convert to point
SELECT point(circle '<(3,4),1>') AS circle_to_point;
SELECT point(box '(2,2),(0,0)')  AS box_to_point;

-- polygon() — convert to polygon
SELECT polygon(box '(2,2),(0,0)') AS box_to_polygon;
SELECT polygon(circle '<(0,0),1>') AS circle_to_polygon;
SELECT polygon(4, circle '<(0,0),1>') AS circle_to_polygon_4pts;
SELECT polygon(path '((0,0),(1,0),(1,1),(0,1))') AS path_to_polygon;

-- =============================================================================
-- Cleanup
-- =============================================================================

DROP TABLE geom_shapes;
DROP TABLE geom_points;
