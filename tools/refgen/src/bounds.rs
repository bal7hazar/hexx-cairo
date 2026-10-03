//! `bounds`: the golden vectors of `crates/hexx/src/bounds.cairo` (`src/bounds.rs`), brief LIB-06
//! M2-T5, Scope 3. Every item at the radii `0..=6` around `centers` centres (the origin and
//! seeded ones), one test per radius for the items that return a span, a hexagon or a bit per
//! probe:
//!
//! - `all_coords`, `corners`: the expected span, flat, for the centres in order;
//! - `is_in_bounds`: `near` probes (seeded offsets of `[-near, near]²` from each centre), the
//!   answers as the bits of one `u64` per centre;
//! - `wrap`, `wrap_local`: `points` seeded points of `[domain_min, domain_max]²` per bounds;
//! - `hex_count`, `hex_count32`, `positive_radius`, `new`, `from_radius`: tables;
//! - `from_min_max` on every ordered pair of `min_max_points` seeded points: `(min + max) / 2` is
//!   `hexx`'s `Div<i32>`, which the port computes exactly (`div_scalar`): a pair where `hexx`'s
//!   `f32` result differs from the exact rule is not dropped, the table expects the port's value
//!   and the generated file lists `hexx`'s in a comment;
//! - `intersecting_with` on every ordered pair of 8 bounds (`inter_radii`, equal radii included);
//! - `from_span` on the spans of `iter::span_sets` (the same inputs as `HexSpanExt`).

use std::path::{Path, PathBuf};

use hexx::{Hex, HexBounds};

use crate::cairo::{probe, seeded_points, Emitter};
use crate::impls::{cases_array, exact, hx};
use crate::iter::{hexx_bounds, span_sets};
use crate::spec::Spec;

/// `let name: Array<ty> = array![...];` of scalars, as `scarb fmt` prints it: on one line when it
/// fits in 100 columns, else packed, as many per line as fit.
pub fn scalar_array(name: &str, ty: &str, values: &[String]) -> String {
    let one = format!("    let {name}: Array<{ty}> = array![{}];\n", values.join(", "));
    if one.len() <= 101 {
        return one;
    }
    let mut out = format!("    let {name}: Array<{ty}> = array![\n");
    let mut line = String::new();
    for value in values {
        if !line.is_empty() && line.len() + 1 + value.len() + 1 > 100 - 8 {
            out.push_str(&format!("        {line}\n"));
            line.clear();
        }
        if !line.is_empty() {
            line.push(' ');
        }
        line.push_str(&format!("{value},"));
    }
    out.push_str(&format!("        {line}\n    ];\n"));
    out
}

fn tuples(name: &str, types: &str, rows: &[String]) -> String {
    cases_array(types, rows).replacen("let cases", &format!("let {name}"), 1)
}

fn pair(h: Hex) -> String {
    format!("{}, {}", h.x, h.y)
}

fn row(p: (i32, i32)) -> String {
    format!("{}, {}", p.0, p.1)
}

/// A span-valued item, one test per radius: `call` builds the span from `bounds`.
fn span_test(
    e: &mut Emitter,
    name: &str,
    radius: u32,
    centers: &[(i32, i32)],
    expected: &[(i32, i32)],
    count: usize,
    call: &str,
) -> Result<(), String> {
    let rows: Vec<String> = centers.iter().map(|&c| row(c)).collect();
    let body = format!(
        "{}{}    let mut k = 0;
    let mut c = 0;
    while c < centers.len() {{
        let (cx, cy) = *centers.at(c);
        let bounds = HexBoundsTrait::new(HexTrait::new(cx, cy), {radius});
        let mut got = {call};
        assert(got.len() == {count}, 'len');
        while let Some(h) = got.pop_front() {{
            let (ex, ey) = *expected.at(k);
            assert(*h == HexTrait::new(ex, ey), '{name}');
            k += 1;
        }}
        c += 1;
    }}
    assert(k == expected.len(), 'count');
",
        tuples("centers", "i32, i32", &rows),
        tuples("expected", "i32, i32", &expected.iter().map(|&p| row(p)).collect::<Vec<_>>()),
    );
    e.test(&format!("golden_bounds_{name}_r{radius}"), false, &body)
}

