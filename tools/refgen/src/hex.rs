//! `hex`: the items of `impl Hex` of milestone L-M1 (`src/hex/mod.rs`): `new`, `x`, `y`, `z`,
//! `ZERO`, `NEIGHBORS_COORDS`, `const_sub`, `length`, `ulength`, `distance_to`,
//! `unsigned_distance_to`; and the shared items of M2-T0: the constants, `hex`, `splat`,
//! `new_cubic`, `from_array`, `to_array`, `to_cubic_array`, `const_neg`, `const_add`, `abs`, `min`,
//! `max`, `dot`, `signum`, `range_count`, `ring_count`, `wedge_count`, `mul_scalar` (the `Mul<i32>`
//! operator), `neighbor_coord`, `add_dir`, `neighbor`, `all_neighbors`.
//!
//! Inputs (plan §4.3): `points` seeded coordinates of `[domain_min, domain_max]²`; the unary
//! functions on each, the binary functions on every ordered pair of them (`chunks` tests of
//! `points / chunks` rows each); then the `i32` values near the bounds (`cairo::BOUND_VALUES`),
//! where `hexx` panics in a debug build and wraps in a release build: a table per function of the
//! cases where `hexx` returns, and a `#[should_panic]` test for the cases where it panics (at most
//! `panic_cap` per function, evenly spread over the cases that panic).

use hexx::{DirectionWay, EdgeDirection, Hex, VertexDirection};

use crate::cairo::{bound_points, cases_array as packed_cases, probe, seeded_points, spread, Emitter};
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

/// A function under test over the inputs `I`: its name, the Cairo types and variable names of its
/// result in a table row, the Cairo expression of the call (`r` is bound to it), the assertion on
/// `r` and the row's variables, and `hexx`'s result as literals (`None` when it panics).
struct Fun<I> {
    name: &'static str,
    types: &'static str,
    vars: &'static str,
    call: &'static str,
    check: &'static str,
    eval: fn(I) -> Option<Vec<String>>,
}

/// How the inputs of a table are written: the row's types and variables, and the Cairo lines that
/// build the inputs from them.
struct Inputs<I> {
    types: &'static str,
    vars: &'static str,
    prelude: &'static str,
    /// The literals of one input.
    row: fn(I) -> String,
}

/// `cairo::cases_array`, with the header split after `=` when it exceeds 100 columns, as
/// `scarb fmt` splits it (the table of `all_neighbors` has fourteen columns).
fn cases_array(types: &str, rows: &[String]) -> String {
    let text = packed_cases(types, rows);
    let (first, rest) = text.split_once('\n').unwrap_or((&text, ""));
    if first.len() <= 100 {
        return text;
    }
    let head = first.strip_suffix(" array![").unwrap_or(first);
    format!("{head}\n        array![\n{rest}")
}

/// `text`, every line indented by `spaces`.
fn indented(text: &str, spaces: usize) -> String {
    text.lines().map(|l| format!("{}{l}\n", " ".repeat(spaces))).collect()
}

fn hex_row(h: (i32, i32)) -> String {
    format!("{}, {}", h.0, h.1)
}

fn pair_row(p: ((i32, i32), (i32, i32))) -> String {
    format!("{}, {}, {}, {}", (p.0).0, (p.0).1, (p.1).0, (p.1).1)
}

fn scalar_row(p: ((i32, i32), i32)) -> String {
    format!("{}, {}, {}", (p.0).0, (p.0).1, p.1)
}

fn direction_row(p: ((i32, i32), usize)) -> String {
    format!("{}, {}, {}", (p.0).0, (p.0).1, p.1)
}

fn h(p: (i32, i32)) -> Hex {
    Hex::new(p.0, p.1)
}

fn pair(h: Hex) -> Vec<String> {
    vec![h.x.to_string(), h.y.to_string()]
}

fn one(v: impl ToString) -> Vec<String> {
    vec![v.to_string()]
}

/// One table test per function over `inputs` (the cases where `hexx` returns), plus, when
/// `panics` is set, up to `panic_cap` `#[should_panic]` tests per function (evenly spread over the
/// inputs where `hexx` panics). Without `panics`, an input that panics is an error: the seeded
/// domain never overflows. A function that never panics near the bounds has no such tests.
fn tables<I: Copy>(
    e: &mut Emitter,
    prefix: &str,
    inputs: &[I],
    layout: &Inputs<I>,
    funs: &[Fun<I>],
    panics: Option<usize>,
) -> Result<(), String> {
    for fun in funs {
        let mut rows = Vec::new();
        let mut failing = Vec::new();
        for &input in inputs {
            match (fun.eval)(input) {
                Some(values) => rows.push(format!("{}, {}", (layout.row)(input), values.join(", "))),
                None if panics.is_some() => failing.push(input),
                None => return Err(format!("hexx panics inside the seeded domain: {}", fun.name)),
            }
        }
        let body = format!(
            "{}    let mut i = 0;
    while i < cases.len() {{
        let ({}, {}) = *cases.at(i);
{}        let r = {};
        assert({}, '{}');
        i += 1;
    }}
",
            cases_array(&format!("{}, {}", layout.types, fun.types), &rows),
            layout.vars,
            fun.vars,
            indented(layout.prelude, 8),
            fun.call,
            fun.check,
            fun.name
        );
        e.test(&format!("golden_hex_{prefix}_{}", fun.name), false, &body)?;
        if let Some(cap) = panics {
            for (n, input) in spread(&failing, cap).into_iter().enumerate() {
                let line = format!(
                    "    let ({}): ({}) = ({});",
                    layout.vars,
                    layout.types,
                    (layout.row)(input)
                );
                // `scarb fmt` breaks a binding that exceeds 100 columns after the `(`
                let line = if line.len() > 100 {
                    format!(
                        "    let ({}): ({}) = (\n        {},\n    );",
                        layout.vars,
                        layout.types,
                        (layout.row)(input)
                    )
                } else {
                    line
                };
                let body = format!(
                    "{line}\n{}    let _ = {};\n",
                    indented(layout.prelude, 4),
                    fun.call
                );
                e.test(&format!("golden_hex_{prefix}_{}_panics_{n}", fun.name), true, &body)?;
            }
        }
    }
    Ok(())
}

const HEX_IN: Inputs<(i32, i32)> = Inputs {
    types: "i32, i32",
    vars: "x, y",
    prelude: "let h = HexTrait::new(x, y);\n",
    row: hex_row,
};

