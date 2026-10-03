//! `euclidean`: `squared_euclidean_length` and `squared_euclidean_distance_to`
//! (`src/hex/euclidean.rs:20`, `:65`) on the seeded points of `[domain_min, domain_max]²` and every
//! ordered pair of them (`chunks` tests), then near the bounds: the values of `BOUND_VALUES²`, the
//! points where `x² + y²` leaves `i32` although the total `x² + y² + x·y` would not (`hexx` panics
//! there in a debug build, at the partial sum), and the pairs of `BOUND_PAIR_POINTS`.

use std::path::{Path, PathBuf};

use crate::cairo::{bound_points, probe, seeded_points, Emitter};
use crate::impls::{fun_tables, hex_row, hx, Fun, BOUND_PAIR_POINTS};
use crate::spec::Spec;

fn pair_row(p: ((i32, i32), (i32, i32))) -> String {
    format!("{}, {}", hex_row(p.0), hex_row(p.1))
}

const LENGTH: [Fun<(i32, i32)>; 1] = [Fun {
    name: "squared_euclidean_length",
    types: "i32, i32",
    vars: "x, y",
    setup: "        let h = HexTrait::new(x, y);\n",
    call: "h.squared_euclidean_length()",
    out_types: "i32",
    out_vars: "e",
    expected: "e",
    eval: |p| probe(|| hx(p).squared_euclidean_length()).map(|v| vec![v.to_string()]),
    row: hex_row,
}];

const DISTANCE: [Fun<((i32, i32), (i32, i32))>; 1] = [Fun {
    name: "squared_euclidean_distance_to",
    types: "i32, i32, i32, i32",
    vars: "x1, y1, x2, y2",
    setup: "        let a = HexTrait::new(x1, y1);\n        let b = HexTrait::new(x2, y2);\n",
    call: "a.squared_euclidean_distance_to(b)",
    out_types: "i32",
    out_vars: "e",
    expected: "e",
    eval: |p| probe(|| hx(p.0).squared_euclidean_distance_to(hx(p.1))).map(|v| vec![v.to_string()]),
    row: pair_row,
}];

/// Points where `x² + y²` leaves `i32` while `x² + y² + x·y` is in range, and their neighbours.
const PARTIAL: [(i32, i32); 8] = [
    (40_000, -40_000),
    (-40_000, 40_000),
    (46_340, -46_340),
    (32_768, -32_768),
    (32_767, -32_768),
    (46_340, 0),
    (46_341, 0),
    (0, -46_341),
];

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
        return Err("specs/euclidean.toml: `points` is not a multiple of `chunks`".into());
    }
    let mut e = Emitter::new(
        spec,
        "`Hex::squared_euclidean_length` (src/hex/euclidean.rs:20),\n// `Hex::squared_euclidean_distance_to` :65",
        "use hexx::hex::HexTrait;\nuse hexx::hex::euclidean::HexEuclideanTrait;\n",
    );
    fun_tables(&mut e, "euclidean", "unary", &points, &LENGTH, None)?;
    let per_chunk = points.len() / chunks;
    for chunk in 0..chunks {
        let pairs: Vec<_> = points[chunk * per_chunk..(chunk + 1) * per_chunk]
            .iter()
            .flat_map(|&a| points.iter().map(move |&b| (a, b)))
            .collect();
        fun_tables(&mut e, "euclidean", &format!("pairs_{chunk}"), &pairs, &DISTANCE, None)?;
    }
    let mut bounds = bound_points();
    bounds.extend(PARTIAL);
    for &p in &PARTIAL {
        let total = i64::from(p.0).pow(2) + i64::from(p.1).pow(2) + i64::from(p.0) * i64::from(p.1);
        if i64::from(p.0).pow(2) + i64::from(p.1).pow(2) > i64::from(i32::MAX)
            && total <= i64::from(i32::MAX)
            && probe(|| hx(p).squared_euclidean_length()).is_some()
        {
            return Err(format!("hexx returns on a partial overflow: {p:?}"));
        }
    }
    fun_tables(&mut e, "euclidean", "bounds", &bounds, &LENGTH, Some(panic_cap))?;
    // The partial sum `x² + y²` leaves `i32` although the total would not: `hexx` panics there.
    let body = "    let _ = HexTrait::new(40000, -40000).squared_euclidean_length();\n";
    e.test("golden_euclidean_partial_sum_panics", true, body)?;
    let mut bound_points_2 = BOUND_PAIR_POINTS.to_vec();
    bound_points_2.extend(PARTIAL);
    let bound_pairs: Vec<_> = bound_points_2
        .iter()
        .flat_map(|&a| bound_points_2.iter().map(move |&b| (a, b)))
        .collect();
    fun_tables(&mut e, "euclidean", "bounds", &bound_pairs, &DISTANCE, Some(panic_cap))?;
    let golden = root.join("crates").join("hexx").join("tests").join("golden_euclidean.cairo");
    Ok(vec![(golden, e.finish()?)])
}
