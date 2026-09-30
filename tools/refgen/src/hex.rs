//! `hex`: the items of `impl Hex` of milestone L-M1 (`src/hex/mod.rs`): `new`, `x`, `y`, `z`,
//! `ZERO`, `NEIGHBORS_COORDS`, `const_sub`, `length`, `ulength`, `distance_to`,
//! `unsigned_distance_to`.
//!
//! Inputs (plan §4.3): `points` seeded coordinates of `[domain_min, domain_max]²`; the unary
//! functions on each, the binary functions on every ordered pair of them (`chunks` tests of
//! `points / chunks` rows each); then the `i32` values near the bounds (`cairo::BOUND_VALUES`),
//! where `hexx` panics in a debug build and wraps in a release build: a table per function of the
//! cases where `hexx` returns, and a `#[should_panic]` test for the cases where it panics (at most
//! `panic_cap` per function, evenly spread over the cases that panic).

use hexx::Hex;

use crate::cairo::{bound_points, cases_array, probe, seeded_points, spread, Emitter};
use crate::spec::Spec;

/// `(x, y, z, length, ulength)`, `None` when `hexx` panics.
fn unary(x: i32, y: i32) -> Option<(i32, i32, i32, i32, u32)> {
    probe(|| {
        let h = Hex::new(x, y);
        (x, y, h.z(), h.length(), h.ulength())
    })
}

/// `(x1, y1, x2, y2, distance_to, unsigned_distance_to, const_sub.x, const_sub.y)`.
fn binary(a: (i32, i32), b: (i32, i32)) -> Option<(i32, i32, i32, i32, i32, u32, i32, i32)> {
    probe(|| {
        let (p, q) = (Hex::new(a.0, a.1), Hex::new(b.0, b.1));
        let sub = p.const_sub(q);
        (a.0, a.1, b.0, b.1, p.distance_to(q), p.unsigned_distance_to(q), sub.x, sub.y)
    })
}

const UNARY_TYPES: &str = "i32, i32, i32, i32, u32";
const BINARY_TYPES: &str = "i32, i32, i32, i32, i32, u32, i32, i32";

const UNARY_LOOP: &str = "    let mut i = 0;
    while i < cases.len() {
        let (x, y, z, length, ulength) = *cases.at(i);
        let h = HexTrait::new(x, y);
        assert(h.x() == x, 'x');
        assert(h.y() == y, 'y');
        assert(h.x == x && h.y == y, 'fields');
        assert(h.z() == z, 'z');
        assert(h.length() == length, 'length');
        assert(h.ulength() == ulength, 'ulength');
        i += 1;
    }
";

const BINARY_LOOP: &str = "    let mut i = 0;
    while i < cases.len() {
        let (x1, y1, x2, y2, distance, unsigned_distance, sx, sy) = *cases.at(i);
        let a = HexTrait::new(x1, y1);
        let b = HexTrait::new(x2, y2);
        assert(a.distance_to(b) == distance, 'distance_to');
        assert(a.unsigned_distance_to(b) == unsigned_distance, 'unsigned_distance_to');
        assert(a.const_sub(b) == HexTrait::new(sx, sy), 'const_sub');
        i += 1;
    }
";