const PAIR_IN: Inputs<((i32, i32), (i32, i32))> = Inputs {
    types: "i32, i32, i32, i32",
    vars: "x1, y1, x2, y2",
    prelude: "let a = HexTrait::new(x1, y1);\nlet b = HexTrait::new(x2, y2);\n",
    row: pair_row,
};

const SCALAR_IN: Inputs<((i32, i32), i32)> = Inputs {
    types: "i32, i32, i32",
    vars: "x, y, k",
    prelude: "let h = HexTrait::new(x, y);\n",
    row: scalar_row,
};

const DIRECTION_IN: Inputs<((i32, i32), usize)> = Inputs {
    types: "i32, i32, u8",
    vars: "x, y, d",
    prelude: "let all = EdgeDirectionTrait::ALL_DIRECTIONS;
let direction = *all.span().at(d.into());
let h = HexTrait::new(x, y);
",
    row: direction_row,
};

const UNARY_L_M2: [Fun<(i32, i32)>; 6] = [
    Fun {
        name: "to_array",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.to_array()",
        check: "r == [ex, ey]",
        eval: |p| probe(|| h(p).to_array()).map(|a| vec![a[0].to_string(), a[1].to_string()]),
    },
    Fun {
        name: "to_cubic_array",
        types: "i32, i32, i32",
        vars: "ex, ey, ez",
        call: "h.to_cubic_array()",
        check: "r == [ex, ey, ez]",
        eval: |p| {
            probe(|| h(p).to_cubic_array())
                .map(|a| vec![a[0].to_string(), a[1].to_string(), a[2].to_string()])
        },
    },
    Fun {
        name: "const_neg",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.const_neg()",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p).const_neg()).map(pair),
    },
    Fun {
        name: "abs",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.abs()",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p).abs()).map(pair),
    },
    Fun {
        name: "signum",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.signum()",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p).signum()).map(pair),
    },
    Fun {
        name: "splat",
        types: "i32, i32",
        vars: "ex, ey",
        call: "HexTrait::splat(h.x)",
        check: "r == HexTrait::new(ex, ey) && HexTrait::from_array([x, y]) == h",
        eval: |p| probe(|| Hex::splat(p.0)).map(pair),
    },
];

const BINARY_L_M2: [Fun<((i32, i32), (i32, i32))>; 4] = [
    Fun {
        name: "const_add",
        types: "i32, i32",
        vars: "ex, ey",
        call: "a.const_add(b)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p.0).const_add(h(p.1))).map(pair),
    },
    Fun {
        name: "min",
        types: "i32, i32",
        vars: "ex, ey",
        call: "a.min(b)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p.0).min(h(p.1))).map(pair),
    },
    Fun {
        name: "max",
        types: "i32, i32",
        vars: "ex, ey",
        call: "a.max(b)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p.0).max(h(p.1))).map(pair),
    },
    Fun {
        name: "dot",
        types: "i32",
        vars: "e",
        call: "a.dot(b)",
        check: "r == e",
        eval: |p| probe(|| h(p.0).dot(h(p.1))).map(one),
    },
];

const SCALAR_L_M2: [Fun<((i32, i32), i32)>; 1] = [Fun {
    name: "mul_scalar",
    types: "i32, i32",
    vars: "ex, ey",
    call: "h.mul_scalar(k)",
    check: "r == HexTrait::new(ex, ey)",
    // `impl Mul<i32> for Hex` (`src/hex/impls.rs:174`)
    eval: |p| probe(|| h(p.0) * p.1).map(pair),
}];

const DIRECTION_L_M2: [Fun<((i32, i32), usize)>; 2] = [
    Fun {
        name: "neighbor",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.neighbor(direction)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p.0).neighbor(EdgeDirection::ALL_DIRECTIONS[p.1])).map(pair),
    },
    Fun {
        name: "add_dir",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.add_dir(direction)",
        check: "r == HexTrait::new(ex, ey)",
        // `pub(crate)` in `hexx`: its public form is the `Add<EdgeDirection>` operator
        eval: |p| probe(|| h(p.0) + EdgeDirection::ALL_DIRECTIONS[p.1]).map(pair),
    },
];

/// The pairs of the cubic triples near the bounds.
fn cubic_triples() -> Vec<(i32, i32, i32)> {
    let mut triples = Vec::new();
    for &x in &crate::cairo::BOUND_VALUES {
        for &y in &crate::cairo::BOUND_VALUES {
            for &z in &crate::cairo::BOUND_VALUES {
                triples.push((x, y, z));
            }
        }
    }
    triples
}

