//! `rings`: the golden vectors of `crates/hexx/src/hex/rings.cairo`, written by M2-T4 (LIB-06). Registered by M2-T0 so that `main.rs` is
//! never edited again; the owning task replaces the body of `emit` and adds `specs/rings.toml`.

use std::path::{Path, PathBuf};

use crate::spec::Spec;

/// The golden file and whatever else the generator writes beside it (the multi-file signature of
/// `line` and `hexagon`).
pub fn emit(_spec: &Spec, _root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    Err("rings: written by M2-T4".into())
}
