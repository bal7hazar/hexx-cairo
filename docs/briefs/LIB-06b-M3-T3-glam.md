# LIB-06b M3-T3 — `hexx_glam`: the `glam` interop of `Hex`

## Agent

Title: `[Sonnet 5.5] LIB-06b M3-T3 glam` · Profile: `impl-sonnet` (five field copies in a new
package; most of the work is the package's place in the workspace, CI and the parity script).
Review: `review-opus`. Audit: **none** (D-177: no value, access control or randomness; the release
M3-R carries the one audit of the published interface, and `hexx_glam`'s first publication with
it).

Inherits [COMMON.md](COMMON.md) and `AGENTS.md`. Run as a thread of the herdr project: the report
goes where your thread brief says, with the contents of COMMON.md §7. You never publish, tag or
release anything. You delete and kill only what you created, named exactly.

**Starts after M3-T1 is merged** (it edits `scripts/api_parity.py` and
`crates/consumer/src/lib.cairo` before you). **Runs in parallel with M3-T2** (disjoint files).

## Goal

After this task the unpublished workspace holds a new package **`crates/hexx_glam`**, published
later beside `hexx` (M3-R), that converts between `hexx::Hex` and the `IVec2` / `IVec3` of the
Cairo `glam` (scarbs.xyz): the counterparts of `hexx` 0.25.0's `Hex::as_ivec2`, `Hex::as_ivec3`,
`From<Hex> for IVec2`, `From<Hex> for IVec3` and `From<IVec2> for Hex`, as the house's
`nalgebra_glam` does for `nalgebra` (plan §2.1, §4.4, D-14). It is the task "`crates/hexx_glam/**`"
of plan §8, L-M3. `hexx` itself gains no dependency.

## Context — read, in this order

1. [The index](LIB-06b-L-M3.md): **Decisions needed 3 and 4** (this brief follows their
   recommendations; a contrary ruling replaces Scopes 3 and 6).
2. [The plan](../research/LIB-03-porting-plan.md) **§14 first**, then §2.1 (the companion
   package), §4.4 (the rows `as_ivec2`, `as_ivec3` of `src/hex/mod.rs` and the three `From` rows of
   `src/hex/convert.rs`), §9.
3. What exists: `Hex` and `HexTrait::z` (`crates/hexx/src/hex.cairo`); the `Into` impls of M2-T3 in
   `crates/hexx/src/hex/convert.cairo` (the form of a Cairo conversion in this repository);
   `scripts/api_parity.py:181-200` (the five interop rules, which read `missing` by design today),
   `:1776-1792` (`_INTEROP_ITEMS`, `milestone_of`); AGENTS.md "Golden tests" (what a new package
   needs); `crates/hexx/{LICENSE-hexx,README.md}` (the licence notices of rc.2).
4. The pinned `hexx` 0.25.0: `src/hex/mod.rs:365-395` (`as_ivec2`, `as_ivec3`),
   `src/hex/convert.rs:32-58`. The published `glam` 0.5.0: `glam_core`'s `src/ivec2.cairo` and
   `src/ivec3.cairo` (`pub struct IVec2 { pub x: i32, pub y: i32 }`, `IVec3 { x, y, z }`, derives
   `Copy, Drop, Serde, PartialEq, Debug, Default, Hash`; `cairo-version = "^2.20.0"`).

## Scope

**In**

1. **The package** `crates/hexx_glam`: `Scarb.toml` (`name = "hexx_glam"`, the workspace's
   `version`, `edition`, `cairo-version`, `license`; a `description`; `hexx = { path = "../hexx",
   version = "<the workspace version>" }`, so that `scarb package` rewrites it to a registry
   dependency and M3-R bumps both together; **`glam = "0.5.0"`**, the facade its README names as
   the entry point, whose `glam::ivec2::IVec2` is `glam_core`'s type; `snforge_std` as a
   dev-dependency only, N-9); `README.md` (what it converts, how to import the impls, the credit
   "Ported to Cairo from bevy hexx 0.25.0 (Apache-2.0); the code is a rewrite, not a copy");
   `LICENSE` (MIT, as the workspace) and `LICENSE-hexx` (a copy of `crates/hexx/LICENSE-hexx`).
   Depending on `glam_core` alone instead (fewer packages to resolve): what would choose it is the
   orchestrator or `glam`'s author saying `glam_core` is a supported entry point.
2. **The items**, in `src/lib.cairo`, each with `Mirrors ...` and `#### Deviations` where one
   applies:
   - `HexGlamTrait` (D-143: a trait with short names, its impl on `Hex`) with `as_ivec2(self: Hex)
     -> IVec2` (`IVec2 { x, y }`) and `as_ivec3(self: Hex) -> IVec3` (`IVec3 { x, y, z: self.z() }`,
     `HexTrait::z` of L-M1, so its `#### Panics` are `z`'s at the `i32` extremes, pinned by a test).
   - `impl HexIntoIVec2 of Into<Hex, IVec2>`, `impl HexIntoIVec3 of Into<Hex, IVec3>`, `impl
     IVec2IntoHex of Into<IVec2, Hex>` (`HexTrait::new(v.x, v.y)`), the counterparts of the three
     `From` impls: Cairo's conversion trait is `Into` (deviation, as M2-T3's tuple and array
     conversions). Nothing more: `hexx` has no `From<IVec3> for Hex`, and none is added.
   - **Deviation to document, after checking it**: an impl defined in `hexx_glam` is neither in
     the module of `Into` nor in those of `Hex` or `IVec2`, so a consumer must bring it into scope
     (`use hexx_glam::{HexIntoIVec2, …}` or `use hexx_glam::*`) for `.into()` to find it. Prove the
     rule with the consumer call sites (Scope 5) and write what you measured in the README and the
     doc comments.
3. **The parity table** (Decision 3): extend `scripts/api_parity.py` so that the five keys of
   `_INTEROP_ITEMS`, and only those, are also looked up in `crates/hexx_glam/src` (`HexGlamTrait`
   counting for the owner `Hex`, the three impls matched by their `Into` forms), replacing the
   comment of `:181-187` that says they read `missing` forever; with unit tests in
   `scripts/tests/test_api_parity.py` (present: `ported` or `renamed`; absent: `missing`; nothing
   else of `hexx_glam` enters the table). `docs/API_PARITY.md` regenerated: the five rows no longer
   `missing`.
4. **Tests** (D-167, in `src/lib.cairo`, `#[cfg(test)] mod tests`): the oracle is the definition —
   every `(x, y)` of `[-40, 40]²`: `as_ivec2` and `Into<Hex, IVec2>` equal `IVec2 { x, y }`, and
   `Into<IVec2, Hex>` of it gives the hex back; `as_ivec3` and `Into<Hex, IVec3>` equal `IVec3 { x,
   y, z: -x - y }`; the `i32` extremes of `IVec2` both ways; `as_ivec3` at the extremes as
   `HexTrait::z` behaves. A few vectors of `hexx`'s own `as_ivec3` are not needed: it is
   `IVec3 { x, y, z: self.z() }` (`mod.rs:390-396`) and `z` is golden-tested since L-M1; say so in
   the module doc. Every test with its `#[available_gas(l2_gas: N)]`; no bench (field copies, no
   target).
5. **Call sites**: `crates/consumer/Scarb.toml` gains `hexx_glam = { path = "../hexx_glam" }`;
   `crates/consumer/src/lib.cairo` gains `pub mod mirror_glam;`; `crates/consumer/src/mirror_glam.cairo`
   (contract `HexxGlam`) calls the five items; `gas/bytecode.size` re-taken on Linux.
6. **The workspace** (AGENTS.md, "Golden tests": what a new package requires, in the same change):
   `crates/hexx_glam` in the root `Scarb.toml`'s `members`; `Scarb.lock`; the `test` matrix and the
   `gas` matrix of `.github/workflows/ci.yml` (one row each, as the golden packages'; edited with
   the file-editing tool, in this pull request, and said in the report); `gas/hexx_glam.snap`;
   the package list of `scripts/tests/test_bench_gate_split.py`. `scripts/ci_changes.py` needs no
   change (`crates/.*` already selects the `cairo` group): check it in its test and say so.
   Packaging `hexx_glam` (`scarb package -p hexx_glam`) is M3-R's, once `hexx` 0.3.0 is on the
   registry; do not add it to the `package` job.

**Out**: any change to `crates/hexx` (no `glam` dependency in the published `hexx`); `Into<IVec3,
Hex>` or any item `hexx` does not have; `UVec`, `Vec2`, `f32` conversions (dropped: `f32`);
`CHANGELOG.md`; `docs/RELEASING.md`; any publication, tag or registry write.

**Allowlist**: `crates/hexx_glam/**`; `Scarb.toml` (root, `members`), `Scarb.lock`;
`.github/workflows/ci.yml` (the two matrix rows); `scripts/api_parity.py` (the interop lookup and
its comment), `scripts/tests/test_api_parity.py`, `scripts/tests/test_bench_gate_split.py`,
`scripts/tests/test_ci_changes.py` (a case for `crates/hexx_glam/`, if absent);
`crates/consumer/Scarb.toml`, `crates/consumer/src/lib.cairo` (one `mod` line),
`crates/consumer/src/mirror_glam.cairo`; `docs/API_PARITY.md`, `docs/EXTENSIONS.md`,
`docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/hexx_glam.snap`, `gas/bytecode.size`. If a script other
than these (`deviations.py`, `gas_tables.py`, `bench.py`, `takeover_check.py`, `prepush.sh`) needs
to know the new package: an escalation, with the line it needs.

## Interfaces

Consumed: L-M1 `Hex`, `HexTrait::{new, x, y, z}`; `glam` 0.5.0 `IVec2`, `IVec3`. Provided:
`hexx_glam::{HexGlamTrait, HexIntoIVec2, HexIntoIVec3, IVec2IntoHex}`; nothing of L-M3 consumes
them.

## Acceptance criteria

- [ ] AC-1 The five items exist in `hexx_glam` with the forms of Scope 2 and pass the tests of
      Scope 4; the import rule of Scope 2 is checked and documented.
- [ ] AC-2 `api_parity.py --check` shows the five rows `ported` or `renamed`;
      `--check-release L-M3 --report-only` lists only M3-T2's items if it has not merged, none
      otherwise; the unit tests of Scope 3 pass; `deviations.py --check` passes.
- [ ] AC-3 `crates/hexx` is unchanged; `hexx`'s manifest has no `glam` dependency.
- [ ] AC-4 The workspace items of Scope 6 are in place; CI runs `hexx_glam`'s tests and gas.
- [ ] AC-5 `scripts/check.sh` passes; CI green, the slowest job reported.
- [ ] AC-6 Nothing outside the allowlist was written.

## Measurements (programme rule, 2026-10-02) and memory (AGENTS.md, "How tests are scoped")

Every committed pin — `gas/hexx_glam.snap`, `gas/bytecode.size`, and any class hash — is generated
and checked **on Linux only** (the VPS or CI, the single-thread build of D-176), never on the Mac;
CI's artefact `gas-pins-<head sha>` carries every package it measured completely. A Mac/Linux
difference is reported with both figures. **Never state a class hash as reproducible across
machines.** The build and tests of `hexx_glam` and of `consumer` have **unknown peaks: measure
each first** (on the Mac, or on the VPS under `prlimit --as=8589934592 -- /usr/bin/time -v`, and on
the Mac if that aborts), then run under `--as` = 1.5 × the measured peak, rounded up to whole GiB;
record the figures in your report so the orchestrator can add them to AGENTS.md's table. The
`hexx` test target is not yours to build (D-212).

## Shared generated files

`docs/API_PARITY.md`, `docs/EXTENSIONS.md`, `docs/DEVIATIONS.md`, `docs/GAS.md`, `gas/*.snap` and
`gas/bytecode.size` are regenerated, never edited or merged by hand. If `main` moves under your
open pull request and they conflict (M3-T2 runs beside you), merge `origin/main` into your branch
(a merge commit; never a rebase), regenerate them with their scripts on Linux, and push.

## Verification

Scoped to the parts touched (AGENTS.md): `scripts/lock.sh snforge test -p hexx_glam` and
`scripts/lock.sh snforge test -p consumer` (peaks measured first, above);
`python3 -m unittest discover -s scripts/tests`; `python3 scripts/api_parity.py --check` and
`--check-release L-M3 --report-only`; `python3 scripts/deviations.py --check`;
`python3 scripts/bench.py check`; `python3 scripts/gas_tables.py --check`;
`python3 scripts/bytecode_size.py check`; `scarb fmt --check --workspace`; `scripts/prepush.sh`
before every push; `scripts/check.sh` before asking for the review.

## What the reviewer will check

The five items against `hexx` 0.25.0 (`z` of `as_ivec3`, the direction of each conversion, nothing
added); the import rule as measured, not assumed; `hexx` untouched; the manifest (path plus
version, `glam` by published version, `snforge_std` dev-only, the licence files); the parity
script's lookup limited to the five keys, with tests for presence and absence; the CI rows; the
organisation lens.

## Report

As COMMON.md §7, with the measured peaks of the new builds.
