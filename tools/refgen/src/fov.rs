//! `fov`: the golden vectors of `range_fov` and `directional_fov` (M3-T2, LIB-06b). Registered
//! here by M3-T1 so that `main.rs` is not edited twice; M3-T2 replaces this body and adds
//! `specs/fov.toml`.

use std::path::{Path, PathBuf};

use crate::spec::Spec;

pub fn emit(_spec: &Spec, _root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    Err("fov: no generator yet (M3-T2)".into())
}
