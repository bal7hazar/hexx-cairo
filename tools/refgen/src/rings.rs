//! `rings`: the golden vectors of `crates/hexx/src/hex/rings.cairo` against `hexx` 0.25.0
//! (`src/hex/rings.rs`, `src/hex/euclidean.rs:110`): every item at radii `0..=6` around 8 centres,
//! every start direction and both senses for the `custom_` forms, every `VertexDirection` for the
//! ring edges and wedges, the three `*_to` forms on every ordered pair of the centres, the radii
//! spans `[0..=6]`, `[3, 1, 5]` and the empty one, the cached forms at `RANGE` 0, 1 and 7, and
//! `circular_range` at `r` in `0..=12` and 40 around two centres.
//!
//! A span is compared element by element through a digest: the length, then every hex in order,
//! folded into a `u64` (`Digest`, mirrored by `DigestTrait` of the generated file), so that an
//! element out of place changes the digest. Each test walks the same nested loops as the
//! generator (`Dim`), in the order of the expected digests.

use std::path::{Path, PathBuf};

use hexx::{EdgeDirection, Hex, VertexDirection};

use crate::cairo::Emitter;
use crate::spec::Spec;

/// The 8 centres of the vectors (`GoldenTrait::centres`).
const CENTRES: [(i32, i32); 8] =
    [(0, 0), (3, -6), (-5, 4), (12, -7), (-9, -2), (7, 7), (-20, 15), (1, -1)];

/// The radii spans: `0..=6`, `[3, 1, 5]`, the empty span (`GoldenTrait::range_sets`).
const RANGE_SETS: [&[u32]; 3] = [&[0, 1, 2, 3, 4, 5, 6], &[3, 1, 5], &[]];

/// The `RANGE` of the cached forms (`GoldenTrait::counts`).
const COUNTS: [u32; 3] = [0, 1, 7];

/// The radii of `circular_range` of the first test, and of the second.
const CIRCLES_SMALL: std::ops::RangeInclusive<u32> = 0..=12;
const CIRCLES_LARGE: [u32; 1] = [40];

/// FNV-1a over `u64` words, as the generated file folds it.
struct Digest(u64);

impl Digest {
    fn new() -> Self {
        Digest(0xcbf2_9ce4_8422_2325)
    }

    fn fold(&mut self, value: u64) {
        let d = (self.0 ^ value).wrapping_mul(0x100_0000_01b3);
        self.0 = d ^ (d >> 32);
    }

    fn hex(&mut self, h: Hex) {
        let x = (i64::from(h.x) + 0x8000_0000) as u64;
        let y = (i64::from(h.y) + 0x8000_0000) as u64;
        self.fold(x * 0x1_0000_0000 + y);
    }

    fn hexes(&mut self, hexes: &[Hex]) {
        self.fold(hexes.len() as u64);
        for &h in hexes {
            self.hex(h);
        }
    }
}

fn digest_one(hexes: &[Hex]) -> u64 {
    let mut d = Digest::new();
    d.hexes(hexes);
    d.0
}

fn digest_many(spans: &[Vec<Hex>]) -> u64 {
    let mut d = Digest::new();
    d.fold(spans.len() as u64);
    for s in spans {
        d.hexes(s);
    }
    d.0
}

/// A dimension of a test: one nested loop of the generated function and of the generator.
#[derive(Clone, Copy, PartialEq)]
enum Dim {
    Center,
    Target,
    Radius,
    Dir,
    Vertex,
    Sense,
    Ranges,
    Count,
}

impl Dim {
    /// The header of the loop in Cairo and the length of its closing.
    fn header(self, centres: &str) -> String {
        match self {
            Dim::Center => format!("for c in {centres} {{"),
            Dim::Target => "for t in GoldenTrait::centres() {".into(),
            Dim::Radius => "for r in 0..7_u32 {".into(),
            Dim::Dir => "for d in EdgeDirectionTrait::iter() {".into(),
            Dim::Vertex => "for v in VertexDirectionTrait::iter() {".into(),
            Dim::Sense => "for cw in array![false, true] {".into(),
            Dim::Ranges => "for rs in GoldenTrait::range_sets() {".into(),
            Dim::Count => "for k in GoldenTrait::counts() {".into(),
        }
    }
}

/// One point of the product of the dimensions of a test.
#[derive(Clone, Copy, Default)]
struct Case {
    center: (i32, i32),
    target: (i32, i32),
    radius: u32,
    dir: usize,
    vertex: usize,
    clockwise: bool,
    ranges: usize,
    count: u32,
}

