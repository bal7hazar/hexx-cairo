//! `shapes`: the golden vectors of `crates/hexx/src/shapes.cairo`, written by M2-T6 (LIB-06). Registered by M2-T0 so that `main.rs` is
//! never edited again; the owning task replaces the body of `emit` and adds `specs/shapes.toml`.

use std::path::{Path, PathBuf};

use crate::spec::Spec;

/// The golden file and whatever else the generator writes beside it (the multi-file signature of
/// `line` and `hexagon`).
pub fn emit(_spec: &Spec, _root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    Err("shapes: written by M2-T6".into())
}