/// The largest `range` for which `f` does not panic (`f` is monotone: once it panics it does for
/// every larger `range`), by bisection.
fn last_ok(f: impl Fn(u32) -> Option<u64>) -> u32 {
    let (mut lo, mut hi) = (0u32, u32::MAX);
    if f(hi).is_some() {
        return hi;
    }
    while lo + 1 < hi {
        let mid = lo + (hi - lo) / 2;
        if f(mid).is_some() {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    lo
}

/// `range_count`, `ring_count` and `wedge_count` of `range`, `None` when `hexx` panics, or when
/// the result does not fit `u32` (`ring_count` returns a `usize`, and this port a `u32`).
fn counts(name: &str, range: u32) -> Option<u64> {
    match name {
        "range_count" => probe(|| u64::from(Hex::range_count(range))),
        "ring_count" => probe(|| Hex::ring_count(range) as u64).filter(|&v| v <= u64::from(u32::MAX)),
        _ => probe(|| u64::from(Hex::wedge_count(range))),
    }
}

fn count_tests(e: &mut Emitter) -> Result<(), String> {
    for name in ["range_count", "ring_count", "wedge_count"] {
        let edge = last_ok(|r| counts(name, r));
        let mut ranges: Vec<u32> = (0..=64).collect();
        ranges.extend([edge - 1, edge, edge.saturating_add(1), u32::MAX]);
        ranges.sort_unstable();
        ranges.dedup();
        let (ok, failing): (Vec<u32>, Vec<u32>) =
            ranges.into_iter().partition(|&r| counts(name, r).is_some());
        let rows: Vec<String> =
            ok.iter().map(|&r| format!("{r}, {}", counts(name, r).unwrap_or(0))).collect();
        let body = format!(
            "{}    let mut i = 0;
    while i < cases.len() {{
        let (range, expected) = *cases.at(i);
        assert(HexTrait::{name}(range) == expected, '{name}');
        i += 1;
    }}
",
            cases_array("u32, u32", &rows)
        );
        e.test(&format!("golden_hex_{name}"), false, &body)?;
        for (n, range) in failing.into_iter().take(2).enumerate() {
            let body = format!("    let _ = HexTrait::{name}({range});\n");
            e.test(&format!("golden_hex_{name}_panics_{n}"), true, &body)?;
        }
    }
    Ok(())
}

/// The items of M2-T0.
fn emit_l_m2(
    e: &mut Emitter,
    points: &[(i32, i32)],
    chunks: usize,
    panic_cap: usize,
) -> Result<(), String> {
    // The constants, from `hexx` itself.
    let consts: [(&str, Hex); 7] = [
        ("ORIGIN", Hex::ORIGIN),
        ("ONE", Hex::ONE),
        ("NEG_ONE", Hex::NEG_ONE),
        ("X", Hex::X),
        ("NEG_X", Hex::NEG_X),
        ("Y", Hex::Y),
        ("NEG_Y", Hex::NEG_Y),
    ];
    let arrays: [(&str, &[Hex]); 7] = [
        ("INCR_X", &Hex::INCR_X),
        ("INCR_Y", &Hex::INCR_Y),
        ("INCR_Z", &Hex::INCR_Z),
        ("DECR_X", &Hex::DECR_X),
        ("DECR_Y", &Hex::DECR_Y),
        ("DECR_Z", &Hex::DECR_Z),
        ("DIAGONAL_COORDS", &Hex::DIAGONAL_COORDS),
    ];
    let mut body = String::new();
    for (name, c) in consts {
        body.push_str(&format!(
            "    assert(HexTrait::{name} == HexTrait::new({}, {}), '{name}');\n",
            c.x, c.y
        ));
    }
    for (name, list) in arrays {
        body.push_str(&format!("    let {} = HexTrait::{name};\n", name.to_lowercase()));
        body.push_str(&format!("    let {0} = {0}.span();\n", name.to_lowercase()));
        body.push_str(&format!(
            "    assert({}.len() == {}, '{name} len');\n",
            name.to_lowercase(),
            list.len()
        ));
        for (i, c) in list.iter().enumerate() {
            body.push_str(&format!(
                "    assert(*{}.at({i}) == HexTrait::new({}, {}), '{name} {i}');\n",
                name.to_lowercase(),
                c.x,
                c.y
            ));
        }
    }
    for d in 0..6 {
        let c = Hex::neighbor_coord(EdgeDirection::ALL_DIRECTIONS[d]);
        body.push_str(&format!(
            "    let all = EdgeDirectionTrait::ALL_DIRECTIONS;
    let direction = *all.span().at({d});
    assert(HexTrait::neighbor_coord(direction) == HexTrait::new({}, {}), 'neighbor_coord {d}');\n",
            c.x, c.y
        ));
    }
    body.push_str(&format!(
        "    assert(hex(3, -5) == HexTrait::new({}, {}), 'hex');\n",
        hexx::hex(3, -5).x,
        hexx::hex(3, -5).y
    ));
    e.test("golden_hex_constants_l_m2", false, &body)?;

    // `new_cubic`: the valid triples of the seeded points, then the triples near the bounds.
    let rows: Vec<String> = points.iter().map(|&(x, y)| {
        let c = Hex::new_cubic(x, y, -x - y);
        format!("{}, {}, {}", c.x, c.y, -x - y)
    }).collect();
    let body = format!(
        "{}    let mut i = 0;
    while i < cases.len() {{
        let (x, y, z) = *cases.at(i);
        assert(HexTrait::new_cubic(x, y, z) == HexTrait::new(x, y), 'new_cubic');
        i += 1;
    }}
",
        cases_array("i32, i32, i32", &rows)
    );
    e.test("golden_hex_new_cubic", false, &body)?;
    let triples = cubic_triples();
    let (valid, failing): (Vec<_>, Vec<_>) =
        triples.iter().partition(|&&(x, y, z)| probe(|| Hex::new_cubic(x, y, z)).is_some());
    let rows: Vec<String> = valid.iter().map(|(x, y, z)| format!("{x}, {y}, {z}")).collect();
    let body = format!(
        "{}    let mut i = 0;
    while i < cases.len() {{
        let (x, y, z) = *cases.at(i);
        assert(HexTrait::new_cubic(x, y, z) == HexTrait::new(x, y), 'new_cubic');
        i += 1;
    }}
",
        cases_array("i32, i32, i32", &rows)
    );
    e.test("golden_hex_bounds_new_cubic", false, &body)?;
    // The sum is not zero, and the sum itself leaves `i32`: both panic in `hexx`.
    for (n, (x, y, z)) in spread(&failing, panic_cap).into_iter().enumerate() {
        let body = format!("    let _ = HexTrait::new_cubic({x}, {y}, {z});\n");
        e.test(&format!("golden_hex_new_cubic_panics_{n}"), true, &body)?;
    }

    // The unary items on the seeded points, then near the bounds.
    tables(e, "unary", points, &HEX_IN, &UNARY_L_M2, None)?;
    let bounds = bound_points();
    tables(e, "bounds", &bounds, &HEX_IN, &UNARY_L_M2, Some(panic_cap))?;

    // The binary items on every ordered pair of the seeded points, in `chunks` tests, then on the
    // pairs near the bounds.
    let per_chunk = points.len() / chunks;
    for chunk in 0..chunks {
        let pairs: Vec<_> = points[chunk * per_chunk..(chunk + 1) * per_chunk]
            .iter()
            .flat_map(|&a| points.iter().map(move |&b| (a, b)))
            .collect();
        tables(e, &format!("pairs_{chunk}"), &pairs, &PAIR_IN, &BINARY_L_M2, None)?;
    }
    let bound_pairs: Vec<_> = BOUND_PAIR_POINTS
        .iter()
        .flat_map(|&a| BOUND_PAIR_POINTS.iter().map(move |&b| (a, b)))
        .collect();
    tables(e, "bounds_pairs", &bound_pairs, &PAIR_IN, &BINARY_L_M2, Some(panic_cap))?;

    // `mul_scalar`: every point by the abscissa of the points of a stride, then near the bounds.
    let scalars: Vec<((i32, i32), i32)> = points
        .iter()
        .flat_map(|&p| points.iter().step_by(8).map(move |&q| (p, q.0)))
        .collect();
    tables(e, "scalar", &scalars, &SCALAR_IN, &SCALAR_L_M2, None)?;
    let bound_scalars: Vec<((i32, i32), i32)> = BOUND_PAIR_POINTS
        .iter()
        .flat_map(|&p| crate::cairo::BOUND_VALUES.iter().map(move |&k| (p, k)))
        .collect();
    tables(e, "bounds_scalar", &bound_scalars, &SCALAR_IN, &SCALAR_L_M2, Some(panic_cap))?;

    // The neighbours: the six directions of every point, then near the bounds.
    let directions: Vec<((i32, i32), usize)> =
        points.iter().flat_map(|&p| (0..6).map(move |d| (p, d))).collect();
    tables(e, "direction", &directions, &DIRECTION_IN, &DIRECTION_L_M2, None)?;
    let bound_directions: Vec<((i32, i32), usize)> =
        bounds.iter().flat_map(|&p| (0..6).map(move |d| (p, d))).collect();
    tables(e, "bounds_direction", &bound_directions, &DIRECTION_IN, &DIRECTION_L_M2, Some(panic_cap))?;

    // `all_neighbors`: the six neighbours as one array, on the seeded points and near the bounds.
    let all = |p: (i32, i32)| probe(|| h(p).all_neighbors());
    for (prefix, inputs, cap) in [("unary", points.to_vec(), None), ("bounds", bounds.clone(), Some(panic_cap))] {
        let mut rows = Vec::new();
        let mut failing = Vec::new();
        for &p in &inputs {
            match all(p) {
                Some(n) => rows.push(format!(
                    "{}, {}, {}",
                    p.0,
                    p.1,
                    n.iter().map(|c| format!("{}, {}", c.x, c.y)).collect::<Vec<_>>().join(", ")
                )),
                None if cap.is_some() => failing.push(p),
                None => return Err("hexx panics inside the seeded domain: all_neighbors".into()),
            }
        }
        let body = format!(
            "{}    let mut i = 0;
    while i < cases.len() {{
        let (x, y, x0, y0, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5) = *cases.at(i);
        let r = HexTrait::new(x, y).all_neighbors();
        let expected = [
            HexTrait::new(x0, y0), HexTrait::new(x1, y1), HexTrait::new(x2, y2),
            HexTrait::new(x3, y3), HexTrait::new(x4, y4), HexTrait::new(x5, y5),
        ];
        assert(r == expected, 'all_neighbors');
        i += 1;
    }}
",
            cases_array("i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32", &rows)
        );
        e.test(&format!("golden_hex_{prefix}_all_neighbors"), false, &body)?;
        if let Some(cap) = cap {
            for (n, p) in spread(&failing, cap).into_iter().enumerate() {
                let body = format!(
                    "    let _ = HexTrait::new({}, {}).all_neighbors();\n",
                    p.0, p.1
                );
                e.test(&format!("golden_hex_{prefix}_all_neighbors_panics_{n}"), true, &body)?;
            }
        }
    }

    count_tests(e)
}

// ---- M2-T2: the rest of `HexTrait` ----

/// The rotation counts of the vectors: `0..=12` and the largest `u32` that fits a `u8`.
const ROTATIONS: [u32; 14] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 255];

/// `2^24`: below it, every integer is exact in `f32`.
const F32_EXACT: i64 = 1 << 24;

const VERTEX_DIRECTION_IN: Inputs<((i32, i32), usize)> = Inputs {
    types: "i32, i32, u8",
    vars: "x, y, d",
    prelude: "let all = VertexDirectionTrait::ALL_DIRECTIONS;
let direction = *all.span().at(d.into());
let h = HexTrait::new(x, y);
",
    row: direction_row,
};

/// A point and a neighbour direction `k` in `0..6`, or `6` for the one non-neighbour `(x + 2, y)`.
const OTHER_IN: Inputs<((i32, i32), usize)> = Inputs {
    types: "i32, i32, u8",
    vars: "x, y, k",
    prelude: "let h = HexTrait::new(x, y);
let all = EdgeDirectionTrait::ALL_DIRECTIONS;
let other = if k < 6 {
    h.neighbor(*all.span().at(k.into()))
} else {
    HexTrait::new(x + 2, y)
};
",
    row: direction_row,
};

const ROTATION_IN: Inputs<((i32, i32), u32)> = Inputs {
    types: "i32, i32, u32",
    vars: "x, y, m",
    prelude: "let h = HexTrait::new(x, y);\n",
    row: scalar_u32_row,
};

const RADIUS_IN: Inputs<((i32, i32), u32)> = Inputs {
    types: "i32, i32, u32",
    vars: "x, y, radius",
    prelude: "let h = HexTrait::new(x, y);\n",
    row: scalar_u32_row,
};

type Around = (((i32, i32), (i32, i32)), u32);

const AROUND_IN: Inputs<Around> = Inputs {
    types: "i32, i32, i32, i32, u32",
    vars: "x1, y1, x2, y2, m",
    prelude: "let a = HexTrait::new(x1, y1);\nlet b = HexTrait::new(x2, y2);\n",
    row: around_row,
};

fn scalar_u32_row(p: ((i32, i32), u32)) -> String {
    format!("{}, {}, {}", (p.0).0, (p.0).1, p.1)
}

fn around_row(p: Around) -> String {
    format!("{}, {}", pair_row(p.0), p.1)
}

fn vh(p: (i32, i32)) -> Hex {
    Hex::new(p.0, p.1)
}

/// `(kind, first, second)` of a way: `Single(d)` is `(0, d, d)`, `Tie([a, b])` is `(1, a, b)`.
fn way_row<T: Copy>(way: DirectionWay<T>, index: impl Fn(T) -> u8) -> Vec<String> {
    match way {
        DirectionWay::Single(d) => vec!["0".into(), index(d).to_string(), index(d).to_string()],
        DirectionWay::Tie([a, b]) => vec!["1".into(), index(a).to_string(), index(b).to_string()],
    }
}

/// `(length, hash)` of a path: the polynomial hash the Cairo helper `PathDigestTrait::digest` computes.
fn path_digest(path: impl Iterator<Item = Hex>) -> Vec<String> {
    let (mut len, mut hash) = (0u32, 0u64);
    for p in path {
        let ux = (i64::from(p.x) + 2_147_483_648) as u64;
        let uy = (i64::from(p.y) + 2_147_483_648) as u64;
        hash = (hash * 1_000_003 + ux * 65_537 + uy) % 1_000_000_007;
        len += 1;
    }
    vec![len.to_string(), hash.to_string()]
}

const WAY_TYPES: &str = "u8, u8, u8";
const WAY_VARS: &str = "ek, e0, e1";

/// The helpers of the generated file: the shape of a way and the digest of a path, in traits
/// (D-143: a table of helpers, not free functions).
const T2_USES: &str = "
/// `(kind, first, second)` of a way: `Single(d)` is `(0, d, d)`, `Tie([a, b])` is `(1, a, b)`.
#[generate_trait]
impl WayShape of WayShapeTrait {
    fn edge(way: DirectionWay<EdgeDirection>) -> (u8, u8, u8) {
        match way {
            DirectionWay::Single(d) => (0, d.index(), d.index()),
            DirectionWay::Tie(pair) => {
                let [a, b] = pair;
                (1, a.index(), b.index())
            },
        }
    }

    fn neighbor(direction: Option<EdgeDirection>) -> u8 {
        match direction {
            Some(d) => d.index(),
            None => 255,
        }
    }

    fn vertex(way: DirectionWay<VertexDirection>) -> (u8, u8, u8) {
        match way {
            DirectionWay::Single(d) => (0, d.index(), d.index()),
            DirectionWay::Tie(pair) => {
                let [a, b] = pair;
                (1, a.index(), b.index())
            },
        }
    }
}

/// `(length, polynomial hash modulo 1_000_000_007)` of a path, computed as `refgen` does.
#[generate_trait]
impl PathDigest of PathDigestTrait {
    fn digest(path: Span<Hex>) -> (u32, u32) {
        let mut hash: u64 = 0;
        let mut i = 0;
        while i != path.len() {
            let p = *path.at(i);
            let x: i64 = p.x.into();
            let y: i64 = p.y.into();
            let ux: u64 = (x + 2147483648).try_into().unwrap();
            let uy: u64 = (y + 2147483648).try_into().unwrap();
            hash = (hash * 1000003 + ux * 65537 + uy) % 1000000007;
            i += 1;
        }
        (path.len(), hash.try_into().unwrap())
    }
}
";

const UNARY_T2: [Fun<(i32, i32)>; 5] = [
    Fun {
        name: "counter_clockwise",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.counter_clockwise()",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p).counter_clockwise()).map(pair),
    },
    Fun {
        name: "clockwise",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.clockwise()",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p).clockwise()).map(pair),
    },
    Fun {
        name: "reflect_x",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.reflect_x()",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p).reflect_x()).map(pair),
    },
    Fun {
        name: "reflect_y",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.reflect_y()",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p).reflect_y()).map(pair),
    },
    Fun {
        name: "reflect_z",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.reflect_z()",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p).reflect_z()).map(pair),
    },
];

const PAIR_T2: [Fun<((i32, i32), (i32, i32))>; 6] = [
    Fun {
        name: "way_to",
        types: WAY_TYPES,
        vars: WAY_VARS,
        call: "WayShapeTrait::edge(a.way_to(b))",
        check: "r == (ek, e0, e1)",
        eval: |p| {
            probe(|| way_row(h(p.0).way_to(h(p.1)), |d| d.index()))
        },
    },
    Fun {
        name: "main_direction_to",
        types: "u8",
        vars: "e",
        call: "a.main_direction_to(b).index()",
        check: "r == e",
        eval: |p| probe(|| h(p.0).main_direction_to(h(p.1)).index()).map(one),
    },
    Fun {
        name: "diagonal_way_to",
        types: WAY_TYPES,
        vars: WAY_VARS,
        call: "WayShapeTrait::vertex(a.diagonal_way_to(b))",
        check: "r == (ek, e0, e1)",
        eval: |p| {
            probe(|| way_row(h(p.0).diagonal_way_to(h(p.1)), |d| d.index()))
        },
    },
    Fun {
        name: "main_diagonal_to",
        types: "u8",
        vars: "e",
        call: "a.main_diagonal_to(b).index()",
        check: "r == e",
        eval: |p| probe(|| h(p.0).main_diagonal_to(h(p.1)).index()).map(one),
    },
    Fun {
        name: "ccw_around",
        types: "i32, i32",
        vars: "ex, ey",
        call: "a.ccw_around(b)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p.0).ccw_around(h(p.1))).map(pair),
    },
    Fun {
        name: "cw_around",
        types: "i32, i32",
        vars: "ex, ey",
        call: "a.cw_around(b)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p.0).cw_around(h(p.1))).map(pair),
    },
];

/// `rectiline_to` in both senses, as the digest of its path.
const RECTILINE_T2: [Fun<((i32, i32), (i32, i32))>; 2] = [
    Fun {
        name: "rectiline_to_cw",
        types: "u32, u32",
        vars: "len, hash",
        call: "PathDigestTrait::digest(a.rectiline_to(b, true))",
        check: "r == (len, hash)",
        eval: |p| probe(|| path_digest(h(p.0).rectiline_to(h(p.1), true))),
    },
    Fun {
        name: "rectiline_to_ccw",
        types: "u32, u32",
        vars: "len, hash",
        call: "PathDigestTrait::digest(a.rectiline_to(b, false))",
        check: "r == (len, hash)",
        eval: |p| probe(|| path_digest(h(p.0).rectiline_to(h(p.1), false))),
    },
];

const VERTEX_T2: [Fun<((i32, i32), usize)>; 2] = [
    Fun {
        name: "diagonal_neighbor",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.diagonal_neighbor(direction)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| {
            probe(|| h(p.0).diagonal_neighbor(VertexDirection::ALL_DIRECTIONS[p.1])).map(pair)
        },
    },
    Fun {
        name: "add_diag_dir",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.add_diag_dir(direction)",
        check: "r == HexTrait::new(ex, ey)",
        // `pub(crate)` in `hexx`: its public form is the `Add<VertexDirection>` operator
        eval: |p| probe(|| h(p.0) + VertexDirection::ALL_DIRECTIONS[p.1]).map(pair),
    },
];

const OTHER_T2: [Fun<((i32, i32), usize)>; 1] = [Fun {
    name: "neighbor_direction",
    types: "u8",
    vars: "e",
    // 255 stands for `None`
    call: "WayShapeTrait::neighbor(h.neighbor_direction(other))",
    check: "r == e",
    eval: |p| {
        probe(|| {
            let other = if p.1 < 6 {
                h(p.0).neighbor(EdgeDirection::ALL_DIRECTIONS[p.1])
            } else {
                Hex::new(p.0 .0 + 2, p.0 .1)
            };
            h(p.0).neighbor_direction(other).map_or(255, |d| d.index())
        })
        .map(one)
    },
}];

const ROTATION_T2: [Fun<((i32, i32), u32)>; 2] = [
    Fun {
        name: "rotate_cw",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.rotate_cw(m)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p.0).rotate_cw(p.1)).map(pair),
    },
    Fun {
        name: "rotate_ccw",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.rotate_ccw(m)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p.0).rotate_ccw(p.1)).map(pair),
    },
];

