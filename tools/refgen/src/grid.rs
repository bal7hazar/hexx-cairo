//! `grid`: `GridEdge` (`src/hex/grid/edge.rs`) and `GridVertex` (`src/hex/grid/vertex.rs`),
//! with `Hex::all_edges` and `Hex::all_vertices`. For `origins` seeded origins of
//! `[domain_min, domain_max]²` and each of the six directions: every item (`destination`,
//! `vertices`, `flipped`, `const_neg` and `Neg`, `clockwise`, `counter_clockwise`; `coordinates`,
//! `destinations`, `side_edges`), the rotations at the offsets `0..=12` and 255, `all_edges` and
//! `all_vertices`, `Into` from a direction; then `equivalent` on every ordered pair of the 6 × 7
//! edges (and vertices) that a hex and its six neighbours carry, around `pair_origins` of the
//! origins, one test per origin.

use std::path::{Path, PathBuf};

use hexx::{EdgeDirection, GridEdge, GridVertex, Hex, VertexDirection};

use crate::cairo::{cases_array, seeded_points, Emitter};
use crate::spec::Spec;

/// The rotation offsets of the vectors: `0..=12` (two turns and a bit) and the largest `u8`.
const OFFSETS: [u8; 14] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 255];

fn origin(p: (i32, i32)) -> Hex {
    Hex::new(p.0, p.1)
}

fn hex_pair(h: Hex) -> String {
    format!("{}, {}", h.x, h.y)
}

/// `x, y, direction` of an edge, as the Cairo table holds it.
fn edge_row(e: GridEdge) -> String {
    format!("{}, {}, {}", e.origin.x, e.origin.y, e.direction.index())
}

fn vertex_row(v: GridVertex) -> String {
    format!("{}, {}, {}", v.origin.x, v.origin.y, v.direction.index())
}

/// A hex and its six neighbours, the hex first.
fn neighbourhood(h: Hex) -> Vec<Hex> {
    let mut v = vec![h];
    v.extend(h.all_neighbors());
    v
}

fn edge_table(origins: &[(i32, i32)]) -> Vec<String> {
    let mut rows = Vec::new();
    for &p in origins {
        for e in origin(p).all_edges() {
            let [a, b] = e.vertices();
            let f = e.flipped();
            rows.push(format!(
                "{}, {}, {}, {}, {}, {}, {}, {}",
                edge_row(e),
                hex_pair(e.destination()),
                a.direction.index(),
                b.direction.index(),
                edge_row(f),
                (-e).direction.index(),
                e.clockwise().direction.index(),
                e.counter_clockwise().direction.index(),
            ));
        }
    }
    rows
}

fn vertex_table(origins: &[(i32, i32)]) -> Vec<String> {
    let mut rows = Vec::new();
    for &p in origins {
        for v in origin(p).all_vertices() {
            let [_, c1, c2] = v.coordinates();
            let [d1, d2] = v.destinations();
            assert_eq!([c1, c2], [d1, d2]);
            let [s1, s2] = v.side_edges();
            rows.push(format!(
                "{}, {}, {}, {}, {}, {}, {}, {}",
                vertex_row(v),
                hex_pair(c1),
                hex_pair(c2),
                s1.direction.index(),
                s2.direction.index(),
                (-v).direction.index(),
                v.clockwise().direction.index(),
                v.counter_clockwise().direction.index(),
            ));
        }
    }
    rows
}

fn edge_rotations(p: (i32, i32)) -> Vec<String> {
    let mut rows = Vec::new();
    for e in origin(p).all_edges() {
        for offset in OFFSETS {
            rows.push(format!(
                "{}, {offset}, {}, {}",
                edge_row(e),
                e.rotate_cw(offset).direction.index(),
                e.rotate_ccw(offset).direction.index()
            ));
        }
    }
    rows
}

fn vertex_rotations(p: (i32, i32)) -> Vec<String> {
    let mut rows = Vec::new();
    for v in origin(p).all_vertices() {
        for offset in OFFSETS {
            rows.push(format!(
                "{}, {offset}, {}, {}",
                vertex_row(v),
                v.rotate_cw(offset).direction.index(),
                v.rotate_ccw(offset).direction.index()
            ));
        }
    }
    rows
}

