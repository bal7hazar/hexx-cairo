//! `direction`: `EdgeDirection` (`src/direction/edge_direction.rs`), `VertexDirection`
//! (`vertex_direction.rs`), `DirectionWay` (`way.rs`) and the operators (`impls.rs`), exhaustive
//! (plan §4.3): the 30 and 36 constants by name, `ALL_DIRECTIONS` and `iter`, and for each of the
//! six directions of both types `index`, `into_hex` (and the `Into<_, Hex>` that `From<_> for Hex`
//! becomes), `const_neg`, `clockwise`, `counter_clockwise`, the links between the two types, then
//! `rotate_cw` and `rotate_ccw` for every `offset` of `u8` (0..=255) on every direction; the `Debug`
//! strings, `Neg`, `Mul<i32>`; `DirectionWay`: `contains` (and `PartialEq<T>`), `unwrap` and `map`
//! on every `Single` and every `Tie` of two directions (all 36 pairs). `way_from` is `pub(crate)`:
//! it has no vector from the crate, its exhaustive table is a unit test of `way.cairo`.

use hexx::{DirectionWay, EdgeDirection, Hex, VertexDirection};

use crate::cairo::{cases_array, probe, spread, Emitter, BOUND_VALUES};
use crate::spec::Spec;

macro_rules! constants {
    ($($name:ident),* $(,)?) => {
        [$((stringify!($name), EdgeDirection::$name.index())),*]
    };
}