/// A hexagon-valued item on seeded points, one test per radius.
fn point_test(
    e: &mut Emitter,
    name: &str,
    radius: u32,
    centers: &[(i32, i32)],
    points: &[(i32, i32)],
    expected: &[(i32, i32)],
) -> Result<(), String> {
    let rows: Vec<String> = centers.iter().map(|&c| row(c)).collect();
    let body = format!(
        "{}{}{}    let mut c = 0;
    while c < centers.len() {{
        let (cx, cy) = *centers.at(c);
        let bounds = HexBoundsTrait::new(HexTrait::new(cx, cy), {radius});
        let mut j = 0;
        while j < points.len() {{
            let (px, py) = *points.at(j);
            let (ex, ey) = *expected.at(c * points.len() + j);
            assert(bounds.{name}(HexTrait::new(px, py)) == HexTrait::new(ex, ey), '{name}');
            j += 1;
        }}
        c += 1;
    }}
",
        tuples("centers", "i32, i32", &rows),
        tuples("points", "i32, i32", &points.iter().map(|&p| row(p)).collect::<Vec<_>>()),
        tuples("expected", "i32, i32", &expected.iter().map(|&p| row(p)).collect::<Vec<_>>()),
    );
    e.test(&format!("golden_bounds_{name}_r{radius}"), false, &body)
}

fn bounds_of(c: (i32, i32), radius: u32) -> HexBounds {
    HexBounds::new(hx(c), radius)
}