const AROUND_T2: [Fun<Around>; 2] = [
    Fun {
        name: "rotate_cw_around",
        types: "i32, i32",
        vars: "ex, ey",
        call: "a.rotate_cw_around(b, m)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h((p.0).0).rotate_cw_around(h((p.0).1), p.1)).map(pair),
    },
    Fun {
        name: "rotate_ccw_around",
        types: "i32, i32",
        vars: "ex, ey",
        call: "a.rotate_ccw_around(b, m)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h((p.0).0).rotate_ccw_around(h((p.0).1), p.1)).map(pair),
    },
];

const HIGHER_T2: [Fun<((i32, i32), u32)>; 1] = [Fun {
    name: "to_higher_res",
    types: "i32, i32",
    vars: "ex, ey",
    call: "h.to_higher_res(radius)",
    check: "r == HexTrait::new(ex, ey)",
    eval: |p| probe(|| h(p.0).to_higher_res(p.1)).map(pair),
}];

const LOWER_T2: [Fun<((i32, i32), u32)>; 3] = [
    Fun {
        name: "to_lower_res",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.to_lower_res(radius)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p.0).to_lower_res(p.1)).map(pair),
    },
    Fun {
        name: "to_local",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.to_local(radius)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p.0).to_local(p.1)).map(pair),
    },
    Fun {
        name: "wrap_in_range",
        types: "i32, i32",
        vars: "ex, ey",
        call: "h.wrap_in_range(radius)",
        check: "r == HexTrait::new(ex, ey)",
        eval: |p| probe(|| h(p.0).wrap_in_range(p.1)).map(pair),
    },
];

