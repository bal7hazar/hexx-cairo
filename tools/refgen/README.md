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

## Why the golden file is not under `crates/hexx/tests/` yet

`Hex::distance_to` is not ported: M1-T2 (LIB-05) is the task that adds `Hex`, `HexTrait` and
`distance_to` to `crates/hexx/src`. Until then, a golden file that calls them must not be part of
`scarb build` / `snforge test`.

It cannot simply be dropped into `crates/hexx/tests/` and left undeclared: **Scarb bundles every
`.cairo` file directly under a package's `tests/` directory into one `<package>_integrationtest`
target even with no `tests/lib.cairo` present** — confirmed empirically while building this task
(`scarb build -p hexx` failed with `E0006`/`E0002` the moment a `tests/golden_hex.cairo` calling
the not-yet-existing `hexx::hex::Hex` existed, with no `tests/lib.cairo` and no `[[test]]` target
declaring it). There is no "declared but not compiled" state for a loose file in that directory.

`refgen` therefore writes to `tools/refgen/generated/golden_<module>.cairo`, outside every
package's source tree, where nothing discovers or compiles it. M1-T2 moves the file into
`crates/hexx/tests/` (creating `tests/lib.cairo` at that point, as the house convention does) once
the mirror item it tests exists.

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
   `tools/refgen/generated/` (or `crates/<package>/tests/` once the mirror item it calls exists).
