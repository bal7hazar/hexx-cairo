//! `impls`: the operators of `Hex` (`src/hex/impls.rs`) and their named counterparts, the golden
//! vectors of `crates/hexx/src/hex/impls.cairo`, and the exhaustive off-chain comparison of
//! `div_scalar` (brief LIB-06 M2-T3, Scope 2), written to `docs/deviations/div_scalar.md`.
//!
//! Inputs (plan §4.3): `points` seeded coordinates of `[domain_min, domain_max]²`; the binary
//! operators on every ordered pair of them (`chunks` tests), `Neg` on each, the scalar forms on
//! each point by the abscissa of every eighth point, the direction forms on each point in the six
//! directions of both types; then the values
//! near the bounds (`cairo::BOUND_VALUES`), where `hexx` panics in a debug build and wraps in a
//! release build: a table of the cases where it returns, and `#[should_panic]` tests (at most
//! `panic_cap` per function) for those where it panics.
//!
//! `div_scalar`: `hexx` computes `n = length / rhs`, then `ZERO.lerp(self, n as f32 / length as
//! f32)` rounded by `Hex::round` (`impls.rs:241`, `mod.rs:474`, `:973`). The port computes the
//! same rescale on exact rationals, `(x·n/L, y·n/L)`, rounded by the same rule (`exact`). Every
//! `Hex` of `[-div_domain, div_domain]²` by every `rhs` of `[-div_rhs, div_rhs] \ {0}`, and
//! `div_large` seeded pairs with `2^20 ≤ L < 2^31`, are compared with the crate; every pair where
//! they differ is listed with its explanation. The generator stops if a pair differs for a reason
//! other than `f32` error, or if more than 1 % of the exhaustive domain differs.

use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use hexx::{EdgeDirection, Hex, VertexDirection};

use crate::cairo::{cases_array as packed_cases, probe, seeded_points, spread, Emitter, Rng, BOUND_VALUES};
use crate::spec::Spec;

/// The exact rule of `div_scalar` and `rem_scalar` (Scope 2): what the Cairo port computes.
pub mod exact {
    /// `Hex::round` (`src/hex/mod.rs:474-484`) of the point `(nx / d, ny / d)`, `d > 0`, exact:
    /// each component rounded half away from zero; the component with the larger remainder
    /// (compared with `>=`, `x` first) is corrected by `round(r_a + r_b / 2)`.
    pub fn hexround(nx: i128, ny: i128, d: i128) -> (i128, i128) {
        let round = |n: i128, d: i128| {
            let q = n / d;
            let r = n - q * d;
            if 2 * r.abs() >= d {
                q + n.signum()
            } else {
                q
            }
        };
        let (mut xr, mut yr) = (round(nx, d), round(ny, d));
        let (rx, ry) = (nx - xr * d, ny - yr * d);
        if rx.abs() >= ry.abs() {
            xr += round(2 * rx + ry, 2 * d);
        } else {
            yr += round(2 * ry + rx, 2 * d);
        }
        (xr, yr)
    }

    /// `div_scalar`, `None` where the port panics: `rhs = 0`, or `length` panics.
    pub fn div_scalar(x: i32, y: i32, rhs: i32) -> Option<(i32, i32)> {
        let length = super::probe(|| hexx::Hex::new(x, y).length())?;
        if rhs == 0 {
            return None;
        }
        let n = length / rhs;
        if n == 0 {
            return Some((0, 0));
        }
        let (xr, yr) =
            hexround(i128::from(x) * i128::from(n), i128::from(y) * i128::from(n), i128::from(length));
        Some((i32::try_from(xr).ok()?, i32::try_from(yr).ok()?))
    }

    /// `rem_scalar`: `self − div_scalar(self, rhs) · rhs` (`impls.rs:298`), `None` where the port
    /// panics.
    pub fn rem_scalar(x: i32, y: i32, rhs: i32) -> Option<(i32, i32)> {
        let (dx, dy) = div_scalar(x, y, rhs)?;
        Some((x.checked_sub(dx.checked_mul(rhs)?)?, y.checked_sub(dy.checked_mul(rhs)?)?))
    }
}

/// An `f32` as the exact rational `num / 2^shift`.
fn f32_exact(v: f32) -> (i128, u32) {
    if v == 0.0 {
        return (0, 0);
    }
    let bits = v.to_bits();
    let sign: i128 = if bits >> 31 == 1 { -1 } else { 1 };
    let exponent = ((bits >> 23) & 0xff) as i32;
    let (mantissa, exponent) = if exponent == 0 {
        (i128::from(bits & 0x7f_ffff), -149)
    } else {
        (i128::from((bits & 0x7f_ffff) | 0x80_0000), exponent - 150)
    };
    if exponent >= 0 {
        (sign * (mantissa << exponent), 0)
    } else {
        (sign * mantissa, (-exponent) as u32)
    }
}

/// Why `hexx` and the exact rule differ on one pair.
enum Why {
    /// The `f32` rescale moved the point; `hexx` rounds its own point by the exact rule.
    Rescale { px: f32, py: f32 },
    /// The `f32` rescale moved the point, and `Hex::round`'s own `f32` arithmetic moved the result.
    RescaleAndRound { px: f32, py: f32 },
}