/// Whether `to_lower_res` is exact in `f32` on `p` at `radius`: every operand converted to `f32` is
/// below `2^24` in magnitude, so that `hexx`'s floor is the exact one. Computed in `i64`.
fn lower_res_exact(p: (i32, i32), radius: u32) -> bool {
    let (x, y) = (i64::from(p.0), i64::from(p.1));
    let z = -x - y;
    let r = i64::from(radius);
    let (area, shift) = (3 * r * (r + 1) + 1, 3 * r + 2);
    let n = [y + shift * x, z + shift * y, x + shift * z];
    if area >= F32_EXACT || n.iter().any(|v| v.abs() >= F32_EXACT) {
        return false;
    }
    let q = n.map(|v| v.div_euclid(area));
    [1 + q[0] - q[1], 1 + q[1] - q[2]].iter().all(|v| v.abs() < F32_EXACT)
}

/// The largest numerator of `to_lower_res` at `p`, `radius`: how far from zero the `f32` operands go.
fn lower_res_magnitude(p: (i32, i32), radius: u32) -> i64 {
    let (x, y) = (i64::from(p.0), i64::from(p.1));
    let z = -x - y;
    let shift = 3 * i64::from(radius) + 2;
    [y + shift * x, z + shift * y, x + shift * z].iter().map(|v| v.abs()).max().unwrap_or(0)
}

