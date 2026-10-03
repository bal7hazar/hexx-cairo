//! `iter`: the golden vectors of `HexSpanExt` (`crates/hexx/src/hex/iter.cairo`), the counterpart of
//! `hexx`'s `HexIterExt` (`src/hex/iter.rs:4`): `average`, `center` and `bounds` on the empty span,
//! one point, the `points` seeded points, `spans` seeded spans of `1..=span_max` points of
//! `[-span_domain, span_domain]²` and triangles (the `trio_size` branch of `FromIterator<Hex>`,
//! `src/bounds.rs:161-230`), as one table: the spans flat, their lengths, and per span the
//! expected centre, radius and average.
//!
//! `average` is `sum / count` with `hexx`'s `Div<i32>`, which the port computes exactly
//! (`div_scalar`, brief LIB-06 M2-T3): a span where `hexx`'s `f32` result differs from the exact
//! rule is not dropped, the test expects the port's (`impls::exact`) and the generated file lists
//! `hexx`'s value in a comment.

use std::path::{Path, PathBuf};

use hexx::{Hex, HexBounds, HexIterExt};

use crate::cairo::{probe, seeded_points, Emitter, Rng};
use crate::impls::{cases_array, exact, hx};
use crate::spec::Spec;

/// The spans of the table, in order: the empty one, one point, the seeded points, the seeded spans,
/// the triangles. Read by the generator of `bounds` too (`from_span`): both specs hold the same
/// `seed`, `points`, `domain_*`, `spans`, `span_*` keys.
pub fn span_sets(spec: &Spec) -> Result<Vec<Vec<(i32, i32)>>, String> {
    let seed = spec.text("seed")?;
    let (min, max) = (spec.int("domain_min")? as i32, spec.int("domain_max")? as i32);
    let points = seeded_points(&seed, spec.int("points")? as usize, min, max);
    let (domain, longest) = (spec.int("span_domain")? as i32, spec.int("span_max")? as i32);
    let mut rng = Rng::new(&format!("{seed}::spans"));
    let mut sets = vec![vec![], vec![points[0]], points.clone()];
    for _ in 0..spec.int("spans")? {
        let count = rng.next_i32(1, longest);
        sets.push((0..count).map(|_| (rng.next_i32(-domain, domain), rng.next_i32(-domain, domain))).collect());
    }
    // The filled triangles `x, y >= 0, x + y <= side` and their opposites, offset by a seeded point
    for (n, side) in [1, 2, 3, 4, 5, 6, 7, 9].into_iter().enumerate() {
        let (ox, oy) = (rng.next_i32(-10, 10), rng.next_i32(-10, 10));
        let sign = if n % 2 == 0 { 1 } else { -1 };
        let mut triangle = Vec::new();
        for x in 0..=side {
            for y in 0..=(side - x) {
                triangle.push((ox + sign * x, oy + sign * y));
            }
        }
        sets.push(triangle);
    }
    Ok(sets)
}

fn hexes(span: &[(i32, i32)]) -> Vec<Hex> {
    span.iter().map(|&p| hx(p)).collect()
}

/// `hexx`'s `HexBounds` of the span, `None` where it panics.
pub fn hexx_bounds(span: &[(i32, i32)]) -> Option<HexBounds> {
    probe(|| hexes(span).into_iter().bounds())
}

/// `hexx`'s average and the port's (the exact rule), `None` where it panics.
fn averages(span: &[(i32, i32)]) -> Option<((i32, i32), (i32, i32))> {
    let theirs = probe(|| {
        let a = hexes(span).into_iter().average();
        (a.x, a.y)
    })?;
    let (mut sx, mut sy) = (0_i32, 0_i32);
    for &(x, y) in span {
        sx = sx.checked_add(x)?;
        sy = sy.checked_add(y)?;
    }
    let ours = exact::div_scalar(sx, sy, (span.len() as i32).max(1))?;
    Some((theirs, ours))
}

pub fn emit(spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    let sets = span_sets(spec)?;
    let mut lens = Vec::new();
    let mut flat = Vec::new();
    let mut rows = Vec::new();
    let mut deviations = Vec::new();
    for (n, span) in sets.iter().enumerate() {
        let bounds = hexx_bounds(span).ok_or("hexx panics on a seeded span")?;
        let (theirs, ours) = averages(span).ok_or("hexx panics on the average of a seeded span")?;
        if theirs != ours {
            deviations.push(format!("span {n} ({} points): hexx {theirs:?}, port {ours:?}", span.len()));
        }
        lens.push(format!("{}", span.len()));
        flat.extend(span.iter().map(|&(x, y)| format!("{x}, {y}")));
        rows.push(format!(
            "{}, {}, {}, {}, {}",
            bounds.center.x, bounds.center.y, bounds.radius, ours.0, ours.1
        ));
    }
    let mut e = Emitter::new(
        spec,
        "`HexIterExt::average`, `center`, `bounds` (src/hex/iter.rs:17, :31, :46)",
        "use hexx::hex::HexTrait;\nuse hexx::hex::iter::HexSpanExt;\n",
    );
    let note = if deviations.is_empty() {
        "// `average`: the port's result equals `hexx`'s on every span.\n".to_string()
    } else {
        let mut text = String::from(
            "// `average`: the spans where `hexx`'s `f32` result differs from the exact rule of the\n\
             // port (`div_scalar`, docs/deviations/div_scalar.md); the table holds the port's.\n",
        );
        for line in &deviations {
            text.push_str(&format!("// - {line}\n"));
        }
        text
    };
    e.out.push_str(&note);
    let body = format!(
        "{}{}{}{}",
        crate::bounds::scalar_array("lens", "u32", &lens),
        cases_array("(i32, i32)", &flat).replacen("let cases", "let points", 1),
        cases_array("(i32, i32, u32, i32, i32)", &rows).replacen("let cases", "let expected", 1),
        "    let mut k = 0;
    let mut i = 0;
    while i < lens.len() {
        let mut built = array![];
        let mut j = 0;
        while j < *lens.at(i) {
            let (x, y) = *points.at(k);
            built.append(HexTrait::new(x, y));
            k += 1;
            j += 1;
        }
        let span = built.span();
        let (cx, cy, r, ax, ay) = *expected.at(i);
        let bounds = span.bounds();
        assert(bounds.center == HexTrait::new(cx, cy) && bounds.radius == r, 'bounds');
        assert(span.center() == HexTrait::new(cx, cy), 'center');
        assert(span.average() == HexTrait::new(ax, ay), 'average');
        i += 1;
    }
    assert(k == points.len(), 'points');
",
    );
    e.test("golden_iter_spans", false, &body)?;
    Ok(vec![(crate::target(root, spec), e.finish()?)])
}