impl Case {
    fn center(&self) -> Hex {
        Hex::new(self.center.0, self.center.1)
    }
    fn target(&self) -> Hex {
        Hex::new(self.target.0, self.target.1)
    }
    fn dir(&self) -> EdgeDirection {
        EdgeDirection::ALL_DIRECTIONS[self.dir]
    }
    fn vertex(&self) -> VertexDirection {
        VertexDirection::ALL_DIRECTIONS[self.vertex]
    }
    fn ranges(&self) -> Vec<u32> {
        RANGE_SETS[self.ranges].to_vec()
    }
}

/// The product of `dims` in loop order (the first dimension outermost); the centres restricted to
/// `centres` (a chunk).
fn product(dims: &[Dim], centres: &[(i32, i32)]) -> Vec<Case> {
    let mut cases = vec![Case::default()];
    for &dim in dims {
        let mut next = Vec::new();
        for case in &cases {
            match dim {
                Dim::Center => {
                    for &c in centres {
                        next.push(Case { center: c, ..*case });
                    }
                }
                Dim::Target => {
                    for &c in &CENTRES {
                        next.push(Case { target: c, ..*case });
                    }
                }
                Dim::Radius => {
                    for radius in 0..7 {
                        next.push(Case { radius, ..*case });
                    }
                }
                Dim::Dir => {
                    for dir in 0..6 {
                        next.push(Case { dir, ..*case });
                    }
                }
                Dim::Vertex => {
                    for vertex in 0..6 {
                        next.push(Case { vertex, ..*case });
                    }
                }
                Dim::Sense => {
                    for clockwise in [false, true] {
                        next.push(Case { clockwise, ..*case });
                    }
                }
                Dim::Ranges => {
                    for ranges in 0..RANGE_SETS.len() {
                        next.push(Case { ranges, ..*case });
                    }
                }
                Dim::Count => {
                    for count in COUNTS {
                        next.push(Case { count, ..*case });
                    }
                }
            }
        }
        cases = next;
    }
    cases
}

/// What a function returns, as a digest.
type Eval = fn(&Case) -> u64;

/// One function under test: the loops, the Cairo call, and `hexx`'s answer.
struct Fun {
    name: &'static str,
    dims: &'static [Dim],
    /// The Cairo expression of the digest of the call, in terms of the loop variables.
    call: &'static str,
    eval: Eval,
}

fn one<I: Iterator<Item = Hex>>(iter: I) -> u64 {
    digest_one(&iter.collect::<Vec<_>>())
}

fn many<I: Iterator<Item = Vec<Hex>>>(iter: I) -> u64 {
    digest_many(&iter.collect::<Vec<_>>())
}

fn edges<I, J>(iter: I) -> u64
where
    I: Iterator<Item = J>,
    J: Iterator<Item = Hex>,
{
    many(iter.map(|j| j.collect::<Vec<_>>()))
}

/// `[Vec<Hex>; RANGE]` for the three `RANGE` of the vectors.
macro_rules! cached {
    ($count:expr, $call:ident, $($arg:expr),*) => {
        match $count {
            0 => digest_many(&$call::<0>($($arg),*)),
            1 => digest_many(&$call::<1>($($arg),*)),
            7 => digest_many(&$call::<7>($($arg),*)),
            other => panic!("rings: no RANGE {other}"),
        }
    };
}

fn cached_custom_ring_edges<const R: usize>(h: Hex, v: VertexDirection, cw: bool) -> [Vec<Hex>; R] {
    h.cached_custom_ring_edges::<R>(v, cw)
}

fn cached_ring_edges<const R: usize>(h: Hex, v: VertexDirection) -> [Vec<Hex>; R] {
    h.cached_ring_edges::<R>(v)
}

fn cached_rings<const R: usize>(h: Hex) -> [Vec<Hex>; R] {
    h.cached_rings::<R>()
}

fn cached_custom_rings<const R: usize>(h: Hex, d: EdgeDirection, cw: bool) -> [Vec<Hex>; R] {
    h.cached_custom_rings::<R>(d, cw)
}

use Dim::*;

