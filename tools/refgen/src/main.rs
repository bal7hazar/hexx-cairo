//! `refgen`: golden-vector generator. `hexx` 0.25.0 is the oracle of the Cairo port (plan §4.3).
//!
//! ```text
//! cargo run --manifest-path tools/refgen/Cargo.toml -- gen [module]     # write the file(s)
//! cargo run --manifest-path tools/refgen/Cargo.toml -- check [module]   # CI: exit 1 on drift
//! ```
//!
//! Dependency-free by design (no `toml`/`serde`, mirroring the Python scripts' own house rule):
//! `specs/*.toml` here is a deliberately small, flat format (`key = value` lines, no nesting),
//! parsed by `spec::load` without an external crate.

mod algorithms;
mod bounds;
mod cairo;
mod conversions;
mod convert;
mod direction;
mod euclidean;
mod fov;
mod grid;
mod hex;
mod hexagon;
mod impls;
mod iter;
mod line;
mod rings;
mod shapes;
mod spec;
mod swizzle;

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use spec::Spec;

const USAGE: &str = "usage: refgen [--root <repo>] [--specs <dir>] <gen|check> [module]";

fn default_specs_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("specs")
}

fn default_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join("..")
}

/// `crates/<package>/tests/golden_<module>.cairo`: an integration test of the package (Scarb
/// bundles every `.cairo` file directly under a package's `tests/` into one
/// `<package>_integrationtest` target, no `tests/lib.cairo` needed, `tools/refgen/README.md`).
fn target(root: &Path, spec: &Spec) -> PathBuf {
    root.join("crates")
        .join(&spec.package)
        .join("tests")
        .join(format!("golden_{}.cairo", spec.module))
}

fn load_specs(dir: &Path, filter: &[String]) -> Result<Vec<Spec>, String> {
    let mut paths: Vec<PathBuf> = fs::read_dir(dir)
        .map_err(|e| format!("{}: {e}", dir.display()))?
        .filter_map(|entry| entry.ok().map(|e| e.path()))
        .filter(|p| p.extension().is_some_and(|e| e == "toml"))
        .collect();
    paths.sort();
    let specs: Result<Vec<Spec>, String> = paths.iter().map(|p| Spec::load(p)).collect();
    let mut specs = specs?;
    for module in filter {
        if !specs.iter().any(|s| &s.module == module) {
            return Err(format!("no spec {}/{module}.toml", dir.display()));
        }
    }
    if !filter.is_empty() {
        specs.retain(|s| filter.contains(&s.module));
    }
    Ok(specs)
}

fn run() -> Result<bool, String> {
    let mut args: Vec<String> = env::args().skip(1).collect();
    let mut root = default_root();
    let mut specs_dir = default_specs_dir();
    loop {
        match args.first().map(String::as_str) {
            Some("--specs") if args.len() >= 2 => {
                specs_dir = PathBuf::from(args[1].clone());
                args.drain(..2);
            }
            Some("--root") if args.len() >= 2 => {
                root = PathBuf::from(args[1].clone());
                args.drain(..2);
            }
            _ => break,
        }
    }
    let Some(command) = args.first().cloned() else {
        return Err(USAGE.into());
    };
    let modules = &args[1..];
    let specs = load_specs(&specs_dir, modules)?;

    match command.as_str() {
        "gen" | "check" => {
            let mut clean = true;
            for spec in &specs {
                let outputs = match spec.module.as_str() {
                    "hex" => vec![(target(&root, spec), hex::emit(spec)?)],
                    "hex_t2" => vec![(target(&root, spec), hex::emit_t2_module(spec)?)],
                    "direction" => vec![(target(&root, spec), direction::emit(spec)?)],
                    "conversions" => vec![(target(&root, spec), conversions::emit(spec)?)],
                    // The golden file, the table region of `board/line.cairo` and the deviations
                    "line" => line::emit(spec, &root)?,
                    // The tables of `board/hexagon.cairo` and the band `ROW_FROM_16` of `board/tables.cairo`
                    "hexagon" => hexagon::emit(spec, &root)?,
                    // The generators of L-M2 (LIB-06): registered here by M2-T0, filled by the
                    // task that owns the module (M2-T3: impls, swizzle, euclidean, convert;
                    // M2-T4: rings; M2-T5: bounds, iter; M2-T6: shapes; M2-T7: grid)
                    "impls" => impls::emit(spec, &root)?,
                    "swizzle" => swizzle::emit(spec, &root)?,
                    "euclidean" => euclidean::emit(spec, &root)?,
                    "convert" => convert::emit(spec, &root)?,
                    "rings" => rings::emit(spec, &root)?,
                    "bounds" => bounds::emit(spec, &root)?,
                    "iter" => iter::emit(spec, &root)?,
                    "shapes" => shapes::emit(spec, &root)?,
                    "grid" => grid::emit(spec, &root)?,
                    // The algorithms of L-M3 (LIB-06b): M3-T1 `algorithms`, M3-T2 `fov`
                    "algorithms" => algorithms::emit(spec, &root)?,
                    "fov" => fov::emit(spec, &root)?,
                    other => return Err(format!("no generator registered for module {other:?}")),
                };
                for (path, text) in outputs {
                let current = fs::read_to_string(&path).ok().map(|t| t.replace("\r\n", "\n"));
                let up_to_date = current.as_deref() == Some(text.as_str());
                let shown = path.strip_prefix(&root).unwrap_or(&path).display().to_string();
                if command == "gen" {
                    if !up_to_date {
                        if let Some(parent) = path.parent() {
                            fs::create_dir_all(parent).map_err(|e| format!("{shown}: {e}"))?;
                        }
                        fs::write(&path, &text).map_err(|e| format!("{shown}: {e}"))?;
                    }
                    println!("{} {shown}", if up_to_date { "unchanged" } else { "wrote    " });
                } else if up_to_date {
                    println!("ok    {shown}");
                } else {
                    clean = false;
                    println!("STALE {shown}");
                }
                }
            }
            if !clean {
                eprintln!(
                    "golden files differ from the generator output; run:\n  cargo run \
                     --manifest-path tools/refgen/Cargo.toml -- gen"
                );
            }
            Ok(clean)
        }
        _ => Err(USAGE.into()),
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(e) => {
            eprintln!("error: {e}");
            ExitCode::from(2)
        }
    }
}
