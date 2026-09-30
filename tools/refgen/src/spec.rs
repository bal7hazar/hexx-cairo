//! A deliberately small, flat TOML-like format: `key = value` lines (a `#` starts a comment), no
//! tables, no nesting, no arrays, no external crate (mirrors the Python scripts' dependency-free
//! house rule, carried into this Rust tool).
//!
//! Every spec has `module` and `package`; the other keys are read by the generator of the module
//! (`Spec::int`, `Spec::text`) and an unknown key is an error there, not here. The
//! keys `gas.<test name>` hold the `#[available_gas(l2_gas: N)]` budget of the generated test of
//! that name (`N = ceil(1.05 * measured)`, set from a measurement: `Spec::gas`).

use std::collections::BTreeMap;
use std::fs;
use std::path::Path;

pub struct Spec {
    pub module: String,
    /// The package whose `tests/` directory receives `golden_<module>.cairo`.
    pub package: String,
    keys: BTreeMap<String, String>,
    path: String,
}

fn unquote(value: &str) -> String {
    value.trim().trim_matches('"').to_string()
}

impl Spec {
    pub fn load(path: &Path) -> Result<Spec, String> {
        let shown = path.display().to_string();
        let text = fs::read_to_string(path).map_err(|e| format!("{shown}: {e}"))?;
        let mut keys = BTreeMap::new();
        for raw_line in text.lines() {
            let line = raw_line.split('#').next().unwrap_or("").trim();
            if line.is_empty() {
                continue;
            }
            let Some((key, value)) = line.split_once('=') else {
                return Err(format!("{shown}: cannot parse line: {raw_line:?}"));
            };
            let key = key.trim().to_string();
            if keys.insert(key.clone(), unquote(value)).is_some() {
                return Err(format!("{shown}: duplicate key {key:?}"));
            }
        }
        let module = keys.remove("module").ok_or_else(|| format!("{shown}: missing `module`"))?;
        let package = keys.remove("package").ok_or_else(|| format!("{shown}: missing `package`"))?;
        Ok(Spec { module, package, keys, path: shown })
    }

    pub fn text(&self, key: &str) -> Result<String, String> {
        self.keys.get(key).cloned().ok_or_else(|| format!("{}: missing `{key}`", self.path))
    }

    pub fn int(&self, key: &str) -> Result<i64, String> {
        let value = self.text(key)?;
        value.parse().map_err(|_| format!("{}: bad integer for `{key}`: {value:?}", self.path))
    }

    /// The budget of the generated test `test`; a placeholder until it is measured.
    pub fn gas(&self, test: &str) -> Result<u64, String> {
        match self.keys.get(&format!("gas.{test}")) {
            Some(value) => value
                .parse()
                .map_err(|_| format!("{}: bad budget for `{test}`: {value:?}", self.path)),
            None => Ok(PLACEHOLDER_GAS),
        }
    }

    /// The keys `gas.<test>` of the spec, for the tests that no longer exist (a stale budget).
    pub fn budgeted_tests(&self) -> Vec<String> {
        self.keys.keys().filter_map(|k| k.strip_prefix("gas.")).map(str::to_string).collect()
    }
}

/// Written when a test has no `gas.<test>` key yet: large enough to run, never a valid budget
/// (`scripts/bench.py check` rejects it).
pub const PLACEHOLDER_GAS: u64 = 1_000_000_000;