/// `all_diagonals` of a point: its six diagonal neighbours, as one array.
fn all_diagonals_test(
    e: &mut Emitter,
    prefix: &str,
    inputs: &[(i32, i32)],
    cap: Option<usize>,
) -> Result<(), String> {
    let mut rows = Vec::new();
    let mut failing = Vec::new();
    for &p in inputs {
        match probe(|| h(p).all_diagonals()) {
            Some(n) => rows.push(format!(
                "{}, {}, {}",
                p.0,
                p.1,
                n.iter().map(|c| format!("{}, {}", c.x, c.y)).collect::<Vec<_>>().join(", ")
            )),
            None if cap.is_some() => failing.push(p),
            None => return Err("hexx panics inside the seeded domain: all_diagonals".into()),
        }
    }
    let body = format!(
        "{}    let mut i = 0;
    while i < cases.len() {{
        let (x, y, x0, y0, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5) = *cases.at(i);
        let r = HexTrait::new(x, y).all_diagonals();
        let expected = [
            HexTrait::new(x0, y0), HexTrait::new(x1, y1), HexTrait::new(x2, y2),
            HexTrait::new(x3, y3), HexTrait::new(x4, y4), HexTrait::new(x5, y5),
        ];
        assert(r == expected, 'all_diagonals');
        i += 1;
    }}
",
        cases_array("i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32", &rows)
    );
    e.test(&format!("golden_hex_{prefix}_all_diagonals"), false, &body)?;
    if let Some(cap) = cap {
        for (n, p) in spread(&failing, cap).into_iter().enumerate() {
            let body =
                format!("    let _ = HexTrait::new({}, {}).all_diagonals();\n", p.0, p.1);
            e.test(&format!("golden_hex_{prefix}_all_diagonals_panics_{n}"), true, &body)?;
        }
    }
    Ok(())
}