/// `hexx`'s point `ZERO.lerp(self, n / L)` in `f32`, as glam 0.30 computes it
/// (`Vec2::lerp`: `self * (1 - s) + rhs * s`).
fn hexx_point(x: i32, y: i32, n: i32, length: i32) -> (f32, f32) {
    let s = n as f32 / length as f32;
    (0.0 * (1.0 - s) + x as f32 * s, 0.0 * (1.0 - s) + y as f32 * s)
}

/// The explanation of a pair where `hexx` and the rule differ, `None` if it is not `f32` error:
/// the exact point is what `hexx`'s point would be without `f32` error.
fn explain(x: i32, y: i32, rhs: i32, hexx: (i32, i32)) -> Option<Why> {
    let length = Hex::new(x, y).length();
    let n = length / rhs;
    let (px, py) = hexx_point(x, y, n, length);
    let ((nx, sx), (ny, sy)) = (f32_exact(px), f32_exact(py));
    let shift = sx.max(sy);
    let (nx, ny) = (nx << (shift - sx), ny << (shift - sy));
    let d = 1i128 << shift;
    // The point is exact: `hexx` rounded the exact point and differs, not an `f32` rescale
    let (ex, ey, el) = (i128::from(x) * i128::from(n), i128::from(y) * i128::from(n), i128::from(length));
    if nx * el == ex * d && ny * el == ey * d {
        return None;
    }
    let (rx, ry) = exact::hexround(nx, ny, d);
    if (rx, ry) == (i128::from(hexx.0), i128::from(hexx.1)) {
        Some(Why::Rescale { px, py })
    } else {
        Some(Why::RescaleAndRound { px, py })
    }
}

/// `hexx`'s `Div<i32>`, `None` where it panics.
fn hexx_div(x: i32, y: i32, rhs: i32) -> Option<(i32, i32)> {
    probe(|| Hex::new(x, y) / rhs).map(|h| (h.x, h.y))
}

/// `hexx`'s `Rem<i32>`, `None` where it panics.
fn hexx_rem(x: i32, y: i32, rhs: i32) -> Option<(i32, i32)> {
    probe(|| Hex::new(x, y) % rhs).map(|h| (h.x, h.y))
}

/// One pair where `hexx` and the rule differ.
struct Deviation {
    x: i32,
    y: i32,
    rhs: i32,
    hexx: (i32, i32),
    rule: (i32, i32),
    why: Why,
}

/// The comparison of `div_scalar` with `hexx` on one set: the pairs that agree (`hexx` returns),
/// the pairs where both panic, and the deviations.
struct Compared {
    agree: Vec<(i32, i32, i32, (i32, i32))>,
    deviations: Vec<Deviation>,
    total: usize,
}

fn compare(pairs: &[(i32, i32, i32)]) -> Result<Compared, String> {
    let mut out = Compared { agree: Vec::new(), deviations: Vec::new(), total: pairs.len() };
    for &(x, y, rhs) in pairs {
        let (h, r) = (hexx_div(x, y, rhs), exact::div_scalar(x, y, rhs));
        match (h, r) {
            (Some(h), Some(r)) if h == r => {
                // `rem_scalar` follows: same rule, same panics
                if hexx_rem(x, y, rhs) != exact::rem_scalar(x, y, rhs) {
                    return Err(format!("rem_scalar differs where div_scalar agrees: ({x}, {y}) % {rhs}"));
                }
                out.agree.push((x, y, rhs, h));
            }
            (None, None) => {}
            (Some(h), Some(r)) => {
                let why = explain(x, y, rhs, h).ok_or_else(|| {
                    format!(
                        "div_scalar: ({x}, {y}) / {rhs}: hexx {h:?}, rule {r:?}, not explained by f32 \
                         error (Scope 2: stop and report)"
                    )
                })?;
                out.deviations.push(Deviation { x, y, rhs, hexx: h, rule: r, why });
            }
            _ => return Err(format!("div_scalar: ({x}, {y}) / {rhs}: hexx {h:?}, rule {r:?}: one panics")),
        }
    }
    Ok(out)
}

/// The exhaustive domain: every `Hex` of `[-d, d]²` by every `rhs` of `[-k, k] \ {0}`.
fn exhaustive(d: i32, k: i32) -> Vec<(i32, i32, i32)> {
    let mut pairs = Vec::new();
    for x in -d..=d {
        for y in -d..=d {
            for rhs in (-k..=k).filter(|&r| r != 0) {
                pairs.push((x, y, rhs));
            }
        }
    }
    pairs
}

/// `count` seeded pairs with `2^20 ≤ L < 2^31`, `rhs` in `[-k, k] \ {0}`.
fn large(seed: &str, count: usize, k: i32) -> Vec<(i32, i32, i32)> {
    let mut rng = Rng::new(seed);
    let mut pairs = Vec::new();
    while pairs.len() < count {
        let x = rng.next_i32(-(1 << 30) + 1, (1 << 30) - 1);
        let y = rng.next_i32(-(1 << 30) + 1, (1 << 30) - 1);
        let rhs = rng.next_i32(-k, k);
        if rhs == 0 || Hex::new(x, y).length() < 1 << 20 {
            continue;
        }
        pairs.push((x, y, rhs));
    }
    pairs
}