fn edge_pairs(h: Hex) -> Vec<String> {
    let edges: Vec<GridEdge> = neighbourhood(h).into_iter().flat_map(Hex::all_edges).collect();
    let mut rows = Vec::new();
    for a in &edges {
        for b in &edges {
            rows.push(format!("{}, {}, {}", edge_row(*a), edge_row(*b), a.equivalent(b)));
        }
    }
    rows
}

fn vertex_pairs(h: Hex) -> Vec<String> {
    let vertices: Vec<GridVertex> =
        neighbourhood(h).into_iter().flat_map(Hex::all_vertices).collect();
    let mut rows = Vec::new();
    for a in &vertices {
        for b in &vertices {
            rows.push(format!("{}, {}, {}", vertex_row(*a), vertex_row(*b), a.equivalent(b)));
        }
    }
    rows
}

/// The Cairo body that reads `cases` and runs `loop_body` on each row, with the direction tables
/// `dirs` bound beforehand (`setup`).
fn body(cases: String, setup: &str, row: &str, loop_body: &str) -> String {
    format!(
        "{cases}{setup}    let mut i = 0;\n    while i < cases.len() {{\n        let {row} = *cases.at(i);\n{loop_body}        i += 1;\n    }}\n"
    )
}

const EDGE_SETUP: &str =
    "    let dirs = EdgeDirectionTrait::ALL_DIRECTIONS;\n    let dirs = dirs.span();\n";
const VERTEX_SETUP: &str =
    "    let dirs = VertexDirectionTrait::ALL_DIRECTIONS;\n    let dirs = dirs.span();\n";