const FUNS: &[Fun] = &[
    Fun {
        name: "custom_ring",
        dims: &[Center, Radius, Dir, Sense],
        call: "DigestTrait::one((*c).custom_ring(r, *d, cw))",
        eval: |c| one(c.center().custom_ring(c.radius, c.dir(), c.clockwise)),
    },
    Fun {
        name: "ring",
        dims: &[Center, Radius],
        call: "DigestTrait::one((*c).ring(r))",
        eval: |c| one(c.center().ring(c.radius)),
    },
    Fun {
        name: "rings",
        dims: &[Center, Ranges],
        call: "DigestTrait::many((*c).rings(*rs))",
        eval: |c| many(c.center().rings(c.ranges().into_iter())),
    },
    Fun {
        name: "custom_rings",
        dims: &[Center, Ranges, Dir, Sense],
        call: "DigestTrait::many((*c).custom_rings(*rs, *d, cw))",
        eval: |c| many(c.center().custom_rings(c.ranges().into_iter(), c.dir(), c.clockwise)),
    },
    Fun {
        name: "custom_ring_edge",
        dims: &[Center, Radius, Vertex, Sense],
        call: "DigestTrait::one((*c).custom_ring_edge(r, *v, cw))",
        eval: |c| one(c.center().custom_ring_edge(c.radius, c.vertex(), c.clockwise)),
    },
    Fun {
        name: "ring_edge",
        dims: &[Center, Radius, Vertex],
        call: "DigestTrait::one((*c).ring_edge(r, *v))",
        eval: |c| one(c.center().ring_edge(c.radius, c.vertex())),
    },
    Fun {
        name: "ring_edges",
        dims: &[Center, Ranges, Vertex],
        call: "DigestTrait::many((*c).ring_edges(*rs, *v))",
        eval: |c| edges(c.center().ring_edges(c.ranges().into_iter(), c.vertex())),
    },
    Fun {
        name: "custom_ring_edges",
        dims: &[Center, Ranges, Vertex, Sense],
        call: "DigestTrait::many((*c).custom_ring_edges(*rs, *v, cw))",
        eval: |c| {
            edges(c.center().custom_ring_edges(c.ranges().into_iter(), c.vertex(), c.clockwise))
        },
    },
    Fun {
        name: "custom_wedge",
        dims: &[Center, Ranges, Vertex, Sense],
        call: "DigestTrait::one((*c).custom_wedge(*rs, *v, cw))",
        eval: |c| {
            one(c.center().custom_wedge(c.ranges().into_iter(), c.vertex(), c.clockwise))
        },
    },
    Fun {
        name: "wedge",
        dims: &[Center, Ranges, Vertex],
        call: "DigestTrait::one((*c).wedge(*rs, *v))",
        eval: |c| one(c.center().wedge(c.ranges().into_iter(), c.vertex())),
    },
    Fun {
        name: "custom_full_wedge",
        dims: &[Center, Radius, Vertex, Sense],
        call: "DigestTrait::one((*c).custom_full_wedge(r, *v, cw))",
        eval: |c| one(c.center().custom_full_wedge(c.radius, c.vertex(), c.clockwise)),
    },
    Fun {
        name: "full_wedge",
        dims: &[Center, Radius, Vertex],
        call: "DigestTrait::one((*c).full_wedge(r, *v))",
        eval: |c| one(c.center().full_wedge(c.radius, c.vertex())),
    },
    Fun {
        name: "custom_wedge_to",
        dims: &[Center, Target, Sense],
        call: "DigestTrait::one((*c).custom_wedge_to(*t, cw))",
        eval: |c| one(c.center().custom_wedge_to(c.target(), c.clockwise)),
    },
    Fun {
        name: "wedge_to",
        dims: &[Center, Target],
        call: "DigestTrait::one((*c).wedge_to(*t))",
        eval: |c| one(c.center().wedge_to(c.target())),
    },
    Fun {
        name: "corner_wedge",
        dims: &[Center, Ranges, Dir],
        call: "DigestTrait::one((*c).corner_wedge(*rs, *d))",
        eval: |c| one(c.center().corner_wedge(c.ranges().into_iter(), c.dir())),
    },
    Fun {
        name: "corner_wedge_to",
        dims: &[Center, Target],
        call: "DigestTrait::one((*c).corner_wedge_to(*t))",
        eval: |c| one(c.center().corner_wedge_to(c.target())),
    },
    Fun {
        name: "cached_custom_ring_edges",
        dims: &[Center, Count, Vertex, Sense],
        call: "DigestTrait::many((*c).cached_custom_ring_edges(*k, *v, cw))",
        eval: |c| cached!(c.count, cached_custom_ring_edges, c.center(), c.vertex(), c.clockwise),
    },
    Fun {
        name: "cached_ring_edges",
        dims: &[Center, Count, Vertex],
        call: "DigestTrait::many((*c).cached_ring_edges(*k, *v))",
        eval: |c| cached!(c.count, cached_ring_edges, c.center(), c.vertex()),
    },
    Fun {
        name: "cached_rings",
        dims: &[Center, Count],
        call: "DigestTrait::many((*c).cached_rings(*k))",
        eval: |c| cached!(c.count, cached_rings, c.center()),
    },
    Fun {
        name: "cached_custom_rings",
        dims: &[Center, Count, Dir, Sense],
        call: "DigestTrait::many((*c).cached_custom_rings(*k, *d, cw))",
        eval: |c| cached!(c.count, cached_custom_rings, c.center(), c.dir(), c.clockwise),
    },
    Fun {
        name: "custom_spiral_range",
        dims: &[Center, Ranges, Dir, Sense],
        call: "DigestTrait::one((*c).custom_spiral_range(*rs, *d, cw))",
        eval: |c| {
            one(c.center().custom_spiral_range(c.ranges().into_iter(), c.dir(), c.clockwise))
        },
    },
    Fun {
        name: "spiral_range",
        dims: &[Center, Ranges],
        call: "DigestTrait::one((*c).spiral_range(*rs))",
        eval: |c| one(c.center().spiral_range(c.ranges().into_iter())),
    },
];