pub fn emit(spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    let seed = spec.text("seed")?;
    let max_radius = spec.int("radius_max")? as u32;
    let mut centers = vec![(0, 0)];
    centers.extend(seeded_points(
        &format!("{seed}::centers"),
        spec.int("centers")? as usize - 1,
        spec.int("center_min")? as i32,
        spec.int("center_max")? as i32,
    ));
    let (min, max) = (spec.int("domain_min")? as i32, spec.int("domain_max")? as i32);
    let wrap_points = seeded_points(&format!("{seed}::wrap"), spec.int("wrap_points")? as usize, min, max);
    let near = spec.int("near")? as i32;
    let probes = seeded_points(&format!("{seed}::near"), spec.int("near_points")? as usize, -near, near);
    if probes.len() > 64 {
        return Err("specs/bounds.toml: `near_points` above 64 does not fit a u64".into());
    }
    let mut e = Emitter::new(
        spec,
        "`HexBounds` (src/bounds.rs:36-230) and `FromIterator<Hex>` (:161)",
        "use hexx::hex::HexTrait;\nuse hexx::{HexBounds, HexBoundsTrait};\n",
    );

    // new, from_radius, positive_radius, hex_count, hex_count32
    let mut rows = Vec::new();
    for radius in 0..=max_radius {
        for &c in &centers {
            let b = bounds_of(c, radius);
            let from_radius = HexBounds::from_radius(radius);
            if (from_radius.center != Hex::ZERO) || b.center != hx(c) || b.radius != radius {
                return Err("hexx's constructors differ from the fields".into());
            }
            rows.push(format!("{}, {radius}", row(c)));
        }
    }
    let body = format!(
        "{}    let mut i = 0;
    while i < cases.len() {{
        let (x, y, r) = *cases.at(i);
        let bounds = HexBoundsTrait::new(HexTrait::new(x, y), r);
        assert(bounds.center == HexTrait::new(x, y) && bounds.radius == r, 'new');
        assert(
            HexBoundsTrait::from_radius(r) == HexBoundsTrait::new(HexTrait::ZERO, r), 'from_radius',
        );
        i += 1;
    }}
",
        cases_array("i32, i32, u32", &rows)
    );
    e.test("golden_bounds_constructors", false, &body)?;

    let radii: Vec<u32> = (0..=max_radius).chain([64, 100, 1000, 37_836]).collect();
    let rows: Vec<String> = radii
        .iter()
        .map(|&r| format!("{r}, {}, {}", HexBounds::from_radius(r).hex_count32(), HexBounds::from_radius(r).hex_count()))
        .collect();
    let body = format!(
        "{}    let mut i = 0;
    while i < cases.len() {{
        let (r, n32, n) = *cases.at(i);
        let bounds = HexBoundsTrait::from_radius(r);
        assert(bounds.hex_count32() == n32, 'hex_count32');
        assert(bounds.hex_count() == n, 'hex_count');
        i += 1;
    }}
",
        cases_array("u32, u32, usize", &rows)
    );
    e.test("golden_bounds_hex_count", false, &body)?;
    // `Hex::range_count` leaves `u32` above 37,836: `hexx` panics in a debug build
    if probe(|| HexBounds::from_radius(37_837).hex_count32()).is_some() {
        return Err("hexx does not panic at radius 37837".into());
    }
    e.test(
        "golden_bounds_hex_count_overflow",
        true,
        "    let _ = HexBoundsTrait::from_radius(37837).hex_count32();\n",
    )?;

    let radii: Vec<u32> = (0..=max_radius).chain([64, 100, 1000, i32::MAX as u32]).collect();
    let rows: Vec<String> = radii
        .iter()
        .map(|&r| {
            let b = HexBounds::positive_radius(r);
            format!("{r}, {}, {}", b.center.x, b.center.y)
        })
        .collect();
    let body = format!(
        "{}    let mut i = 0;
    while i < cases.len() {{
        let (r, x, y) = *cases.at(i);
        let bounds = HexBoundsTrait::positive_radius(r);
        assert(bounds.center == HexTrait::new(x, y) && bounds.radius == r, 'positive_radius');
        i += 1;
    }}
",
        cases_array("u32, i32, i32", &rows)
    );
    e.test("golden_bounds_positive_radius", false, &body)?;
    // `hexx` casts the radius with `as` and wraps; the port panics above `i32::MAX` (Deviations)
    e.test(
        "golden_bounds_positive_radius_above_i32",
        true,
        "    let _ = HexBoundsTrait::positive_radius(2147483648);\n",
    )?;

    // The span-valued, point-valued and mask items, per radius
    for radius in 0..=max_radius {
        let count = HexBounds::from_radius(radius).hex_count();
        let coords: Vec<(i32, i32)> = centers
            .iter()
            .flat_map(|&c| bounds_of(c, radius).all_coords().map(|h| (h.x, h.y)).collect::<Vec<_>>())
            .collect();
        span_test(&mut e, "all_coords", radius, &centers, &coords, count, "bounds.all_coords()")?;
        let corners: Vec<(i32, i32)> = centers
            .iter()
            .flat_map(|&c| bounds_of(c, radius).corners().map(|h| (h.x, h.y)))
            .collect();
        span_test(&mut e, "corners", radius, &centers, &corners, 6, "bounds.corners().span()")?;

        let masks: Vec<String> = centers
            .iter()
            .map(|&c| {
                let b = bounds_of(c, radius);
                let mask = probes.iter().enumerate().fold(0_u64, |m, (j, &(ox, oy))| {
                    m | (u64::from(b.is_in_bounds(Hex::new(c.0 + ox, c.1 + oy))) << j)
                });
                mask.to_string()
            })
            .collect();
        let body = format!(
            "{}{}{}    let mut c = 0;
    while c < centers.len() {{
        let (cx, cy) = *centers.at(c);
        let bounds = HexBoundsTrait::new(HexTrait::new(cx, cy), {radius});
        let mut mask = *masks.at(c);
        let mut j = 0;
        while j < probes.len() {{
            let (ox, oy) = *probes.at(j);
            let inside = bounds.is_in_bounds(HexTrait::new(cx + ox, cy + oy));
            assert(inside == (mask % 2 == 1), 'is_in_bounds');
            mask /= 2;
            j += 1;
        }}
        c += 1;
    }}
",
            tuples("centers", "i32, i32", &centers.iter().map(|&p| row(p)).collect::<Vec<_>>()),
            tuples("probes", "i32, i32", &probes.iter().map(|&p| row(p)).collect::<Vec<_>>()),
            scalar_array("masks", "u64", &masks),
        );
        e.test(&format!("golden_bounds_is_in_bounds_r{radius}"), false, &body)?;

        let eval = |local: bool| -> Result<Vec<(i32, i32)>, String> {
            let mut out = Vec::new();
            for &c in &centers {
                for &p in &wrap_points {
                    let b = bounds_of(c, radius);
                    let h = probe(|| if local { b.wrap_local(hx(p)) } else { b.wrap(hx(p)) })
                        .ok_or("hexx panics on a seeded wrap")?;
                    out.push((h.x, h.y));
                }
            }
            Ok(out)
        };
        point_test(&mut e, "wrap", radius, &centers, &wrap_points, &eval(false)?)?;
        point_test(&mut e, "wrap_local", radius, &centers, &wrap_points, &eval(true)?)?;
    }

    // from_min_max on every ordered pair of seeded points
    let pts = seeded_points(&format!("{seed}::min_max"), spec.int("min_max_points")? as usize, min, max);
    let (mut rows, mut deviating) = (Vec::new(), Vec::new());
    for &a in &pts {
        for &b in &pts {
            let theirs = probe(|| HexBounds::from_min_max(hx(a), hx(b))).ok_or("hexx panics on from_min_max")?;
            let (sx, sy) = (a.0 + b.0, a.1 + b.1);
            let (cx, cy) = exact::div_scalar(sx, sy, 2).ok_or("the exact rule panics on from_min_max")?;
            let radius = hx((cx, cy)).unsigned_distance_to(hx(b));
            if (theirs.center.x, theirs.center.y) != (cx, cy) {
                deviating.push(format!(
                    "min {a:?} max {b:?}: hexx ({}, {}) radius {}, port ({cx}, {cy}) radius {radius}",
                    theirs.center.x, theirs.center.y, theirs.radius
                ));
            } else if theirs.radius != radius {
                return Err("from_min_max: same centre, different radius".into());
            }
            rows.push(format!("{}, {}, {cx}, {cy}, {radius}", row(a), row(b)));
        }
    }
    if deviating.is_empty() {
        e.out.push_str(&format!(
            "\n// `from_min_max`: 0 of the {} pairs hit a deviation of `div_scalar`.\n",
            rows.len()
        ));
    } else {
        e.out.push_str(&format!(
            "\n// `from_min_max`: {} of the {} pairs hit a deviation of `div_scalar` (`(min + max) / 2` is\n\
             // `hexx`'s `f32` `Div<i32>`, docs/deviations/div_scalar.md); the table holds the port's:\n",
            deviating.len(),
            rows.len()
        ));
        for line in &deviating {
            e.out.push_str(&format!("// - {line}\n"));
        }
    }
    let body = format!(
        "{}    let mut i = 0;
    while i < cases.len() {{
        let (ax, ay, bx, by, cx, cy, r) = *cases.at(i);
        let bounds = HexBoundsTrait::from_min_max(HexTrait::new(ax, ay), HexTrait::new(bx, by));
        assert(bounds.center == HexTrait::new(cx, cy) && bounds.radius == r, 'from_min_max');
        i += 1;
    }}
",
        cases_array("i32, i32, i32, i32, i32, i32, u32", &rows)
    );
    e.test("golden_bounds_from_min_max", false, &body)?;

    // intersecting_with on every ordered pair of 8 bounds
    let radii: Vec<u32> = spec
        .text("inter_radii")?
        .split(',')
        .map(|r| r.trim().parse().map_err(|_| "bad `inter_radii`".to_string()))
        .collect::<Result<_, _>>()?;
    let inter_centers = seeded_points(&format!("{seed}::inter"), radii.len(), -spec.int("inter_domain")? as i32, spec.int("inter_domain")? as i32);
    let all: Vec<HexBounds> = inter_centers.iter().zip(&radii).map(|(&c, &r)| bounds_of(c, r)).collect();
    let (mut counts, mut flat) = (Vec::new(), Vec::new());
    for a in &all {
        for b in &all {
            let hexes: Vec<Hex> = a.intersecting_with(*b).collect();
            counts.push(hexes.len().to_string());
            flat.extend(hexes.iter().map(|h| pair(*h)));
        }
    }
    let bounds_rows: Vec<String> = all.iter().map(|b| format!("{}, {}, {}", b.center.x, b.center.y, b.radius)).collect();
    let body = format!(
        "{}{}{}{}    let mut k = 0;
    let mut n = 0;
    let mut a = 0;
    while a < all.len() {{
        let (ax, ay, ar) = *all.at(a);
        let mut b = 0;
        while b < all.len() {{
            let (bx, by, br) = *all.at(b);
            let first = HexBoundsTrait::new(HexTrait::new(ax, ay), ar);
            let second = HexBoundsTrait::new(HexTrait::new(bx, by), br);
            let mut got = first.intersecting_with(second);
            assert(got.len() == *counts.at(n), 'len');
            while let Some(h) = got.pop_front() {{
                let (ex, ey) = *expected.at(k);
                assert(*h == HexTrait::new(ex, ey), 'intersecting_with');
                k += 1;
            }}
            n += 1;
            b += 1;
        }}
        a += 1;
    }}
    assert(k == expected.len(), 'count');
",
        tuples("all", "i32, i32, u32", &bounds_rows),
        scalar_array("counts", "u32", &counts),
        tuples("expected", "i32, i32", &flat),
        "",
    );
    e.test("golden_bounds_intersecting_with", false, &body)?;

    // from_span on the spans of the `HexSpanExt` table
    let sets = span_sets(spec)?;
    let (mut lens, mut flat, mut rows) = (Vec::new(), Vec::new(), Vec::new());
    for span in &sets {
        let b = hexx_bounds(span).ok_or("hexx panics on a seeded span")?;
        lens.push(span.len().to_string());
        flat.extend(span.iter().map(|&p| row(p)));
        rows.push(format!("{}, {}, {}", b.center.x, b.center.y, b.radius));
    }
    let body = format!(
        "{}{}{}    let mut k = 0;
    let mut i = 0;
    while i < lens.len() {{
        let mut built = array![];
        let mut j = 0;
        while j < *lens.at(i) {{
            let (x, y) = *points.at(k);
            built.append(HexTrait::new(x, y));
            k += 1;
            j += 1;
        }}
        let (cx, cy, r) = *expected.at(i);
        let bounds = HexBoundsTrait::from_span(built.span());
        assert(bounds.center == HexTrait::new(cx, cy) && bounds.radius == r, 'from_span');
        i += 1;
    }}
    assert(k == points.len(), 'points');
",
        scalar_array("lens", "u32", &lens),
        tuples("points", "i32, i32", &flat),
        tuples("expected", "i32, i32, u32", &rows),
    );
    e.test("golden_bounds_from_span", false, &body)?;

    Ok(vec![(crate::target(root, spec), e.finish()?)])
}
