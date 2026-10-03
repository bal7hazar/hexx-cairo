# refgen — golden vectors, hexx 0.25.0 as the oracle

`refgen` calls the real Rust crate [`hexx`](https://github.com/ManevilleF/hexx) `= 0.25.0`
(`default-features = false`, `features = ["algorithms", "grid"]`, plan §4.3) to generate golden
Cairo tests: for a spec's inputs, the exact result `hexx` gives, so the Cairo port can be checked
against it bit for bit.

```sh
cargo run --manifest-path tools/refgen/Cargo.toml -- gen [module]    # write the golden file(s)
cargo run --manifest-path tools/refgen/Cargo.toml -- check [module]  # exit 1 if a file is stale
```

Unlike the house `refgen` of `glam-cairo` (a full spec + oracle-registry engine over an f64
fixed-point quantizer, because `glam-rs` is `f32` and the Cairo port is fixed-point), `hexx`'s
mirror is mostly exact-integer (`i32` in, `i32` out): no quantization, no tolerance budget, no
float is involved for the one function this task generates vectors for. `tools/refgen/specs/*.toml`
is therefore a deliberately small, flat, dependency-free format (`spec.rs`, no `toml`/`serde`
crate), not the richer format the house tool uses; a future module whose mirror needs the same
`f32` -> exact-rational treatment `hexx`'s own `div_scalar`/`to_lower_res` deviations describe
(plan §4.4) can grow this format then, not before.

## Where the golden files go

A spec's `package` names the package whose `tests/` directory receives `golden_<module>.cairo`
(`target` in `main.rs`): never `hexx` itself, but one of the unpublished golden packages
`crates/golden_*`, which depend on `hexx` by path (LIB-04h). **Scarb bundles every `.cairo` file
directly under a package's `tests/` directory into one `<package>_integrationtest` target**, and
the memory of that compile grows with its line count (measured on the VPS, single-threaded:
13,765 lines took 6.0 GB, 5,119 lines 2.0 GB): a package per group of golden files keeps every
compile apart. The line budget of a package and where a new golden file goes are in `AGENTS.md`
("Golden tests"). The `hexagon` spec keeps `package = "hexx"`: it writes tables into
`crates/hexx/src/board/`, not a golden file.

## How CI checks golden files are current without a Rust toolchain in the main job

`ubuntu-latest` preinstalls a stable Rust toolchain, so the dedicated `golden` job of
`.github/workflows/ci.yml` runs `cargo run --manifest-path tools/refgen/Cargo.toml -- check`
directly — no extra setup step. `scripts/check.sh` (what a local run and the other CI jobs use)
only runs that same check `if command -v cargo >/dev/null 2>&1`, so it degrades gracefully on a
machine without Rust: the `golden` CI job is the one place this check is guaranteed to run, and
its cache key (`tools/refgen/Cargo.lock`) keeps it fast. This is the same split `glam-cairo` uses.

## Adding a module

1. Add `tools/refgen/specs/<module>.toml`: `module`, `package`, one `[[function]]` block per
   function with the inputs it needs.
2. Register a generator for it in `main.rs`'s `match spec.module.as_str()` (`emit_hex_module` is
   the one example so far).
3. `cargo run --manifest-path tools/refgen/Cargo.toml -- gen <module>`, commit the result under
   `crates/<package>/tests/` (a golden package, `AGENTS.md`, "Golden tests").