fn fmt_f32(v: f32) -> String {
    format!("{v:?}")
}

/// `docs/deviations/div_scalar.md`.
fn deviations_doc(sets: &[(&str, &Compared)]) -> String {
    let mut out = String::new();
    out.push_str("# `div_scalar`: where this port and `hexx` 0.25.0 differ\n\n");
    out.push_str(
        "Generated by `cargo run --manifest-path tools/refgen/Cargo.toml -- gen impls` \
         (`tools/refgen/src/impls.rs`); do not edit by hand.\n\n",
    );
    out.push_str(
        "`HexOpsTrait::div_scalar(self, rhs)` is the counterpart of `impl Div<i32> for Hex` \
         (`src/hex/impls.rs:241`). `hexx` computes `n = L / rhs` (`L = self.length()`, `i32`, \
         truncated toward zero), then `Hex::ZERO.lerp(self, n as f32 / L as f32)` (`src/hex/mod.rs:973`, \
         glam's `Vec2::lerp`) rounded by `Hex::round` (`:474-484`). The port computes the same \
         point exactly, `(x·n / L, y·n / L)`, and rounds it by the same rule, exactly: each \
         component half away from zero, then the component with the larger remainder (compared \
         with `>=`, `x` first) corrected by `round(r_a + r_b / 2)`. `L = 0` gives `ZERO` in both \
         (`hexx`: `0 / 0` is NaN, and NaN casts to `0`). `rem_scalar` is `self − \
         div_scalar(self, rhs) · rhs` (`:298`) and differs exactly where `div_scalar` does.\n\n",
    );
    out.push_str(
        "Every difference below is `f32` error: `hexx`'s point (`f32`, printed as Rust prints it) is \
         not the exact point `(x·n / L, y·n / L)`. Under *rescale*, `hexx`'s result is the exact rule \
         applied to its own `f32` point; under *rescale and round*, `Hex::round`'s own `f32` \
         arithmetic moved it further. `hexx`'s points are printed in their shortest round-trip \
         form (Rust's `{:?}` of an `f32`), not as their exact binary values; the generator compares \
         the exact values. The generator stops on a difference of any other kind, and \
         when more than 1 % of the exhaustive domain differs (brief LIB-06 M2-T3, Scope 2).\n\n",
    );
    out.push_str("## The sets compared\n\n| Set | Pairs | Pairs that differ |\n|---|---|---|\n");
    for (name, c) in sets {
        let _ = writeln!(out, "| {name} | {} | {} |", c.total, c.deviations.len());
    }
    for (name, c) in sets {
        let _ = writeln!(out, "\n## {name}\n");
        if c.deviations.is_empty() {
            out.push_str("No pair differs.\n");
            continue;
        }
        out.push_str("| Hex | rhs | L | n | hexx | rule | Why | hexx's point |\n|---|---|---|---|---|---|---|---|\n");
        for d in &c.deviations {
            let length = Hex::new(d.x, d.y).length();
            let (why, px, py) = match d.why {
                Why::Rescale { px, py } => ("rescale", px, py),
                Why::RescaleAndRound { px, py } => ("rescale and round", px, py),
            };
            let _ = writeln!(
                out,
                "| `({}, {})` | {} | {} | {} | `({}, {})` | `({}, {})` | {why} | `({}, {})` |",
                d.x,
                d.y,
                d.rhs,
                length,
                length / d.rhs,
                d.hexx.0,
                d.hexx.1,
                d.rule.0,
                d.rule.1,
                fmt_f32(px),
                fmt_f32(py)
            );
        }
    }
    out
}

// ---------------------------------------------------------------------------------------------
// The golden file
// ---------------------------------------------------------------------------------------------

/// `cairo::cases_array`, with the header split after `=` when it exceeds 100 columns, as
/// `scarb fmt` splits it.
pub fn cases_array(types: &str, rows: &[String]) -> String {
    let text = packed_cases(types, rows);
    let (first, rest) = text.split_once('\n').unwrap_or((&text, ""));
    if first.len() <= 100 {
        return text;
    }
    let head = first.strip_suffix(" array![").unwrap_or(first);
    format!("{head}\n        array![\n{rest}")
}

/// A table test: `rows` bound to `cases`, each destructured into `vars`, then `body` (lines
/// indented by eight spaces) in the loop.
pub fn table(types: &str, vars: &str, rows: &[String], body: &str) -> String {
    format!(
        "{}    let mut i = 0;
    while i < cases.len() {{
        let ({vars}) = *cases.at(i);
{body}        i += 1;
    }}
",
        cases_array(types, rows)
    )
}

/// `let (vars): (types) = (values);`, broken after the `(` as `scarb fmt` does past 100 columns.
pub fn binding(vars: &str, types: &str, values: &str) -> String {
    let line = format!("    let ({vars}): ({types}) = ({values});\n");
    if line.len() <= 101 {
        line
    } else {
        format!("    let ({vars}): ({types}) = (\n        {values},\n    );\n")
    }
}

