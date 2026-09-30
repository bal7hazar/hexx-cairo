//! `direction`: `EdgeDirection` (`src/direction/edge_direction.rs`), exhaustive (plan §4.3): the 30
//! constants by name, `ALL_DIRECTIONS` and `iter`, and for each of the six directions `index`,
//! `into_hex` (and the `Into<EdgeDirection, Hex>` that `From<EdgeDirection> for Hex` becomes),
//! `const_neg`, `clockwise`, `counter_clockwise`, then `rotate_cw` and `rotate_ccw` for every
//! `offset` of `u8` (0..=255) on every direction.

use hexx::{EdgeDirection, Hex};

use crate::cairo::{cases_array, Emitter};
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

pub fn emit(spec: &Spec) -> Result<String, String> {
    let mut e = Emitter::new(
        spec,
        "`EdgeDirection` (src/direction/edge_direction.rs:75), the constants :79-190,\n// `ALL_DIRECTIONS` :208, `iter` :212, `index` :219, `into_hex` :226, `const_neg` :243,\n// `clockwise` :261, `counter_clockwise` :279, `rotate_ccw` :296, `rotate_cw` :313,\n// `From<EdgeDirection> for Hex` :628",
        "use hexx::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};\nuse hexx::hex::{Hex, HexTrait};\n",
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
    e.finish()
}