/// `range` and `xrange`: for 8 centres and radii `0..=6`, the spans compared element by element, in
/// the order of `hexx`.
fn range_tests(e: &mut Emitter, points: &[(i32, i32)]) -> Result<(), String> {
    let centers: Vec<(i32, i32)> = points.iter().step_by(points.len() / 8).copied().take(8).collect();
    for (name, exclude) in [("range", false), ("xrange", true)] {
        let mut cases = Vec::new();
        let mut flat = Vec::new();
        for &c in &centers {
            for radius in 0..=6u32 {
                cases.push(format!("{}, {}, {}", c.0, c.1, radius));
                let span: Vec<Hex> = if exclude {
                    h(c).xrange(radius).collect()
                } else {
                    h(c).range(radius).collect()
                };
                flat.extend(span.iter().map(|s| format!("{}, {}", s.x, s.y)));
            }
        }
        let body = format!(
            "{}{}    let mut at = 0;
    let mut i = 0;
    while i < cases.len() {{
        let (x, y, r) = *cases.at(i);
        let span = HexTrait::new(x, y).{name}(r);
        let mut j = 0;
        while j < span.len() {{
            let (ex, ey) = *expected.at(at + j);
            assert(*span.at(j) == HexTrait::new(ex, ey), '{name}');
            j += 1;
        }}
        at += span.len();
        i += 1;
    }}
    assert(at == expected.len(), '{name} len');
",
            cases_array("i32, i32, u32", &cases),
            cases_array("i32, i32", &flat).replace("let cases", "let expected"),
        );
        e.test(&format!("golden_hex_{name}"), false, &body)?;
    }
    Ok(())
}

/// The items of M2-T2.
fn emit_t2(
    e: &mut Emitter,
    points: &[(i32, i32)],
    panic_cap: usize,
) -> Result<(), String> {
    // Every second point of the 121 bound points (the extremes included): the tables near the
    // bounds of the new items are halved for the compile size of the integration target.
    let bounds: Vec<(i32, i32)> = bound_points().into_iter().step_by(2).collect();

    // The unary items: seeded points, then near the bounds.
    tables(e, "unary_t2", points, &HEX_IN, &UNARY_T2, None)?;
    tables(e, "bounds_t2", &bounds, &HEX_IN, &UNARY_T2, Some(panic_cap))?;
    all_diagonals_test(e, "unary", points, None)?;
    all_diagonals_test(e, "bounds", &bounds, Some(panic_cap))?;

    // The binary items on every ordered pair of a 16-point subset (every fourth seeded point), in
    // one test per function, then near the bounds. The 64 x 64 pairs of the first version made the
    // integration target too large for the CI runner's compile (41,000 lines): the exhaustive
    // checks are the module oracles of `range`, the rotations and the counts only; `way_to`,
    // `diagonal_way_to`, `main_diagonal_to`, `main_direction_to`, `rectiline_to` and the
    // `*_around` items rest on the property tests and on this golden subset. `rectiline_to` has
    // none near the bounds: a path of two billion hexes.
    let subset: Vec<(i32, i32)> = points.iter().step_by(4).copied().collect();
    let mut pairs: Vec<_> =
        subset.iter().flat_map(|&a| subset.iter().map(move |&b| (a, b))).collect();
    // Hand-picked: the origin to each of the six vertex hexes and back, so that all six tie
    // orders of `way_to` are pinned against `hexx` (the seeded points hit few of them).
    for v in [(1, 1), (-1, -1), (2, -1), (-2, 1), (1, -2), (-1, 2)] {
        for pair in [((0, 0), v), (v, (0, 0))] {
            if !pairs.contains(&pair) {
                pairs.push(pair);
            }
        }
    }
    tables(e, "pairs_t2", &pairs, &PAIR_IN, &PAIR_T2, None)?;
    tables(e, "pairs_t2", &pairs, &PAIR_IN, &RECTILINE_T2, None)?;
    let bound_pairs: Vec<_> = BOUND_PAIR_POINTS
        .iter()
        .flat_map(|&a| BOUND_PAIR_POINTS.iter().map(move |&b| (a, b)))
        .collect();
    tables(e, "bounds_pairs", &bound_pairs, &PAIR_IN, &PAIR_T2, Some(panic_cap))?;

    // The diagonal neighbours: the six vertex directions of every point, then near the bounds.
    let diagonals: Vec<((i32, i32), usize)> =
        points.iter().flat_map(|&p| (0..6).map(move |d| (p, d))).collect();
    tables(e, "diagonal", &diagonals, &VERTEX_DIRECTION_IN, &VERTEX_T2, None)?;
    let bound_diagonals: Vec<((i32, i32), usize)> =
        bounds.iter().flat_map(|&p| (0..6).map(move |d| (p, d))).collect();
    tables(
        e,
        "bounds_diagonal",
        &bound_diagonals,
        &VERTEX_DIRECTION_IN,
        &VERTEX_T2,
        Some(panic_cap),
    )?;
    let mut body = String::new();
    for d in 0..6 {
        let c = Hex::diagonal_neighbor_coord(VertexDirection::ALL_DIRECTIONS[d]);
        body.push_str(&format!(
            "    let all = VertexDirectionTrait::ALL_DIRECTIONS;
    let direction = *all.span().at({d});
    assert(
        HexTrait::diagonal_neighbor_coord(direction) == HexTrait::new({}, {}),
        'diagonal_neighbor_coord {d}',
    );\n",
            c.x, c.y
        ));
    }
    e.test("golden_hex_diagonal_neighbor_coord", false, &body)?;

    // `neighbor_direction` against each neighbour and one non-neighbour, then near the bounds.
    let others: Vec<((i32, i32), usize)> =
        points.iter().flat_map(|&p| (0..7).map(move |k| (p, k))).collect();
    tables(e, "other", &others, &OTHER_IN, &OTHER_T2, None)?;
    let bound_others: Vec<((i32, i32), usize)> = bounds
        .iter()
        .flat_map(|&p| (0..7).map(move |k| (p, k)))
        .filter(|&(p, k)| k < 6 || probe(|| Hex::new(p.0 + 2, p.1)).is_some())
        .collect();
    tables(e, "bounds_other", &bound_others, &OTHER_IN, &OTHER_T2, Some(panic_cap))?;

    // The rotations at `m` in `0..=12` and 255, then near the bounds.
    let rotations: Vec<((i32, i32), u32)> =
        points.iter().flat_map(|&p| ROTATIONS.iter().map(move |&m| (p, m))).collect();
    tables(e, "rotation", &rotations, &ROTATION_IN, &ROTATION_T2, None)?;
    let bound_rotations: Vec<((i32, i32), u32)> =
        bounds.iter().flat_map(|&p| [1u32, 3, 4].into_iter().map(move |m| (p, m))).collect();
    tables(e, "bounds_rotation", &bound_rotations, &ROTATION_IN, &ROTATION_T2, Some(panic_cap))?;

    // The rotations around a center: the 16-point subset around 4 centres, in 2 tests.
    let centers: Vec<(i32, i32)> = points.iter().step_by(16).copied().collect();
    let arounds: Vec<Around> = subset
        .iter()
        .flat_map(|&p| {
            centers.iter().flat_map(move |&c| ROTATIONS.iter().map(move |&m| ((p, c), m)))
        })
        .collect();
    for (n, part) in arounds.chunks(arounds.len() / 2).enumerate() {
        tables(e, &format!("around_{n}"), part, &AROUND_IN, &AROUND_T2, None)?;
    }
    let bound_arounds: Vec<Around> = BOUND_PAIR_POINTS
        .iter()
        .flat_map(|&a| {
            BOUND_PAIR_POINTS
                .iter()
                .flat_map(move |&c| [1u32, 4].into_iter().map(move |m| ((a, c), m)))
        })
        .collect();
    tables(e, "bounds_around", &bound_arounds, &AROUND_IN, &AROUND_T2, Some(panic_cap))?;

    // The resolutions at radii `1..=6`; a seeded sample of points whose operands are between
    // `2^22` and `2^24`, where `hexx` is still exact; and near the bounds, where it panics.
    let radii: Vec<((i32, i32), u32)> =
        points.iter().flat_map(|&p| (1..=6).map(move |r| (p, r))).collect();
    tables(e, "resolution", &radii, &RADIUS_IN, &LOWER_T2, None)?;
    tables(e, "resolution", &radii, &RADIUS_IN, &HIGHER_T2, None)?;
    let mut rng = crate::cairo::Rng::new("hex::big");
    let mut big: Vec<((i32, i32), u32)> = Vec::new();
    for radius in 1..=6u32 {
        let shift = 3 * i64::from(radius) + 2;
        let limit = (F32_EXACT / (shift + 2)) as i32;
        let mut kept = 0;
        while kept < 16 {
            let p = (rng.next_i32(-limit, limit), rng.next_i32(-limit, limit));
            let magnitude = lower_res_magnitude(p, radius);
            if lower_res_exact(p, radius) && magnitude >= 1 << 22 {
                big.push((p, radius));
                kept += 1;
            }
        }
    }
    tables(e, "big", &big, &RADIUS_IN, &LOWER_T2, None)?;
    tables(e, "big", &big, &RADIUS_IN, &HIGHER_T2, None)?;
    // Near the bounds: `hexx`'s answer is its `f32` one where it returns beyond `2^24` (not this
    // port's exact floor, see the deviation): those cases have no vector, the ones where `hexx`
    // panics keep their `#[should_panic]`.
    let bound_radii: Vec<((i32, i32), u32)> =
        bounds.iter().flat_map(|&p| [1u32, 6].into_iter().map(move |r| (p, r))).collect();
    let kept: Vec<((i32, i32), u32)> = bound_radii
        .iter()
        .copied()
        .filter(|&(p, r)| probe(|| vh(p).to_lower_res(r)).is_none() || lower_res_exact(p, r))
        .collect();
    tables(e, "bounds_resolution", &kept, &RADIUS_IN, &LOWER_T2, Some(panic_cap))?;
    tables(e, "bounds_resolution", &bound_radii, &RADIUS_IN, &HIGHER_T2, Some(panic_cap))?;

    // `range` and `xrange`.
    range_tests(e, points)?;

    // `Debug`: the string of `hexx` for the seeded points.
    let mut body = String::new();
    for &p in points {
        body.push_str(&format!(
            "    assert!(format!(\"{{:?}}\", HexTrait::new({}, {})) == \"{:?}\");\n",
            p.0,
            p.1,
            h(p)
        ));
    }
    e.test("golden_hex_debug", false, &body)?;
    Ok(())
}

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
        "`Hex` (src/hex/mod.rs:69), `new` :208, `x` :256, `y` :264, `z` :274,\n// `const_sub` :449, `length` :568, `ulength` :594, `distance_to` :615, `unsigned_distance_to` :625;\n// and the items of M2-T0: the constants :95-186, `hex` :89, `splat` :225, `new_cubic` :247,\n// `from_array` :290, `to_array` :307, `to_cubic_array` :333, `const_neg` :421, `const_add` :435,\n// `abs` :498, `min` :511, `max` :525, `dot` :535, `signum` :546, `neighbor_coord` :633,\n// `add_dir` :645, `neighbor` :665, `all_neighbors` :760, `range_count` :1160, `ring_count`\n// (rings.rs:540), `wedge_count` (rings.rs:285), `Mul<i32>` (impls.rs:174)",
        "use hexx::direction::edge_direction::EdgeDirectionTrait;\nuse hexx::hex::{Hex, HexTrait, hex};\n",
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
    emit_l_m2(&mut e, &points, spec.int("ops_chunks")? as usize, panic_cap)?;
    e.finish()
}