/// The digests packed as `scarb fmt` packs an array of literals: as many per line as fit in 100
/// columns, each followed by a comma.
fn digest_array(digests: &[u64]) -> String {
    let items: Vec<String> = digests.iter().map(|d| format!("{d:#018x}")).collect();
    let single = format!("    let expected: Array<u64> = array![{}];\n", items.join(", "));
    if single.len() <= 101 {
        return format!("{single}    let mut want = expected.span();\n");
    }
    let mut out = String::from("    let expected: Array<u64> = array![\n");
    let mut line = String::new();
    for d in digests {
        let item = format!("{d:#018x},");
        if line.is_empty() {
            line = format!("        {item}");
        } else if line.len() + 1 + item.len() <= 100 {
            line.push_str(&format!(" {item}"));
        } else {
            out.push_str(&line);
            out.push('\n');
            line = format!("        {item}");
        }
    }
    if !line.is_empty() {
        out.push_str(&line);
        out.push('\n');
    }
    out.push_str("    ];\n    let mut want = expected.span();\n");
    out
}

/// The body of a test: the loops over `dims`, the check of every digest in order.
fn body(_name: &str, dims: &[Dim], call: &str, centres: &str, digests: &[u64]) -> String {
    let mut out = digest_array(digests);
    out.push_str("    let mut n: u32 = 0;\n");
    let mut depth = 1;
    for &dim in dims {
        out.push_str(&format!("{}{}\n", "    ".repeat(depth), dim.header(centres)));
        depth += 1;
    }
    let pad = "    ".repeat(depth);
    out.push_str(&format!("{pad}let got = {call};\n"));
    out.push_str(&format!(
        "{pad}assert!(got == *want.pop_front().unwrap(), \"case {{}}\", n);\n"
    ));
    out.push_str(&format!("{pad}n += 1;\n"));
    for _ in dims {
        depth -= 1;
        out.push_str(&format!("{}}}\n", "    ".repeat(depth)));
    }
    out.push_str("    assert!(want.is_empty());\n");
    out
}

/// `circular_range` at `r` in `radii` around the first two centres.
fn circle_digests(radii: &[u32]) -> Vec<u64> {
    let mut digests = Vec::new();
    for &(x, y) in &CENTRES[..2] {
        for &r in radii {
            digests.push(one(Hex::new(x, y).circular_range(r as f32)));
        }
    }
    digests
}

const PRELUDE: &str = "
/// The digest of `tools/refgen/src/rings.rs` (`Digest`): FNV-1a over `u64` words, folded with its
/// high half, the length of a span first, then every hex in order.
#[generate_trait]
impl DigestImpl of DigestTrait {
    fn fold(digest: u64, value: u64) -> u64 {
        let d = (digest ^ value).wrapping_mul(0x100000001b3);
        d ^ (d / 0x100000000)
    }

    fn hex(digest: u64, hex: Hex) -> u64 {
        let x: i64 = hex.x.into();
        let y: i64 = hex.y.into();
        let x: u64 = (x + 0x80000000).try_into().unwrap();
        let y: u64 = (y + 0x80000000).try_into().unwrap();
        Self::fold(digest, x * 0x100000000 + y)
    }

