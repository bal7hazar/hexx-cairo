//! A deliberately small, flat TOML-like format: top-level `key = value` lines, then one or more
//! `[[function]]` blocks of their own `key = value` lines. No nesting, no arrays, no external
//! crate (mirrors the Python scripts' dependency-free house rule, carried into this Rust tool).

use std::fs;
use std::path::Path;

pub struct Function {
    pub name: String,
    pub seed: String,
    pub samples: u32,
    pub domain_min: i32,
    pub domain_max: i32,
}

pub struct Spec {
    pub module: String,
    /// Not read by this tool (the staging path under `tools/refgen/generated/` does not need
    /// it); kept in the spec as the record of which package LIB-05 moves the file into.
    #[allow(dead_code)]
    pub package: String,
    pub functions: Vec<Function>,
}

fn unquote(value: &str) -> String {
    value.trim().trim_matches('"').to_string()
}

impl Spec {
    pub fn load(path: &Path) -> Result<Spec, String> {
        let text = fs::read_to_string(path).map_err(|e| format!("{}: {e}", path.display()))?;
        let mut module = None;
        let mut package = None;
        let mut functions: Vec<Function> = Vec::new();
        let mut current: Option<(String, String, u32, i32, i32)> = None;

        let flush = |current: &mut Option<(String, String, u32, i32, i32)>, out: &mut Vec<Function>| {
            if let Some((name, seed, samples, domain_min, domain_max)) = current.take() {
                out.push(Function { name, seed, samples, domain_min, domain_max });
            }
        };

        for raw_line in text.lines() {
            let line = raw_line.split('#').next().unwrap_or("").trim();
            if line.is_empty() {
                continue;
            }
            if line == "[[function]]" {
                flush(&mut current, &mut functions);
                current = Some((String::new(), String::new(), 0, 0, 0));
                continue;
            }
            let Some((key, value)) = line.split_once('=') else {
                return Err(format!("{}: cannot parse line: {raw_line:?}", path.display()));
            };
            let key = key.trim();
            let value = value.trim();
            match &mut current {
                Some((name, seed, samples, domain_min, domain_max)) => match key {
                    "name" => *name = unquote(value),
                    "seed" => *seed = unquote(value),
                    "samples" => {
                        *samples = value
                            .parse()
                            .map_err(|_| format!("{}: bad samples {value:?}", path.display()))?
                    }
                    "domain_min" => {
                        *domain_min = value
                            .parse()
                            .map_err(|_| format!("{}: bad domain_min {value:?}", path.display()))?
                    }
                    "domain_max" => {
                        *domain_max = value
                            .parse()
                            .map_err(|_| format!("{}: bad domain_max {value:?}", path.display()))?
                    }
                    other => return Err(format!("{}: unknown key {other:?}", path.display())),
                },
                None => match key {
                    "module" => module = Some(unquote(value)),
                    "package" => package = Some(unquote(value)),
                    other => return Err(format!("{}: unknown key {other:?}", path.display())),
                },
            }
        }
        flush(&mut current, &mut functions);

        Ok(Spec {
            module: module.ok_or_else(|| format!("{}: missing `module`", path.display()))?,
            package: package.ok_or_else(|| format!("{}: missing `package`", path.display()))?,
            functions,
        })
    }
}