/// A unary function under test: its name, the Cairo type of its result, `hexx`'s result as a
/// literal (`None` when it panics), and the Cairo call.
type UnaryFn = (&'static str, &'static str, fn(Hex) -> Option<String>, &'static str);

/// A binary function under test: the same, on a pair; `const_sub` returns two values.
type BinaryFn = (&'static str, &'static str, fn(Hex, Hex) -> Option<String>, &'static str);

const UNARY_FNS: [UnaryFn; 3] = [
    ("z", "i32", |h| probe(|| h.z().to_string()), "h.z()"),
    ("length", "i32", |h| probe(|| h.length().to_string()), "h.length()"),
    ("ulength", "u32", |h| probe(|| h.ulength().to_string()), "h.ulength()"),
];

const BINARY_FNS: [BinaryFn; 3] = [
    (
        "const_sub",
        "i32, i32",
        |a, b| {
            probe(|| {
                let d = a.const_sub(b);
                format!("{}, {}", d.x, d.y)
            })
        },
        "a.const_sub(b)",
    ),
    ("distance_to", "i32", |a, b| probe(|| a.distance_to(b).to_string()), "a.distance_to(b)"),
    (
        "unsigned_distance_to",
        "u32",
        |a, b| probe(|| a.unsigned_distance_to(b).to_string()),
        "a.unsigned_distance_to(b)",
    ),
];

/// The pairs near the bounds: the extremes, the axes and the halves, every ordered pair.
const BOUND_PAIR_POINTS: [(i32, i32); 15] = [
    (i32::MAX, 0),
    (i32::MIN, 0),
    (0, i32::MAX),
    (0, i32::MIN),
    (i32::MAX, i32::MIN),
    (i32::MIN, i32::MAX),
    (i32::MAX, i32::MAX),
    (i32::MIN, i32::MIN),
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
    (1_073_741_824, 0),
    (-1_073_741_824, 0),
    (0, 0),
];

pub fn emit(spec: &Spec) -> Result<String, String> {
    let points = seeded_points(
        &spec.text("seed")?,
        spec.int("points")? as usize,
        spec.int("domain_min")? as i32,
        spec.int("domain_max")? as i32,
    );
    let chunks = spec.int("chunks")? as usize;
    let panic_cap = spec.int("panic_cap")? as usize;
    if points.len() % chunks != 0 {
        return Err("specs/hex.toml: `points` is not a multiple of `chunks`".into());
    }

    let mut e = Emitter::new(
        spec,
        "`Hex` (src/hex/mod.rs:69), `new` :208, `x` :256, `y` :264, `z` :274,\n// `const_sub` :449, `length` :568, `ulength` :594, `distance_to` :615, `unsigned_distance_to` :625",
        "use hexx::hex::{Hex, HexTrait};\n",
    );

    // Constants.
    let mut body = String::new();
    body.push_str(&format!(
        "    assert(HexTrait::ZERO == HexTrait::new({}, {}), 'ZERO');\n",
        Hex::ZERO.x,
        Hex::ZERO.y
    ));
    body.push_str("    let neighbors = HexTrait::NEIGHBORS_COORDS;\n");
    body.push_str("    let neighbors = neighbors.span();\n");
    body.push_str(&format!("    assert(neighbors.len() == {}, 'len');\n", Hex::NEIGHBORS_COORDS.len()));
    for (i, n) in Hex::NEIGHBORS_COORDS.iter().enumerate() {
        body.push_str(&format!(
            "    assert(*neighbors.at({i}) == HexTrait::new({}, {}), 'NEIGHBORS_COORDS {i}');\n",
            n.x, n.y
        ));
    }
    e.test("golden_hex_constants", false, &body)?;

    // The seeded points, unary.
    let rows: Vec<String> = points
        .iter()
        .map(|&(x, y)| {
            let c = unary(x, y).ok_or("hexx panics inside the seeded domain")?;
            Ok(format!("{}, {}, {}, {}, {}", c.0, c.1, c.2, c.3, c.4))
        })
        .collect::<Result<_, String>>()?;
    let body = format!("{}{UNARY_LOOP}", cases_array(UNARY_TYPES, &rows));
    e.test("golden_hex_unary", false, &body)?;

    // The seeded points, every ordered pair, in `chunks` tests.
    let per_chunk = points.len() / chunks;
    for chunk in 0..chunks {
        let mut rows = Vec::new();
        for &a in &points[chunk * per_chunk..(chunk + 1) * per_chunk] {
            for &b in &points {
                let c = binary(a, b).ok_or("hexx panics inside the seeded domain")?;
                rows.push(format!(
                    "{}, {}, {}, {}, {}, {}, {}, {}",
                    c.0, c.1, c.2, c.3, c.4, c.5, c.6, c.7
                ));
            }
        }
        let body = format!("{}{BINARY_LOOP}", cases_array(BINARY_TYPES, &rows));
        e.test(&format!("golden_hex_pairs_{chunk}"), false, &body)?;
    }

    // Near the bounds, unary.
    let bounds = bound_points();
    for (name, ty, eval, call) in UNARY_FNS {
        let mut rows = Vec::new();
        let mut failing = Vec::new();
        for &(x, y) in &bounds {
            match eval(Hex::new(x, y)) {
                Some(value) => rows.push(format!("{x}, {y}, {value}")),
                None => failing.push((x, y)),
            }
        }
        let body = format!(
            "{}    let mut i = 0;
    while i < cases.len() {{
        let (x, y, expected) = *cases.at(i);
        let h = HexTrait::new(x, y);
        assert({call} == expected, '{name}');
        i += 1;
    }}
",
            cases_array(&format!("i32, i32, {ty}"), &rows)
        );
        e.test(&format!("golden_hex_bounds_{name}"), false, &body)?;
        if failing.is_empty() {
            return Err(format!("no bound value makes hexx panic in {name}"));
        }
        for (n, (x, y)) in spread(&failing, panic_cap).into_iter().enumerate() {
            let body = format!("    let h = HexTrait::new({x}, {y});\n    let _ = {call};\n");
            e.test(&format!("golden_hex_{name}_panics_{n}"), true, &body)?;
        }
    }

    // Near the bounds, binary.
    let pairs: Vec<((i32, i32), (i32, i32))> = BOUND_PAIR_POINTS
        .iter()
        .flat_map(|&a| BOUND_PAIR_POINTS.iter().map(move |&b| (a, b)))
        .collect();
    for (name, ty, eval, call) in BINARY_FNS {
        let mut rows = Vec::new();
        let mut failing = Vec::new();
        for &(a, b) in &pairs {
            match eval(Hex::new(a.0, a.1), Hex::new(b.0, b.1)) {
                Some(value) => rows.push(format!("{}, {}, {}, {}, {value}", a.0, a.1, b.0, b.1)),
                None => failing.push((a, b)),
            }
        }
        let (destructure, check) = if name == "const_sub" {
            ("let (x1, y1, x2, y2, sx, sy) = *cases.at(i);", format!("{call} == HexTrait::new(sx, sy)"))
        } else {
            ("let (x1, y1, x2, y2, expected) = *cases.at(i);", format!("{call} == expected"))
        };
        let body = format!(
            "{}    let mut i = 0;
    while i < cases.len() {{
        {destructure}
        let a = HexTrait::new(x1, y1);
        let b = HexTrait::new(x2, y2);
        assert({check}, '{name}');
        i += 1;
    }}
",
            cases_array(&format!("i32, i32, i32, i32, {ty}"), &rows)
        );
        e.test(&format!("golden_hex_bounds_{name}"), false, &body)?;
        if failing.is_empty() {
            return Err(format!("no bound pair makes hexx panic in {name}"));
        }
        for (n, (a, b)) in spread(&failing, panic_cap).into_iter().enumerate() {
            let body = format!(
                "    let a = HexTrait::new({}, {});\n    let b = HexTrait::new({}, {});\n    let _ = {call};\n",
                a.0, a.1, b.0, b.1
            );
            e.test(&format!("golden_hex_{name}_panics_{n}"), true, &body)?;
        }
    }
    e.finish()
}