    fn hexes(digest: u64, hexes: Span<Hex>) -> u64 {
        let mut digest = Self::fold(digest, hexes.len().into());
        for hex in hexes {
            digest = Self::hex(digest, *hex);
        }
        digest
    }

    fn one(hexes: Span<Hex>) -> u64 {
        Self::hexes(0xcbf29ce484222325, hexes)
    }

    fn many(spans: Span<Span<Hex>>) -> u64 {
        let mut digest = Self::fold(0xcbf29ce484222325, spans.len().into());
        for hexes in spans {
            digest = Self::hexes(digest, *hexes);
        }
        digest
    }
}

/// The inputs of the vectors: the 8 centres, the radii spans and the `RANGE` of the cached forms.
#[generate_trait]
impl GoldenImpl of GoldenTrait {
    fn centres() -> Span<Hex> {
        array![
            HexTrait::new(0, 0), HexTrait::new(3, -6), HexTrait::new(-5, 4), HexTrait::new(12, -7),
            HexTrait::new(-9, -2), HexTrait::new(7, 7), HexTrait::new(-20, 15),
            HexTrait::new(1, -1),
        ]
            .span()
    }

    fn range_sets() -> Span<Span<u32>> {
        array![array![0, 1, 2, 3, 4, 5, 6].span(), array![3, 1, 5].span(), array![].span()].span()
    }

    fn counts() -> Span<u32> {
        array![0, 1, 7].span()
    }
}
";

pub fn emit(spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    if CENTRES.len() != 8 {
        return Err("rings: 8 centres".into());
    }
    let mut e = Emitter::new(
        spec,
        "`Hex::custom_ring` ... `Hex::cached_custom_rings` (src/hex/rings.rs),\n// `Hex::circular_range` (src/hex/euclidean.rs:110)",
        "use core::num::traits::WrappingMul;\nuse hexx::direction::edge_direction::EdgeDirectionTrait;\nuse hexx::direction::vertex_direction::VertexDirectionTrait;\nuse hexx::hex::rings::HexRingsTrait;\nuse hexx::hex::{Hex, HexTrait};\n",
    );
    e.out.push_str(PRELUDE);
    for fun in FUNS {
        let chunks = spec.int(&format!("chunks.{}", fun.name))? as usize;
        if CENTRES.len() % chunks != 0 {
            return Err(format!("specs/rings.toml: `chunks.{}` does not divide 8", fun.name));
        }
        let per = CENTRES.len() / chunks;
        for chunk in 0..chunks {
            let centres = &CENTRES[chunk * per..(chunk + 1) * per];
            let digests: Vec<u64> = product(fun.dims, centres).iter().map(fun.eval).collect();
            let list = if chunks == 1 {
                "GoldenTrait::centres()".to_string()
            } else {
                format!("GoldenTrait::centres().slice({}, {per})", chunk * per)
            };
            let name = if chunks == 1 {
                format!("golden_rings_{}", fun.name)
            } else {
                format!("golden_rings_{}_{chunk}", fun.name)
            };
            e.test(&name, false, &body(fun.name, fun.dims, fun.call, &list, &digests))?;
        }
    }
    // `circular_range` at r in 0..=12 and 40 around two centres, against `circular_range_squared(r²)`
    for (name, radii) in
        [("small", CIRCLES_SMALL.collect::<Vec<u32>>()), ("large", CIRCLES_LARGE.to_vec())]
    {
        let digests = circle_digests(&radii);
        let list: Vec<String> = radii.iter().map(u32::to_string).collect();
        let mut out = digest_array(&digests);
        out.push_str("    let mut n: u32 = 0;\n");
        out.push_str("    for center in GoldenTrait::centres().slice(0, 2) {\n");
        out.push_str(&format!("        for r in array![{}] {{\n", list.join(", ")));
        out.push_str("            let squared: i32 = (r * r).try_into().unwrap();\n");
        out.push_str("            let got = DigestTrait::one((*center).circular_range_squared(squared));\n");
        out.push_str("            assert!(got == *want.pop_front().unwrap(), \"circular_range case {}\", n);\n");
        out.push_str("            n += 1;\n        }\n    }\n    assert!(want.is_empty());\n");
        e.test(&format!("golden_rings_circular_range_squared_{name}"), false, &out)?;
    }
    let golden = crate::target(root, spec);
    Ok(vec![(golden, e.finish()?)])
}
