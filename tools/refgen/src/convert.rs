//! `convert`: the `u64` packing of `Hex` (`src/hex/convert.rs:76`, `:99`) and the conversions from
//! an `i32` pair (`From<(i32, i32)>` `:4`, `From<[i32; 2]>` `:11`, Cairo's `Into`): `as_u64` and
//! both conversions on the seeded points of `[domain_min, domain_max]²` and on `BOUND_VALUES²`
//! (negative halves included), `from_u64` on the same packings and on `values` seeded `u64`.
//! None of them panics.

use std::path::{Path, PathBuf};

use hexx::Hex;

use crate::cairo::{bound_points, probe, seeded_points, Emitter, Rng};
use crate::impls::{fun_tables, hex_row, hx, pair, Fun};
use crate::spec::Spec;

const PACKING: [Fun<(i32, i32)>; 3] = [
    Fun {
        name: "as_u64",
        types: "i32, i32",
        vars: "x, y",
        setup: "        let h = HexTrait::new(x, y);\n",
        call: "(h.as_u64(), HexConvertTrait::from_u64(h.as_u64()))",
        out_types: "u64",
        out_vars: "e",
        expected: "(e, h)",
        eval: |p| probe(|| hx(p).as_u64()).map(|v| vec![v.to_string()]),
        row: hex_row,
    },
    Fun {
        name: "from_tuple",
        types: "i32, i32",
        vars: "x, y",
        setup: "        let h: Hex = (x, y).into();\n",
        call: "h",
        out_types: "i32, i32",
        out_vars: "ex, ey",
        expected: "HexTrait::new(ex, ey)",
        eval: |p| probe(|| Hex::from(p)).map(pair),
        row: hex_row,
    },
    Fun {
        name: "from_array",
        types: "i32, i32",
        vars: "x, y",
        setup: "        let h: Hex = [x, y].into();\n",
        call: "h",
        out_types: "i32, i32",
        out_vars: "ex, ey",
        expected: "HexTrait::new(ex, ey)",
        eval: |p| probe(|| Hex::from([p.0, p.1])).map(pair),
        row: hex_row,
    },
];

const UNPACKING: [Fun<u64>; 1] = [Fun {
    name: "from_u64",
    types: "u64",
    vars: "v",
    setup: "        let h = HexConvertTrait::from_u64(v);\n",
    call: "(h, h.as_u64())",
    out_types: "i32, i32",
    out_vars: "ex, ey",
    expected: "(HexTrait::new(ex, ey), v)",
    eval: |v| probe(|| Hex::from_u64(v)).map(pair),
    row: |v| v.to_string(),
}];

pub fn emit(spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    let points = seeded_points(
        &spec.text("seed")?,
        spec.int("points")? as usize,
        spec.int("domain_min")? as i32,
        spec.int("domain_max")? as i32,
    );
    let mut e = Emitter::new(
        spec,
        "`From<(i32, i32)> for Hex` (src/hex/convert.rs:4), `From<[i32; 2]> for Hex`\n// :11, `Hex::from_u64` :76, `Hex::as_u64` :99",
        "use hexx::hex::convert::{HexConvertTrait, HexFromArray, HexFromTuple};\nuse hexx::hex::{Hex, HexTrait};\n",
    );
    let bounds = bound_points();
    fun_tables(&mut e, "convert", "unary", &points, &PACKING, None)?;
    fun_tables(&mut e, "convert", "bounds", &bounds, &PACKING, None)?;
    // `from_u64` on the packings of the points and of the bounds, and on seeded `u64` values,
    // with the extremes of `u64` and of each half.
    let mut rng = Rng::new(&spec.text("seed_u64")?);
    let mut values: Vec<u64> = points.iter().chain(bounds.iter()).map(|&p| hx(p).as_u64()).collect();
    values.extend((0..spec.int("values")?).map(|_| {
        let high = rng.next_i32(i32::MIN, i32::MAX - 1) as u32;
        let low = rng.next_i32(i32::MIN, i32::MAX - 1) as u32;
        (u64::from(high) << 32) | u64::from(low)
    }));
    values.extend([0, u64::MAX, 0x7fff_ffff_7fff_ffff, 0x8000_0000_8000_0000, 0xffff_ffff, 0xffff_ffff_0000_0000]);
    values.sort_unstable();
    values.dedup();
    fun_tables(&mut e, "convert", "values", &values, &UNPACKING, None)?;
    let golden = crate::target(root, spec);
    Ok(vec![(golden, e.finish()?)])
}