/// The generated file of M2-T2 (`golden_hex_t2`, its own package: the target of `golden_hex` is at
/// its line budget, `AGENTS.md` *Golden tests*): the same seeded points as `emit`.
pub fn emit_t2_module(spec: &Spec) -> Result<String, String> {
    let points = seeded_points(
        &spec.text("seed")?,
        spec.int("points")? as usize,
        spec.int("domain_min")? as i32,
        spec.int("domain_max")? as i32,
    );
    let panic_cap = spec.int("panic_cap")? as usize;
    let mut e = Emitter::new(
        spec,
        "the items of M2-T2 of `Hex` (src/hex/mod.rs): `diagonal_neighbor_coord`\n// :641, `add_diag_dir` :649, `diagonal_neighbor` :682, `neighbor_direction` :700,\n// `main_diagonal_to` :709, `diagonal_way_to` :715, `main_direction_to` :734, `way_to` :740,\n// `all_diagonals` :767, the rotations :784-860, the reflections :868-884, `rectiline_to` :936,\n// `range` :993, `xrange` :1021, `to_lower_res` :1064, `to_higher_res` :1114, `to_local` :1143,\n// `wrap_in_range` :1183, `Debug` :1189",
        &format!(
            "use hexx::direction::edge_direction::{{EdgeDirection, EdgeDirectionTrait}};
use hexx::direction::vertex_direction::{{VertexDirection, VertexDirectionTrait}};
use hexx::direction::way::DirectionWay;
use hexx::hex::{{Hex, HexTrait}};
{T2_USES}"
        ),
    );
    emit_t2(&mut e, &points, panic_cap)?;
    e.finish()
}