pub fn emit(spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    let origins = seeded_points(
        &spec.text("seed")?,
        spec.int("origins")? as usize,
        spec.int("domain_min")? as i32,
        spec.int("domain_max")? as i32,
    );
    let pair_origins = spec.int("pair_origins")? as usize;
    let mut e = Emitter::new(
        spec,
        "`GridEdge` (src/hex/grid/edge.rs: `equivalent` :23, `destination` :31,\n// `vertices` :38, `flipped` :55, `const_neg` :65, `clockwise` :75, `counter_clockwise` :85,\n// `rotate_cw` :95, `rotate_ccw` :104, `Hex::all_edges` :116, `Neg` :124, `From<EdgeDirection>`\n// :133) and `GridVertex` (src/hex/grid/vertex.rs: `equivalent` :24, `coordinates` :44,\n// `destinations` :54, `side_edges` :65, `const_neg` :81, `clockwise` :91, `counter_clockwise` :101,\n// `rotate_cw` :111, `rotate_ccw` :120, `Hex::all_vertices` :132, `Neg` :140,\n// `From<VertexDirection>` :149)",
        "use hexx::direction::edge_direction::EdgeDirectionTrait;\nuse hexx::direction::vertex_direction::VertexDirectionTrait;\nuse hexx::hex::HexTrait;\nuse hexx::hex::grid::edge::{GridEdge, GridEdgeNeg, GridEdgeTrait, HexEdgesTrait};\nuse hexx::hex::grid::vertex::{GridVertex, GridVertexNeg, GridVertexTrait, HexVerticesTrait};\n",
    );

    // ---- GridEdge
    let cases = cases_array(
        "i32, i32, u8, i32, i32, u8, u8, i32, i32, u8, u8, u8, u8",
        &edge_table(&origins),
    );
    let loop_body = "        let e = GridEdge { origin: HexTrait::new(ox, oy), direction: *dirs.at(d.into()) };
        assert(e.destination() == HexTrait::new(dx, dy), 'destination');
        let [a, b] = e.vertices();
        assert(a.origin == e.origin && a.direction.index() == vccw, 'vertices ccw');
        assert(b.origin == e.origin && b.direction.index() == vcw, 'vertices cw');
        let flipped = e.flipped();
        assert(flipped.origin == HexTrait::new(fx, fy), 'flipped origin');
        assert(flipped.direction.index() == fd, 'flipped direction');
        let n = e.const_neg();
        assert(n.origin == e.origin && n.direction.index() == neg, 'const_neg');
        assert(-e == n, 'neg');
        let c = e.clockwise();
        assert(c.origin == e.origin && c.direction.index() == cw, 'clockwise');
        let c = e.counter_clockwise();
        assert(c.origin == e.origin && c.direction.index() == ccw, 'counter_clockwise');
";
    e.test(
        "golden_grid_edge_table",
        false,
        &body(
            cases,
            EDGE_SETUP,
            "(ox, oy, d, dx, dy, vccw, vcw, fx, fy, fd, neg, cw, ccw)",
            loop_body,
        ),
    )?;

    for (k, &p) in origins.iter().enumerate() {
        let cases = cases_array("i32, i32, u8, u8, u8, u8", &edge_rotations(p));
        let loop_body = "        let e = GridEdge { origin: HexTrait::new(ox, oy), direction: *dirs.at(d.into()) };
        let r = e.rotate_cw(offset);
        assert(r.origin == e.origin && r.direction.index() == cw, 'rotate_cw');
        let r = e.rotate_ccw(offset);
        assert(r.origin == e.origin && r.direction.index() == ccw, 'rotate_ccw');
";
        e.test(
            &format!("golden_grid_edge_rotations_{k}"),
            false,
            &body(cases, EDGE_SETUP, "(ox, oy, d, offset, cw, ccw)", loop_body),
        )?;
    }

    // `all_edges` and `Into<EdgeDirection, GridEdge>`
    let rows: Vec<String> = origins
        .iter()
        .map(|&p| {
            let idx: Vec<String> =
                origin(p).all_edges().iter().map(|e| e.direction.index().to_string()).collect();
            format!("{}, {}", hex_pair(origin(p)), idx.join(", "))
        })
        .collect();
    let cases = cases_array("i32, i32, u8, u8, u8, u8, u8, u8", &rows);
    let loop_body = "        let h = HexTrait::new(x, y);
        let edges = h.all_edges().span();
        let expected = array![i0, i1, i2, i3, i4, i5].span();
        let mut k = 0;
        while k < 6 {
            let e = *edges.at(k);
            assert(e.origin == h && e.direction.index() == *expected.at(k), 'all_edges');
            k += 1;
        }
";
    e.test(
        "golden_grid_edge_all_edges",
        false,
        &body(cases, "", "(x, y, i0, i1, i2, i3, i4, i5)", loop_body),
    )?;
    let rows: Vec<String> = EdgeDirection::ALL_DIRECTIONS
        .iter()
        .map(|&d| {
            let g = GridEdge::from(d);
            format!("{}, {}", edge_row(g), d.index())
        })
        .collect();
    let cases = cases_array("i32, i32, u8, u8", &rows);
    let loop_body = "        let g: GridEdge = (*dirs.at(source.into())).into();
        assert(g.origin == HexTrait::new(ox, oy) && g.direction.index() == d, 'into');
";
    e.test(
        "golden_grid_edge_from_direction",
        false,
        &body(cases, EDGE_SETUP, "(ox, oy, d, source)", loop_body),
    )?;

    // ---- GridVertex
    let cases = cases_array(
        "i32, i32, u8, i32, i32, i32, i32, u8, u8, u8, u8, u8",
        &vertex_table(&origins),
    );
    let loop_body = "        let v = GridVertex { origin: HexTrait::new(ox, oy), direction: *dirs.at(d.into()) };
        let [c0, c1, c2] = v.coordinates();
        assert(c0 == v.origin, 'coordinates origin');
        assert(c1 == HexTrait::new(x1, y1) && c2 == HexTrait::new(x2, y2), 'coordinates');
        let [d1, d2] = v.destinations();
        assert(d1 == HexTrait::new(x1, y1) && d2 == HexTrait::new(x2, y2), 'destinations');
        let [s1, s2] = v.side_edges();
        assert(s1.origin == v.origin && s1.direction.index() == e_ccw, 'side_edges ccw');
        assert(s2.origin == v.origin && s2.direction.index() == e_cw, 'side_edges cw');
        let n = v.const_neg();
        assert(n.origin == v.origin && n.direction.index() == neg, 'const_neg');
        assert(-v == n, 'neg');
        let c = v.clockwise();
        assert(c.origin == v.origin && c.direction.index() == cw, 'clockwise');
        let c = v.counter_clockwise();
        assert(c.origin == v.origin && c.direction.index() == ccw, 'counter_clockwise');
";
    e.test(
        "golden_grid_vertex_table",
        false,
        &body(
            cases,
            VERTEX_SETUP,
            "(ox, oy, d, x1, y1, x2, y2, e_ccw, e_cw, neg, cw, ccw)",
            loop_body,
        ),
    )?;

    for (k, &p) in origins.iter().enumerate() {
        let cases = cases_array("i32, i32, u8, u8, u8, u8", &vertex_rotations(p));
        let loop_body = "        let v = GridVertex { origin: HexTrait::new(ox, oy), direction: *dirs.at(d.into()) };
        let r = v.rotate_cw(offset);
        assert(r.origin == v.origin && r.direction.index() == cw, 'rotate_cw');
        let r = v.rotate_ccw(offset);
        assert(r.origin == v.origin && r.direction.index() == ccw, 'rotate_ccw');
";
        e.test(
            &format!("golden_grid_vertex_rotations_{k}"),
            false,
            &body(cases, VERTEX_SETUP, "(ox, oy, d, offset, cw, ccw)", loop_body),
        )?;
    }

    let rows: Vec<String> = origins
        .iter()
        .map(|&p| {
            let idx: Vec<String> =
                origin(p).all_vertices().iter().map(|v| v.direction.index().to_string()).collect();
            format!("{}, {}", hex_pair(origin(p)), idx.join(", "))
        })
        .collect();
    let cases = cases_array("i32, i32, u8, u8, u8, u8, u8, u8", &rows);
    let loop_body = "        let h = HexTrait::new(x, y);
        let vertices = h.all_vertices().span();
        let expected = array![i0, i1, i2, i3, i4, i5].span();
        let mut k = 0;
        while k < 6 {
            let v = *vertices.at(k);
            assert(v.origin == h && v.direction.index() == *expected.at(k), 'all_vertices');
            k += 1;
        }
";
    e.test(
        "golden_grid_vertex_all_vertices",
        false,
        &body(cases, "", "(x, y, i0, i1, i2, i3, i4, i5)", loop_body),
    )?;
    let rows: Vec<String> = VertexDirection::ALL_DIRECTIONS
        .iter()
        .map(|&d| {
            let g = GridVertex::from(d);
            format!("{}, {}", vertex_row(g), d.index())
        })
        .collect();
    let cases = cases_array("i32, i32, u8, u8", &rows);
    let loop_body = "        let g: GridVertex = (*dirs.at(source.into())).into();
        assert(g.origin == HexTrait::new(ox, oy) && g.direction.index() == d, 'into');
";
    e.test(
        "golden_grid_vertex_from_direction",
        false,
        &body(cases, VERTEX_SETUP, "(ox, oy, d, source)", loop_body),
    )?;

    // ---- `equivalent`, every ordered pair around each of the first `pair_origins` origins, in
    // chunks of `chunk` rows (the cost of a table grows faster than its length)
    let chunk = spec.int("chunk")? as usize;
    for (k, &p) in origins.iter().take(pair_origins).enumerate() {
        let h = origin(p);
        for (c, rows) in edge_pairs(h).chunks(chunk).enumerate() {
            let cases = cases_array("i32, i32, u8, i32, i32, u8, bool", rows);
            let loop_body = "        let a = GridEdge { origin: HexTrait::new(ax, ay), direction: *dirs.at(ad.into()) };
        let b = GridEdge { origin: HexTrait::new(bx, by), direction: *dirs.at(bd.into()) };
        assert(a.equivalent(b) == expected, 'equivalent');
";
            e.test(
                &format!("golden_grid_edge_equivalent_{k}_{c}"),
                false,
                &body(cases, EDGE_SETUP, "(ax, ay, ad, bx, by, bd, expected)", loop_body),
            )?;
        }
        for (c, rows) in vertex_pairs(h).chunks(chunk).enumerate() {
            let cases = cases_array("i32, i32, u8, i32, i32, u8, bool", rows);
            let loop_body = "        let a = GridVertex { origin: HexTrait::new(ax, ay), direction: *dirs.at(ad.into()) };
        let b = GridVertex { origin: HexTrait::new(bx, by), direction: *dirs.at(bd.into()) };
        assert(a.equivalent(b) == expected, 'equivalent');
";
            e.test(
                &format!("golden_grid_vertex_equivalent_{k}_{c}"),
                false,
                &body(cases, VERTEX_SETUP, "(ax, ay, ad, bx, by, bd, expected)", loop_body),
            )?;
        }
    }

    let golden = crate::target(root, spec);
    Ok(vec![(golden, e.finish()?)])
}
