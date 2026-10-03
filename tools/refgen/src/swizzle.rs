//! `swizzle`: the swizzles of `Hex` (`src/hex/swizzle.rs`), `xx`, `yy`, `zz`, `yx`, `yz`, `xz`,
//! `zx`, `zy`, on the seeded points of `[domain_min, domain_max]²` and near the bounds (the ones
//! that read `z` panic where `z` does: `#[should_panic]` tests, at most `panic_cap` per swizzle).

use std::path::{Path, PathBuf};

use crate::cairo::{bound_points, probe, seeded_points, Emitter};
use crate::impls::{fun_tables, hex_row, hx, pair, Fun};
use crate::spec::Spec;

macro_rules! swizzles {
    ($($name:ident),* $(,)?) => {
        [$(Fun {
            name: stringify!($name),
            types: "i32, i32",
            vars: "x, y",
            setup: "        let h = HexTrait::new(x, y);\n",
            call: concat!("h.", stringify!($name), "()"),
            out_types: "i32, i32",
            out_vars: "ex, ey",
            expected: "HexTrait::new(ex, ey)",
            eval: |p| probe(|| hx(p).$name()).map(pair),
            row: hex_row,
        }),*]
    };
}

fn swizzle_funs() -> [Fun<(i32, i32)>; 8] {
    swizzles![xx, yy, zz, yx, yz, xz, zx, zy]
}

pub fn emit(spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    let points = seeded_points(
        &spec.text("seed")?,
        spec.int("points")? as usize,
        spec.int("domain_min")? as i32,
        spec.int("domain_max")? as i32,
    );
    let panic_cap = spec.int("panic_cap")? as usize;
    let mut e = Emitter::new(
        spec,
        "the swizzles of `Hex` (src/hex/swizzle.rs), `xx` :17, `yy` :34, `zz` :51,\n// `yx` :68, `yz` :88, `xz` :108, `zx` :128, `zy` :148",
        "use hexx::hex::HexTrait;\nuse hexx::hex::swizzle::HexSwizzleTrait;\n",
    );
    let funs = swizzle_funs();
    fun_tables(&mut e, "swizzle", "unary", &points, &funs, None)?;
    // Near the bounds: the swizzles without `z` never panic, so their tables stand alone.
    let bounds = bound_points();
    let (with_z, without_z): (Vec<_>, Vec<_>) = funs.into_iter().partition(|f| f.name.contains('z'));
    fun_tables(&mut e, "swizzle", "bounds", &bounds, &with_z, Some(panic_cap))?;
    fun_tables(&mut e, "swizzle", "bounds", &bounds, &without_z, None)?;
    let golden = root.join("crates").join("hexx").join("tests").join("golden_swizzle.cairo");
    Ok(vec![(golden, e.finish()?)])
}