/// A function under test, for the generators of `swizzle`, `euclidean` and `convert`: its name,
/// the row's input types and variables, the Cairo lines that build the operands (indented by eight
/// spaces), the call, the types and variables of the expected result, the Cairo expression of the
/// expected result from them, `hexx`'s result as literals (`None` when it panics) and the literals
/// of an input.
pub struct Fun<I> {
    pub name: &'static str,
    pub types: &'static str,
    pub vars: &'static str,
    pub setup: &'static str,
    pub call: &'static str,
    pub out_types: &'static str,
    pub out_vars: &'static str,
    pub expected: &'static str,
    pub eval: fn(I) -> Option<Vec<String>>,
    pub row: fn(I) -> String,
}

/// One table test `golden_<module>_<prefix>_<name>` per function over `inputs` (the cases where
/// `hexx` returns), and with `panics`, up to that many `#[should_panic]` tests per function, evenly
/// spread over the inputs where `hexx` panics; without it, an input that panics is an error.
pub fn fun_tables<I: Copy>(
    e: &mut Emitter,
    module: &str,
    prefix: &str,
    inputs: &[I],
    funs: &[Fun<I>],
    panics: Option<usize>,
) -> Result<(), String> {
    for fun in funs {
        let mut rows = Vec::new();
        let mut failing = Vec::new();
        for &input in inputs {
            match (fun.eval)(input) {
                Some(values) => rows.push(format!("{}, {}", (fun.row)(input), values.join(", "))),
                None if panics.is_some() => failing.push(input),
                None => return Err(format!("hexx panics inside the seeded domain: {}", fun.name)),
            }
        }
        let check = format!(
            "{}        assert({} == {}, '{}');\n",
            fun.setup, fun.call, fun.expected, fun.name
        );
        let body = table(
            &format!("{}, {}", fun.types, fun.out_types),
            &format!("{}, {}", fun.vars, fun.out_vars),
            &rows,
            &check,
        );
        e.test(&format!("golden_{module}_{prefix}_{}", fun.name), false, &body)?;
        if let Some(cap) = panics {
            if failing.is_empty() {
                return Err(format!("no bound input makes hexx panic in {}", fun.name));
            }
            for (n, input) in spread(&failing, cap).into_iter().enumerate() {
                let setup: String = fun.setup.lines().map(|l| format!("{}\n", &l[4..])).collect();
                let body = format!(
                    "{}{setup}    let _ = {};\n",
                    binding(fun.vars, fun.types, &(fun.row)(input)),
                    fun.call
                );
                e.test(&format!("golden_{module}_{prefix}_{}_panics_{n}", fun.name), true, &body)?;
            }
        }
    }
    Ok(())
}

/// `(x, y)` of a coordinate as literals.
pub fn pair(h: Hex) -> Vec<String> {
    vec![h.x.to_string(), h.y.to_string()]
}

pub fn hx(p: (i32, i32)) -> Hex {
    Hex::new(p.0, p.1)
}

fn xy(h: Hex) -> String {
    format!("{}, {}", h.x, h.y)
}