/// The 30 compass constants of `src/direction/edge_direction.rs:79-190`, with their index.
fn compass() -> [(&'static str, u8); 30] {
    constants![
        X_NEG_Y,
        FLAT_TOP_RIGHT,
        FLAT_NORTH_EAST,
        POINTY_TOP_RIGHT,
        POINTY_NORTH_EAST,
        NEG_Y,
        FLAT_TOP,
        FLAT_NORTH,
        POINTY_TOP_LEFT,
        POINTY_NORTH_WEST,
        NEG_X,
        FLAT_TOP_LEFT,
        FLAT_NORTH_WEST,
        POINTY_LEFT,
        POINTY_WEST,
        NEG_X_Y,
        FLAT_BOTTOM_LEFT,
        FLAT_SOUTH_WEST,
        POINTY_BOTTOM_LEFT,
        POINTY_SOUTH_WEST,
        Y,
        FLAT_BOTTOM,
        FLAT_SOUTH,
        POINTY_BOTTOM_RIGHT,
        POINTY_SOUTH_EAST,
        X,
        FLAT_BOTTOM_RIGHT,
        FLAT_SOUTH_EAST,
        POINTY_RIGHT,
        POINTY_EAST,
    ]
}


macro_rules! vertex_constants {
    ($($name:ident),* $(,)?) => {
        [$((stringify!($name), VertexDirection::$name.index())),*]
    };
}

/// The 36 compass constants of `src/direction/vertex_direction.rs:78-201`, with their index.
fn vertex_compass() -> [(&'static str, u8); 36] {
    vertex_constants![
        X_NEG_Y_NEG_Z,
        X,
        FLAT_RIGHT,
        FLAT_EAST,
        POINTY_TOP_RIGHT,
        POINTY_NORTH_EAST,
        X_NEG_Y_Z,
        NEG_Y,
        FLAT_TOP_RIGHT,
        FLAT_NORTH_EAST,
        POINTY_TOP,
        POINTY_NORTH,
        NEG_X_NEG_Y,
        Z,
        FLAT_TOP_LEFT,
        FLAT_NORTH_WEST,
        POINTY_TOP_LEFT,
        POINTY_NORTH_WEST,
        NEG_X_Y_Z,
        NEG_X,
        FLAT_LEFT,
        FLAT_WEST,
        POINTY_BOTTOM_LEFT,
        POINTY_SOUTH_WEST,
        NEG_X_Y_NEG_Z,
        Y,
        FLAT_BOTTOM_LEFT,
        FLAT_SOUTH_WEST,
        POINTY_BOTTOM,
        POINTY_SOUTH,
        X_Y,
        NEG_Z,
        FLAT_BOTTOM_RIGHT,
        FLAT_SOUTH_EAST,
        POINTY_BOTTOM_RIGHT,
        POINTY_SOUTH_EAST,
    ]
}

/// The scalars of `Mul<i32>`: the small ones, the thousands, and `BOUND_VALUES` (where the
/// product of a component 1 or 2 overflows `i32` and `hexx` panics in a checked build).
fn scalars() -> Vec<i32> {
    let mut v = vec![0, 1, -1, 2, -2, 3, -3, 7, -7, 1000, -1000];
    for b in BOUND_VALUES {
        if !v.contains(&b) {
            v.push(b);
        }
    }
    v
}

/// `T` for the way tests: the two direction types of `hexx`, by their six directions.
trait Dir: Copy + PartialEq + std::fmt::Debug + std::ops::Neg<Output = Self> {
    const TYPE: &'static str;
    const ALL: [Self; 6];
    fn idx(self) -> u8;
    fn hex(self) -> Hex;
}

impl Dir for EdgeDirection {
    const TYPE: &'static str = "EdgeDirection";
    const ALL: [Self; 6] = EdgeDirection::ALL_DIRECTIONS;
    fn idx(self) -> u8 {
        self.index()
    }
    fn hex(self) -> Hex {
        self.into_hex()
    }
}

impl Dir for VertexDirection {
    const TYPE: &'static str = "VertexDirection";
    const ALL: [Self; 6] = VertexDirection::ALL_DIRECTIONS;
    fn idx(self) -> u8 {
        self.index()
    }
    fn hex(self) -> Hex {
        self.into_hex()
    }
}

pub fn emit(spec: &Spec) -> Result<String, String> {
    let mut e = Emitter::new(
        spec,
        "`EdgeDirection` (src/direction/edge_direction.rs:75), the constants :79-190,\n// `ALL_DIRECTIONS` :208, `iter` :212, `index` :219, `into_hex` :226, `const_neg` :243,\n// `clockwise` :261, `counter_clockwise` :279, `rotate_ccw` :296, `rotate_cw` :313,\n// `diagonal_ccw` :571, `vertex_ccw` :586, `diagonal_cw` :601, `vertex_cw` :616,\n// `vertex_directions` :623, `From<EdgeDirection> for Hex` :628, `Debug` :635;\n// `VertexDirection` (src/direction/vertex_direction.rs:74), the constants :78-201,\n// `ALL_DIRECTIONS` :221, `iter` :225, `index` :232, `into_hex` :239, `const_neg` :253,\n// `clockwise` :268, `counter_clockwise` :286, `rotate_ccw` :300, `rotate_cw` :314,\n// `direction_ccw` :573, `edge_ccw` :588, `direction_cw` :603, `edge_cw` :618,\n// `edge_directions` :625, `From<VertexDirection> for Hex` :630, `Debug` :637;\n// `DirectionWay` (src/direction/way.rs:8), `contains` :62 (and `PartialEq<T>` :42),\n// `unwrap` :53, `map` :75, `From<T>` :95, `From<[T; 2]>` :102;\n// the operators (src/direction/impls.rs), `Neg` :5 :13, `Mul<i32>` :53 :61",
        "use hexx::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};\nuse hexx::direction::impls::{\n    EdgeDirectionNeg, EdgeDirectionOpsTrait, VertexDirectionNeg, VertexDirectionOpsTrait,\n};\nuse hexx::direction::vertex_direction::{VertexDirection, VertexDirectionTrait};\nuse hexx::direction::way::{DirectionWay, DirectionWayTrait};\nuse hexx::hex::{Hex, HexTrait};\n",
    );

    // The 30 constants by name.
    let mut body = String::new();
    for (name, index) in compass() {
        body.push_str(&format!(
            "    assert(EdgeDirectionTrait::{name}.index() == {index}, '{name}');\n"
        ));
    }
    e.test("golden_edge_direction_constants", false, &body)?;

    // ALL_DIRECTIONS and iter: same six, in index order; the Span is the iterator.
    let mut body = String::from(
        "    let all = EdgeDirectionTrait::ALL_DIRECTIONS;\n    let all = all.span();\n    let iter = EdgeDirectionTrait::iter();\n",
    );
    body.push_str(&format!("    assert(all.len() == {}, 'ALL_DIRECTIONS len');\n", EdgeDirection::ALL_DIRECTIONS.len()));
    body.push_str(&format!("    assert(iter.len() == {}, 'iter len');\n", EdgeDirection::iter().len()));
    for (i, d) in EdgeDirection::ALL_DIRECTIONS.iter().enumerate() {
        body.push_str(&format!(
            "    assert((*all.at({i})).index() == {0}, 'ALL_DIRECTIONS {i}');\n    assert((*iter.at({i})).index() == {0}, 'iter {i}');\n",
            d.index()
        ));
    }
    for (i, d) in EdgeDirection::iter().enumerate() {
        assert_eq!(d, EdgeDirection::ALL_DIRECTIONS[i]);
    }
    e.test("golden_edge_direction_all", false, &body)?;

    // The table of the six directions: (index, into_hex.x, into_hex.y, const_neg, clockwise,
    // counter_clockwise), the directions taken from `ALL_DIRECTIONS`.
    let rows: Vec<String> = EdgeDirection::ALL_DIRECTIONS
        .iter()
        .map(|d| {
            let h: Hex = (*d).into();
            assert_eq!(h, d.into_hex());
            format!(
                "{}, {}, {}, {}, {}, {}",
                d.index(),
                h.x,
                h.y,
                d.const_neg().index(),
                d.clockwise().index(),
                d.counter_clockwise().index()
            )
        })
        .collect();
    let body = format!(
        "{}    let all = EdgeDirectionTrait::ALL_DIRECTIONS;
    let all = all.span();
    let mut i = 0;
    while i < cases.len() {{
        let (index, x, y, neg, cw, ccw) = *cases.at(i);
        let d = *all.at(index.into());
        assert(d.index() == index, 'index');
        assert(d.into_hex() == HexTrait::new(x, y), 'into_hex');
        let h: Hex = d.into();
        assert(h == HexTrait::new(x, y), 'into');
        assert(d.const_neg().index() == neg, 'const_neg');
        assert(d.clockwise().index() == cw, 'clockwise');
        assert(d.counter_clockwise().index() == ccw, 'counter_clockwise');
        i += 1;
    }}
",
        cases_array("u8, i32, i32, u8, u8, u8", &rows)
    );
    e.test("golden_edge_direction_table", false, &body)?;

    // Every rotation count of `u8` on every direction, one test per direction.
    for (i, d) in EdgeDirection::ALL_DIRECTIONS.iter().enumerate() {
        let rows: Vec<String> = (0..=255u8)
            .map(|offset| {
                format!("{offset}, {}, {}", d.rotate_cw(offset).index(), d.rotate_ccw(offset).index())
            })
            .collect();
        let body = format!(
            "{}    let d = *EdgeDirectionTrait::iter().at({i});
    let mut i = 0;
    while i < cases.len() {{
        let (offset, cw, ccw) = *cases.at(i);
        assert(d.rotate_cw(offset).index() == cw, 'rotate_cw');
        assert(d.rotate_ccw(offset).index() == ccw, 'rotate_ccw');
        i += 1;
    }}
",
            cases_array("u8, u8, u8", &rows)
        );
        e.test(&format!("golden_edge_direction_rotations_{i}"), false, &body)?;
    }

    // ---- L-M2 (LIB-06 M2-T1): the links between the types, `VertexDirection`, the operators,
    // `Debug`, `DirectionWay`.

    // The new items of `EdgeDirection`: the vertices next to each edge.
    let rows: Vec<String> = EdgeDirection::ALL_DIRECTIONS
        .iter()
        .map(|d| {
            assert_eq!(d.diagonal_ccw(), d.vertex_ccw());
            assert_eq!(d.diagonal_cw(), d.vertex_cw());
            assert_eq!(d.vertex_directions(), [d.vertex_ccw(), d.vertex_cw()]);
            format!(
                "{}, {}, {}",
                d.index(),
                d.vertex_ccw().index(),
                d.vertex_cw().index()
            )
        })
        .collect();
    let body = format!(
        "{}    let all = EdgeDirectionTrait::ALL_DIRECTIONS;
    let all = all.span();
    let mut i = 0;
    while i < cases.len() {{
        let (index, ccw, cw) = *cases.at(i);
        let d = *all.at(index.into());
        assert(d.vertex_ccw().index() == ccw, 'vertex_ccw');
        assert(d.diagonal_ccw().index() == ccw, 'diagonal_ccw');
        assert(d.vertex_cw().index() == cw, 'vertex_cw');
        assert(d.diagonal_cw().index() == cw, 'diagonal_cw');
        let [a, b] = d.vertex_directions();
        assert(a.index() == ccw && b.index() == cw, 'vertex_directions');
        i += 1;
    }}
",
        cases_array("u8, u8, u8", &rows)
    );
    e.test("golden_edge_direction_vertices", false, &body)?;

    // `VertexDirection`: the 36 constants by name.
    let mut body = String::new();
    for (name, index) in vertex_compass() {
        body.push_str(&format!(
            "    assert(VertexDirectionTrait::{name}.index() == {index}, '{name}');\n"
        ));
    }
    e.test("golden_vertex_direction_constants", false, &body)?;

    // ALL_DIRECTIONS and iter.
    let mut body = String::from(
        "    let all = VertexDirectionTrait::ALL_DIRECTIONS;\n    let all = all.span();\n    let iter = VertexDirectionTrait::iter();\n",
    );
    body.push_str(&format!("    assert(all.len() == {}, 'ALL_DIRECTIONS len');\n", VertexDirection::ALL_DIRECTIONS.len()));
    body.push_str(&format!("    assert(iter.len() == {}, 'iter len');\n", VertexDirection::iter().len()));
    for (i, d) in VertexDirection::ALL_DIRECTIONS.iter().enumerate() {
        body.push_str(&format!(
            "    assert((*all.at({i})).index() == {0}, 'ALL_DIRECTIONS {i}');\n    assert((*iter.at({i})).index() == {0}, 'iter {i}');\n",
            d.index()
        ));
    }
    for (i, d) in VertexDirection::iter().enumerate() {
        assert_eq!(d, VertexDirection::ALL_DIRECTIONS[i]);
    }
    e.test("golden_vertex_direction_all", false, &body)?;

    // The table of the six vertex directions, with the links to the edge directions.
    let rows: Vec<String> = VertexDirection::ALL_DIRECTIONS
        .iter()
        .map(|d| {
            let h: Hex = (*d).into();
            assert_eq!(h, d.into_hex());
            assert_eq!(d.direction_ccw(), d.edge_ccw());
            assert_eq!(d.direction_cw(), d.edge_cw());
            assert_eq!(d.edge_directions(), [d.edge_ccw(), d.edge_cw()]);
            format!(
                "{}, {}, {}, {}, {}, {}, {}, {}",
                d.index(),
                h.x,
                h.y,
                d.const_neg().index(),
                d.clockwise().index(),
                d.counter_clockwise().index(),
                d.edge_ccw().index(),
                d.edge_cw().index()
            )
        })
        .collect();
    let body = format!(
        "{}    let all = VertexDirectionTrait::ALL_DIRECTIONS;
    let all = all.span();
    let mut i = 0;
    while i < cases.len() {{
        let (index, x, y, neg, cw, ccw, edge_ccw, edge_cw) = *cases.at(i);
        let d = *all.at(index.into());
        assert(d.index() == index, 'index');
        assert(d.into_hex() == HexTrait::new(x, y), 'into_hex');
        let h: Hex = d.into();
        assert(h == HexTrait::new(x, y), 'into');
        assert(d.const_neg().index() == neg, 'const_neg');
        assert(d.clockwise().index() == cw, 'clockwise');
        assert(d.counter_clockwise().index() == ccw, 'counter_clockwise');
        assert(d.edge_ccw().index() == edge_ccw, 'edge_ccw');
        assert(d.direction_ccw().index() == edge_ccw, 'direction_ccw');
        assert(d.edge_cw().index() == edge_cw, 'edge_cw');
        assert(d.direction_cw().index() == edge_cw, 'direction_cw');
        let [a, b] = d.edge_directions();
        assert(a.index() == edge_ccw && b.index() == edge_cw, 'edge_directions');
        i += 1;
    }}
",
        cases_array("u8, i32, i32, u8, u8, u8, u8, u8", &rows)
    );
    e.test("golden_vertex_direction_table", false, &body)?;

    // Every rotation count of `u8` on every vertex direction, one test per direction.
    for (i, d) in VertexDirection::ALL_DIRECTIONS.iter().enumerate() {
        let rows: Vec<String> = (0..=255u8)
            .map(|offset| {
                format!("{offset}, {}, {}", d.rotate_cw(offset).index(), d.rotate_ccw(offset).index())
            })
            .collect();
        let body = format!(
            "{}    let d = *VertexDirectionTrait::iter().at({i});
    let mut i = 0;
    while i < cases.len() {{
        let (offset, cw, ccw) = *cases.at(i);
        assert(d.rotate_cw(offset).index() == cw, 'rotate_cw');
        assert(d.rotate_ccw(offset).index() == ccw, 'rotate_ccw');
        i += 1;
    }}
",
            cases_array("u8, u8, u8", &rows)
        );
        e.test(&format!("golden_vertex_direction_rotations_{i}"), false, &body)?;
    }

    // `Debug`: the strings of `format!("{:?}")`, both types, six directions each.
    let mut body = String::from(
        "    let edges = EdgeDirectionTrait::ALL_DIRECTIONS;\n    let edges = edges.span();\n    let vertices = VertexDirectionTrait::ALL_DIRECTIONS;\n    let vertices = vertices.span();\n",
    );
    for (i, d) in EdgeDirection::ALL_DIRECTIONS.iter().enumerate() {
        body.push_str(&format!(
            "    assert!(format!(\"{{:?}}\", *edges.at({i})) == \"{d:?}\");\n"
        ));
    }
    for (i, d) in VertexDirection::ALL_DIRECTIONS.iter().enumerate() {
        body.push_str(&format!(
            "    assert!(format!(\"{{:?}}\", *vertices.at({i})) == \"{d:?}\");\n"
        ));
    }
    e.test("golden_direction_debug", false, &body)?;

    // `Neg`: the `-` operator on every direction of both types.
    let mut body = String::from(
        "    let edges = EdgeDirectionTrait::ALL_DIRECTIONS;\n    let edges = edges.span();\n    let vertices = VertexDirectionTrait::ALL_DIRECTIONS;\n    let vertices = vertices.span();\n",
    );
    for (i, d) in EdgeDirection::ALL_DIRECTIONS.iter().enumerate() {
        body.push_str(&format!("    assert((-*edges.at({i})).index() == {}, 'edge neg {i}');\n", (-*d).index()));
    }
    for (i, d) in VertexDirection::ALL_DIRECTIONS.iter().enumerate() {
        body.push_str(&format!("    assert((-*vertices.at({i})).index() == {}, 'vertex neg {i}');\n", (-*d).index()));
    }
    e.test("golden_direction_neg", false, &body)?;

    // `Mul<i32>` (`mul_scalar`): every direction by every scalar, the results that fit, then a
    // `#[should_panic]` test for an evenly spaced pick of the products that leave `i32` (where
    // `hexx` panics in a checked build, `refgen` has overflow checks in every profile).
    macro_rules! mul_scalar_tests {
        ($ty:ty, $trait_:literal, $name:literal, $all:literal) => {{
            let mut rows = Vec::new();
            let mut panics = Vec::new();
            for (i, d) in <$ty>::ALL_DIRECTIONS.iter().enumerate() {
                for rhs in scalars() {
                    match probe(|| *d * rhs) {
                        Some(h) => rows.push(format!("{i}, {rhs}, {}, {}", h.x, h.y)),
                        None => panics.push((i, rhs)),
                    }
                }
            }
            let body = format!(
                "{}    let all = {}::ALL_DIRECTIONS;
    let all = all.span();
    let mut i = 0;
    while i < cases.len() {{
        let (index, rhs, x, y) = *cases.at(i);
        assert((*all.at(index.into())).mul_scalar(rhs) == HexTrait::new(x, y), 'mul_scalar');
        i += 1;
    }}
",
                cases_array("u8, i32, i32, i32", &rows),
                $trait_
            );
            e.test(concat!("golden_", $name, "_mul_scalar"), false, &body)?;
            for (k, (i, rhs)) in spread(&panics, 2).into_iter().enumerate() {
                let body = format!(
                    "    let all = {}::ALL_DIRECTIONS;\n    let all = all.span();\n    (*all.at({i})).mul_scalar({rhs});\n",
                    $trait_
                );
                e.test(&format!(concat!("golden_", $name, "_mul_scalar_revert_overflow_{}"), k), true, &body)?;
            }
        }};
    }
    mul_scalar_tests!(EdgeDirection, "EdgeDirectionTrait", "edge_direction", "edges");
    mul_scalar_tests!(VertexDirection, "VertexDirectionTrait", "vertex_direction", "vertices");

    // `DirectionWay<T>` for both types: `contains` and `PartialEq<T>` (216 + 36 cases), `unwrap`,
    // `map` to `u8` and to `Hex` on the 6 singles and the 36 ties.
    way_tests::<EdgeDirection>(&mut e, "edge_direction", "EdgeDirectionTrait")?;
    way_tests::<VertexDirection>(&mut e, "vertex_direction", "VertexDirectionTrait")?;
    e.finish()
}

/// The `DirectionWay` tests of one direction type: `name` prefixes the test names, `trait_` is the
/// Cairo trait that holds `ALL_DIRECTIONS`.
fn way_tests<T: Dir>(e: &mut Emitter, name: &str, trait_: &str) -> Result<(), String> {
    let ty = T::TYPE;
    let idx = |i: usize| T::ALL[i];
    let _ = idx;

    // The way of each case, rebuilt for each call: `DirectionWay` is neither `Clone` nor `Copy`.
    let single = |a: usize| DirectionWay::from(T::ALL[a]);
    let tie = |a: usize, b: usize| DirectionWay::from([T::ALL[a], T::ALL[b]]);

    // `contains` (and `PartialEq<T>`): `Single` 6 x 6, `Tie` 36 pairs x 6 directions.
    let mut rows = Vec::new();
    for a in 0..6 {
        for d in 0..6 {
            let expected = single(a).contains(&T::ALL[d]);
            assert_eq!(expected, single(a) == T::ALL[d]);
            rows.push(format!("0, {a}, 0, {d}, {expected}"));
        }
    }
    for a in 0..6 {
        for b in 0..6 {
            for d in 0..6 {
                let expected = tie(a, b).contains(&T::ALL[d]);
                assert_eq!(expected, tie(a, b) == T::ALL[d]);
                rows.push(format!("1, {a}, {b}, {d}, {expected}"));
            }
        }
    }
    let body = format!(
        "{}    let all = {trait_}::ALL_DIRECTIONS;
    let all = all.span();
    let mut i = 0;
    while i < cases.len() {{
        let (kind, a, b, d, expected) = *cases.at(i);
        let da: {ty} = *all.at(a.into());
        let db: {ty} = *all.at(b.into());
        let dir: {ty} = *all.at(d.into());
        let way: DirectionWay<{ty}> = if kind == 0 {{
            da.into()
        }} else {{
            [da, db].into()
        }};
        assert(way.contains(@dir) == expected, 'contains');
        i += 1;
    }}
",
        cases_array("u8, u8, u8, u8, bool", &rows)
    );
    e.test(&format!("golden_{name}_way_contains"), false, &body)?;

    // `unwrap`, and `map` to `u8` (`index`) and to `Hex` (`into_hex`): (kind, a, b, ax, ay, bx, by,
    // unwrap, index of a, index of b).
    let mut rows = Vec::new();
    for a in 0..6 {
        let (h, _) = (T::ALL[a].hex(), ());
        assert_eq!(single(a).unwrap(), T::ALL[a]);
        let mapped = single(a).map(|d| d.idx());
        assert!(matches!(mapped, DirectionWay::Single(v) if v == T::ALL[a].idx()));
        rows.push(format!("0, {a}, 0, {}, {}, 0, 0, {}, {}, 0", h.x, h.y, T::ALL[a].idx(), T::ALL[a].idx()));
    }
    for a in 0..6 {
        for b in 0..6 {
            let (ha, hb) = (T::ALL[a].hex(), T::ALL[b].hex());
            assert_eq!(tie(a, b).unwrap(), T::ALL[a]);
            let mapped = tie(a, b).map(|d| d.idx());
            assert!(
                matches!(mapped, DirectionWay::Tie([x, y]) if x == T::ALL[a].idx() && y == T::ALL[b].idx())
            );
            rows.push(format!(
                "1, {a}, {b}, {}, {}, {}, {}, {}, {}, {}",
                ha.x,
                ha.y,
                hb.x,
                hb.y,
                T::ALL[a].idx(),
                T::ALL[a].idx(),
                T::ALL[b].idx()
            ));
        }
    }
    let body = format!(
        "{}    let all = {trait_}::ALL_DIRECTIONS;
    let all = all.span();
    let mut i = 0;
    while i < cases.len() {{
        let (kind, a, b, ax, ay, bx, by, first, ia, ib) = *cases.at(i);
        let da: {ty} = *all.at(a.into());
        let db: {ty} = *all.at(b.into());
        let way: DirectionWay<{ty}> = if kind == 0 {{
            da.into()
        }} else {{
            [da, db].into()
        }};
        assert(way.unwrap().index() == first, 'unwrap');
        let indices = way.map(|d: {ty}| d.index());
        let hexes = way.map(|d: {ty}| d.into_hex());
        match indices {{
            DirectionWay::Single(v) => {{ assert(kind == 0 && v == ia, 'map single index'); }},
            DirectionWay::Tie(pair) => {{
                let [x, y] = pair;
                assert(kind == 1 && x == ia && y == ib, 'map tie index');
            }},
        }}
        match hexes {{
            DirectionWay::Single(h) => {{
                assert(kind == 0 && h == HexTrait::new(ax, ay), 'map single hex');
            }},
            DirectionWay::Tie(pair) => {{
                let [h, g] = pair;
                assert(
                    kind == 1 && h == HexTrait::new(ax, ay) && g == HexTrait::new(bx, by),
                    'map tie hex',
                );
            }},
        }}
        i += 1;
    }}
",
        cases_array("u8, u8, u8, i32, i32, i32, i32, u8, u8, u8", &rows)
    );
    e.test(&format!("golden_{name}_way_unwrap_map"), false, &body)?;
    Ok(())
}