/// The pairs near the bounds: the extremes, the axes and the halves.
pub const BOUND_PAIR_POINTS: [(i32, i32); 15] = [
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

/// The components of the divisors near the bounds: the extremes, the halves and `±1`.
const DIVISORS: [i32; 6] = [i32::MIN, -1_073_741_824, -1, 1, 1_073_741_824, i32::MAX];

/// A binary operator of `Hex` by `Hex`: its name, `hexx`'s result, the Cairo checks of a row.
struct BinaryOp {
    name: &'static str,
    eval: fn(Hex, Hex) -> Hex,
    /// The loop lines after `a` and `b` are bound; the expected result is `(ex, ey)`.
    check: &'static str,
}

const BINARY_OPS: [BinaryOp; 5] = [
    BinaryOp {
        name: "add",
        eval: |a, b| a + b,
        check: "        let mut c = a;
        c += b;
        assert(a + b == HexTrait::new(ex, ey) && c == a + b, 'add');
",
    },
    BinaryOp {
        name: "sub",
        eval: |a, b| a - b,
        check: "        let mut c = a;
        c -= b;
        assert(a - b == HexTrait::new(ex, ey) && c == a - b, 'sub');
",
    },
    BinaryOp {
        name: "mul",
        eval: |a, b| a * b,
        check: "        let mut c = a;
        c *= b;
        assert(a * b == HexTrait::new(ex, ey) && c == a * b, 'mul');
",
    },
    BinaryOp {
        name: "div",
        eval: |a, b| a / b,
        check: "        let mut c = a;
        c /= b;
        assert(a / b == HexTrait::new(ex, ey) && c == a / b, 'div');
",
    },
    BinaryOp {
        name: "rem",
        eval: |a, b| a % b,
        check: "        let mut c = a;
        c %= b;
        assert(a % b == HexTrait::new(ex, ey) && c == a % b, 'rem');
",
    },
];

const PAIR_VARS: &str = "x1, y1, x2, y2, ex, ey";
const PAIR_TYPES: &str = "i32, i32, i32, i32, i32, i32";
const PAIR_PRELUDE: &str = "        let a = HexTrait::new(x1, y1);
        let b = HexTrait::new(x2, y2);
";

/// A unary or scalar counterpart: its name, the row's input types and variables, the Cairo lines
/// that build its operands from them (indented by eight spaces), the call, and `hexx`'s result.
struct Op<I> {
    name: &'static str,
    types: &'static str,
    vars: &'static str,
    setup: &'static str,
    call: &'static str,
    eval: fn(I) -> Option<Hex>,
    row: fn(I) -> String,
}

fn tables<I: Copy>(
    e: &mut Emitter,
    prefix: &str,
    inputs: &[I],
    ops: &[Op<I>],
    panics: Option<usize>,
) -> Result<(), String> {
    for op in ops {
        let mut rows = Vec::new();
        let mut failing = Vec::new();
        for &input in inputs {
            match (op.eval)(input) {
                Some(r) => rows.push(format!("{}, {}", (op.row)(input), xy(r))),
                None if panics.is_some() => failing.push(input),
                None => return Err(format!("hexx panics inside the seeded domain: {}", op.name)),
            }
        }
        let check = format!(
            "{}        assert({} == HexTrait::new(ex, ey), '{}');\n",
            op.setup, op.call, op.name
        );
        let body = table(&format!("{}, i32, i32", op.types), &format!("{}, ex, ey", op.vars), &rows, &check);
        e.test(&format!("golden_impls_{prefix}_{}", op.name), false, &body)?;
        if let Some(cap) = panics {
            if failing.is_empty() {
                return Err(format!("no bound input makes hexx panic in {}", op.name));
            }
            for (n, input) in spread(&failing, cap).into_iter().enumerate() {
                let setup: String = op.setup.lines().map(|l| format!("{}\n", &l[4..])).collect();
                let body = format!(
                    "{}{setup}    let _ = {};\n",
                    binding(op.vars, op.types, &(op.row)(input)),
                    op.call
                );
                e.test(&format!("golden_impls_{prefix}_{}_panics_{n}", op.name), true, &body)?;
            }
        }
    }
    Ok(())
}

pub fn hex_row(p: (i32, i32)) -> String {
    format!("{}, {}", p.0, p.1)
}

fn scalar_row(p: ((i32, i32), i32)) -> String {
    format!("{}, {}, {}", (p.0).0, (p.0).1, p.1)
}

fn dir_row(p: ((i32, i32), usize)) -> String {
    format!("{}, {}, {}", (p.0).0, (p.0).1, p.1)
}

const NEG: [Op<(i32, i32)>; 1] = [Op {
    name: "neg",
    types: "i32, i32",
    vars: "x, y",
    setup: "        let h = HexTrait::new(x, y);
",
    call: "-h",
    eval: |p| probe(|| -hx(p)),
    row: hex_row,
}];

const SCALAR: [Op<((i32, i32), i32)>; 2] = [
    Op {
        name: "add_scalar",
        types: "i32, i32, i32",
        vars: "x, y, k",
        setup: "        let h = HexTrait::new(x, y);
",
        call: "h.add_scalar(k)",
        eval: |p| probe(|| hx(p.0) + p.1),
        row: scalar_row,
    },
    Op {
        name: "sub_scalar",
        types: "i32, i32, i32",
        vars: "x, y, k",
        setup: "        let h = HexTrait::new(x, y);
",
        call: "h.sub_scalar(k)",
        eval: |p| probe(|| hx(p.0) - p.1),
        row: scalar_row,
    },
];

const DIRECTIONS: [Op<((i32, i32), usize)>; 4] = [
    Op {
        name: "add_direction",
        types: "i32, i32, u8",
        vars: "x, y, di",
        setup: "        let h = HexTrait::new(x, y);
        let d = *EdgeDirectionTrait::ALL_DIRECTIONS.span().at(di.into());
",
        call: "h.add_direction(d)",
        eval: |p| probe(|| hx(p.0) + EdgeDirection::ALL_DIRECTIONS[p.1]),
        row: dir_row,
    },
    Op {
        name: "sub_direction",
        types: "i32, i32, u8",
        vars: "x, y, di",
        setup: "        let h = HexTrait::new(x, y);
        let d = *EdgeDirectionTrait::ALL_DIRECTIONS.span().at(di.into());
",
        call: "h.sub_direction(d)",
        eval: |p| probe(|| hx(p.0) - EdgeDirection::ALL_DIRECTIONS[p.1]),
        row: dir_row,
    },
    Op {
        name: "add_diagonal",
        types: "i32, i32, u8",
        vars: "x, y, di",
        setup: "        let h = HexTrait::new(x, y);
        let d = *VertexDirectionTrait::ALL_DIRECTIONS.span().at(di.into());
",
        call: "h.add_diagonal(d)",
        eval: |p| probe(|| hx(p.0) + VertexDirection::ALL_DIRECTIONS[p.1]),
        row: dir_row,
    },
    Op {
        name: "sub_diagonal",
        types: "i32, i32, u8",
        vars: "x, y, di",
        setup: "        let h = HexTrait::new(x, y);
        let d = *VertexDirectionTrait::ALL_DIRECTIONS.span().at(di.into());
",
        call: "h.sub_diagonal(d)",
        eval: |p| probe(|| hx(p.0) - VertexDirection::ALL_DIRECTIONS[p.1]),
        row: dir_row,
    },
];

/// `div_scalar` and `rem_scalar` on the pairs where `hexx` and the rule agree.
const DIV_SCALAR: [Op<((i32, i32), i32)>; 2] = [
    Op {
        name: "div_scalar",
        types: "i32, i32, i32",
        vars: "x, y, k",
        setup: "        let h = HexTrait::new(x, y);
",
        call: "h.div_scalar(k)",
        eval: |p| probe(|| hx(p.0) / p.1),
        row: scalar_row,
    },
    Op {
        name: "rem_scalar",
        types: "i32, i32, i32",
        vars: "x, y, k",
        setup: "        let h = HexTrait::new(x, y);
",
        call: "h.rem_scalar(k)",
        eval: |p| probe(|| hx(p.0) % p.1),
        row: scalar_row,
    },
];

/// The binary operators of `Hex` by `Hex` on the seeded `pairs`, all of `ops` in one table: a row
/// is the pair, then the result of each operator (`hexx` returns on every seeded pair).
fn combined_table(
    e: &mut Emitter,
    name: &str,
    pairs: &[((i32, i32), (i32, i32))],
    ops: &[&BinaryOp],
) -> Result<(), String> {
    let mut rows = Vec::new();
    for &(a, b) in pairs {
        let mut row = format!("{}, {}", hex_row(a), hex_row(b));
        for op in ops {
            let r = probe(|| (op.eval)(hx(a), hx(b)))
                .ok_or_else(|| format!("hexx panics inside the seeded domain: {}", op.name))?;
            row.push_str(&format!(", {}", xy(r)));
        }
        rows.push(row);
    }
    let mut types = String::from("i32, i32, i32, i32");
    let mut vars = String::from("x1, y1, x2, y2");
    let mut body = String::from(PAIR_PRELUDE);
    for op in ops {
        types.push_str(", i32, i32");
        vars.push_str(&format!(", {0}x, {0}y", &op.name[..1]));
        body.push_str(&format!(
            "        let (ex, ey) = ({0}x, {0}y);\n{1}",
            &op.name[..1],
            op.check
        ));
    }
    e.test(&format!("golden_impls_{name}"), false, &table(&types, &vars, &rows, &body))
}

/// The binary operators of `Hex` by `Hex` on the `pairs` near the bounds: a table per operator of
/// the pairs where `hexx` returns, and `#[should_panic]` tests of those where it panics.
fn binary_tables(
    e: &mut Emitter,
    prefix: &str,
    pairs: &[((i32, i32), (i32, i32))],
    ops: &[&BinaryOp],
    cap: usize,
) -> Result<(), String> {
    for op in ops {
        let mut rows = Vec::new();
        let mut failing = Vec::new();
        for &(a, b) in pairs {
            match probe(|| (op.eval)(hx(a), hx(b))) {
                Some(r) => rows.push(format!("{}, {}, {}", hex_row(a), hex_row(b), xy(r))),
                None => failing.push((a, b)),
            }
        }
        let body = table(PAIR_TYPES, PAIR_VARS, &rows, &format!("{PAIR_PRELUDE}{}", op.check));
        e.test(&format!("golden_impls_{prefix}_{}", op.name), false, &body)?;
        if failing.is_empty() {
            return Err(format!("no bound pair makes hexx panic in {}", op.name));
        }
        let symbol = match op.name {
            "add" => "+",
            "sub" => "-",
            "mul" => "*",
            "div" => "/",
            _ => "%",
        };
        for (n, (a, b)) in spread(&failing, cap).into_iter().enumerate() {
            let body = format!(
                "    let a = HexTrait::new({});\n    let b = HexTrait::new({});\n    let _ = a {symbol} b;\n",
                hex_row(a),
                hex_row(b)
            );
            e.test(&format!("golden_impls_{prefix}_{}_panics_{n}", op.name), true, &body)?;
        }
    }
    Ok(())
}

/// The named regression cases of Scope 2, with the values the crate gives.
fn regressions(e: &mut Emitter, ties: &[(i32, i32, i32)]) -> Result<(), String> {
    let mut cases: Vec<(i32, i32, i32)> = vec![(0, 0, 1), (0, 0, -1), (0, 0, 7)];
    // `rhs > L`, `rhs = -1`, `rhs = 1`, the two named pairs
    cases.extend([(2, -1, 3), (-5, 3, 6), (7, -3, -1), (-4, 9, -1), (7, -3, 1), (-4, 9, 1), (3, 0, 2), (1, 1, 2)]);
    cases.extend(ties);
    let mut rows = Vec::new();
    for (x, y, k) in cases {
        let d = hexx_div(x, y, k).ok_or("hexx panics on a regression case")?;
        let r = hexx_rem(x, y, k).ok_or("hexx panics on a regression case")?;
        if exact::div_scalar(x, y, k) != Some(d) || exact::rem_scalar(x, y, k) != Some(r) {
            return Err(format!("regression case ({x}, {y}) / {k} deviates"));
        }
        rows.push(format!("{x}, {y}, {k}, {}, {}, {}, {}", d.0, d.1, r.0, r.1));
    }
    let body = table(
        "i32, i32, i32, i32, i32, i32, i32",
        "x, y, k, dx, dy, rx, ry",
        &rows,
        "        let h = HexTrait::new(x, y);
        assert(h.div_scalar(k) == HexTrait::new(dx, dy), 'div_scalar');
        assert(h.rem_scalar(k) == HexTrait::new(rx, ry), 'rem_scalar');
",
    );
    e.test("golden_impls_div_scalar_regressions", false, &body)?;
    for (n, (x, y)) in [(0, 0), (3, -2)].into_iter().enumerate() {
        let body = format!("    let _ = HexTrait::new({x}, {y}).div_scalar(0);\n");
        e.test(&format!("golden_impls_div_scalar_zero_panics_{n}"), true, &body)?;
        let body = format!("    let _ = HexTrait::new({x}, {y}).rem_scalar(0);\n");
        e.test(&format!("golden_impls_rem_scalar_zero_panics_{n}"), true, &body)?;
    }
    Ok(())
}

/// The exact hexround ties of the exhaustive domain where `hexx` agrees: the first one with a
/// positive and with a negative `rhs` (a tie: `2·|r_x| = L` or `2·|r_y| = L`, or the correction
/// itself at a half).
fn ties(agree: &[(i32, i32, i32, (i32, i32))]) -> Vec<(i32, i32, i32)> {
    let is_tie = |x: i32, y: i32, k: i32| {
        let l = i128::from(Hex::new(x, y).length());
        let n = l / i128::from(k);
        let (nx, ny) = (i128::from(x) * n, i128::from(y) * n);
        let half = |v: i128| (2 * v).rem_euclid(2 * l) == l;
        l != 0 && n != 0 && (half(nx) || half(ny))
    };
    let mut out = Vec::new();
    for positive in [true, false] {
        if let Some(&(x, y, k, _)) =
            agree.iter().find(|&&(x, y, k, _)| (k > 0) == positive && is_tie(x, y, k))
        {
            out.push((x, y, k));
        }
    }
    out
}

pub fn emit(spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    let points = seeded_points(
        &spec.text("seed")?,
        spec.int("points")? as usize,
        spec.int("domain_min")? as i32,
        spec.int("domain_max")? as i32,
    );
    let chunks = spec.int("chunks")? as usize;
    let panic_cap = spec.int("panic_cap")? as usize;
    if points.len() % chunks != 0 {
        return Err("specs/impls.toml: `points` is not a multiple of `chunks`".into());
    }

    // `div_scalar`, off-chain: the exhaustive domain and the large sample.
    let (d, k) = (spec.int("div_domain")? as i32, spec.int("div_rhs")? as i32);
    let domain = exhaustive(d, k);
    let full = compare(&domain)?;
    let big = compare(&large(&spec.text("seed_large")?, spec.int("div_large")? as usize, k))?;
    if full.deviations.len() * 100 > full.total {
        return Err(format!(
            "div_scalar: {} of {} pairs of the exhaustive domain differ, more than 1 % (Scope 2: stop and report)",
            full.deviations.len(),
            full.total
        ));
    }
    let names = [
        (format!("exhaustive, every `Hex` of `[-{d}, {d}]²` by every `rhs` of `[-{k}, {k}] \\ {{0}}`"), &full),
        (format!("seeded, `2^20 ≤ L < 2^31`, `rhs` in `[-{k}, {k}] \\ {{0}}`"), &big),
    ];
    let doc = deviations_doc(&names.iter().map(|(n, c)| (n.as_str(), *c)).collect::<Vec<_>>());

    let mut e = Emitter::new(
        spec,
        "the operators of `Hex` (src/hex/impls.rs): `Add` :16, `AddAssign` :55,\n// `Sub` :96, `SubAssign` :135, `Mul` :164, `MulAssign` :196, `Div` :230,\n// `DivAssign` :265, `Rem` :286, `RemAssign` :304, `Neg` :318; the counterparts\n// `Add<i32>` :25, `Add<EdgeDirection>` :38, `Add<VertexDirection>` :46, `Sub<i32>` :105,\n// `Sub<EdgeDirection>` :117, `Sub<VertexDirection>` :125, `Div<i32>` :241, `Rem<i32>` :295",
        "use hexx::direction::edge_direction::EdgeDirectionTrait;\nuse hexx::direction::vertex_direction::VertexDirectionTrait;\nuse hexx::hex::HexTrait;\nuse hexx::hex::impls::{\n    HexAdd, HexAddAssign, HexDiv, HexDivAssign, HexMul, HexMulAssign, HexNeg, HexOpsTrait, HexRem,\n    HexRemAssign, HexSub, HexSubAssign,\n};\n",
    );

    // The binary operators on every ordered pair of the seeded points, in `chunks` tests per
    // operator; `Div` and `Rem` on the pairs without a zero divisor component.
    let all: Vec<&BinaryOp> = BINARY_OPS.iter().collect();
    let per_chunk = points.len() / chunks;
    for chunk in 0..chunks {
        let pairs: Vec<_> = points[chunk * per_chunk..(chunk + 1) * per_chunk]
            .iter()
            .flat_map(|&a| points.iter().map(move |&b| (a, b)))
            .collect();
        combined_table(&mut e, &format!("pairs_{chunk}"), &pairs, &all[..3])?;
        let divisible: Vec<_> = pairs.into_iter().filter(|&(_, b)| b.0 != 0 && b.1 != 0).collect();
        combined_table(&mut e, &format!("divisible_{chunk}"), &divisible, &all[3..])?;
    }
    // A zero divisor component panics in `hexx` (integer division by zero).
    for (n, (a, b)) in [((7, -3), (0, 2)), ((7, -3), (2, 0))].into_iter().enumerate() {
        for (name, symbol) in [("div", "/"), ("rem", "%")] {
            let body = format!(
                "    let a = HexTrait::new({});\n    let b = HexTrait::new({});\n    let _ = a {symbol} b;\n",
                hex_row(a),
                hex_row(b)
            );
            if probe(|| if symbol == "/" { hx(a) / hx(b) } else { hx(a) % hx(b) }).is_some() {
                return Err("hexx does not panic on a zero divisor".into());
            }
            e.test(&format!("golden_impls_{name}_zero_panics_{n}"), true, &body)?;
        }
    }
    let bound_pairs: Vec<_> = BOUND_PAIR_POINTS
        .iter()
        .flat_map(|&a| BOUND_PAIR_POINTS.iter().map(move |&b| (a, b)))
        .collect();
    // `Div` and `Rem`: the divisors of `DIVISORS²` (`-1` among them: `i32::MIN / -1` overflows).
    let nonzero: Vec<_> = BOUND_PAIR_POINTS
        .iter()
        .flat_map(|&a| {
            DIVISORS.iter().flat_map(|&x| DIVISORS.iter().map(move |&y| (x, y))).map(move |b| (a, b))
        })
        .collect();
    binary_tables(&mut e, "bounds", &bound_pairs, &all[..3], panic_cap)?;
    binary_tables(&mut e, "bounds", &nonzero, &all[3..], panic_cap)?;

    // `Neg` on the seeded points, then near the bounds.
    tables(&mut e, "unary", &points, &NEG, None)?;
    let bounds = crate::cairo::bound_points();
    tables(&mut e, "bounds", &bounds, &NEG, Some(panic_cap))?;

    // The scalar forms: every point by the abscissa of every eighth point, then near the bounds.
    let scalars: Vec<((i32, i32), i32)> = points
        .iter()
        .flat_map(|&p| points.iter().step_by(8).map(move |&q| (p, q.0)))
        .collect();
    tables(&mut e, "scalar", &scalars, &SCALAR, None)?;
    let bound_scalars: Vec<((i32, i32), i32)> = BOUND_PAIR_POINTS
        .iter()
        .flat_map(|&p| BOUND_VALUES.iter().map(move |&k| (p, k)))
        .collect();
    tables(&mut e, "bounds_scalar", &bound_scalars, &SCALAR, Some(panic_cap))?;

    // The direction forms: the six directions of both types on every point, then near the bounds.
    let directions: Vec<((i32, i32), usize)> =
        points.iter().flat_map(|&p| (0..6).map(move |d| (p, d))).collect();
    tables(&mut e, "direction", &directions, &DIRECTIONS, None)?;
    let bound_directions: Vec<((i32, i32), usize)> =
        bounds.iter().flat_map(|&p| (0..6).map(move |d| (p, d))).collect();
    tables(&mut e, "bounds_direction", &bound_directions, &DIRECTIONS, Some(panic_cap))?;

    // `div_scalar` and `rem_scalar`: a seeded sample of the pairs where `hexx` and the rule agree,
    // every pair of `[-small_div, small_div]²` by `[-small_div, small_div] \ {0}`, the regression
    // cases, and near the bounds (the pairs where both agree, and those where `hexx` panics).
    let mut rng = Rng::new(&spec.text("seed_div")?);
    let sample: Vec<((i32, i32), i32)> = (0..spec.int("div_sample")?)
        .map(|_| {
            let (x, y, k, _) = full.agree[rng.next_i32(0, full.agree.len() as i32 - 1) as usize];
            ((x, y), k)
        })
        .collect();
    tables(&mut e, "seeded", &sample, &DIV_SCALAR, None)?;
    let s = spec.int("small_div")? as i32;
    let small_pairs: Vec<((i32, i32), i32)> = exhaustive(s, s)
        .into_iter()
        .map(|(x, y, k)| ((x, y), k))
        .collect();
    for &((x, y), k) in &small_pairs {
        if hexx_div(x, y, k) != exact::div_scalar(x, y, k) {
            return Err(format!("div_scalar deviates on the small domain: ({x}, {y}) / {k}"));
        }
    }
    let parts = spec.int("small_chunks")? as usize;
    for (n, part) in small_pairs.chunks(small_pairs.len().div_ceil(parts)).enumerate() {
        tables(&mut e, &format!("small_{n}"), part, &DIV_SCALAR, None)?;
    }
    regressions(&mut e, &ties(&full.agree))?;
    let bound_div: Vec<((i32, i32), i32)> = bounds
        .iter()
        .flat_map(|&p| BOUND_VALUES.iter().map(move |&k| (p, k)))
        .filter(|&((x, y), k)| hexx_div(x, y, k) == exact::div_scalar(x, y, k))
        .collect();
    tables(&mut e, "bounds_scalar", &bound_div, &DIV_SCALAR, Some(panic_cap))?;

    let golden = crate::target(root, spec);
    let deviations = root.join("docs").join("deviations").join("div_scalar.md");
    Ok(vec![(golden, e.finish()?), (deviations, doc)])
}
