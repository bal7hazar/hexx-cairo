# PENDING — publish `hexx_glam` 0.3.0 (a new package)

Opened by the M3-R prep thread (t-0124) for the orchestrator of track LIB, on 2026-10-10, under D-132
as the owner narrowed it and [`docs/RELEASING.md`](../RELEASING.md), on the model of
[D-211](D-211-publish-hexx-0.2.0.md). Nothing is published until the owner's go is recorded. No
agent publishes, tags or releases (COMMON.md §6). **Order: [`hexx` 0.3.0](PENDING-publish-hexx-0.3.0.md)
first, published and visible on the registry; only then this package**: it depends on
`hexx = "^0.3.0"`, so its verification cannot pass before that (see *Checks*).

## What is asked

| | |
|---|---|
| Package | `hexx_glam` (a **new** package name on the registry) |
| Version | `0.3.0` (a stable version: the owner's go; versioned with `hexx`, first publication) |
| Commit | the merge commit of this PR on `main` (the orchestrator records it) |
| Archive sha256 | to be taken from `scarb package -p hexx_glam` at that commit, after `hexx` 0.3.0 is visible, and recorded in the go |
| For | The game: the `glam` interop of `hexx` 0.25.0 (`Hex` ↔ `IVec2`/`IVec3`) |

## What changed

New package (M3-T3, #130): `HexGlamTrait::as_ivec2` and `as_ivec3`, and the `Into` impls
`HexIntoIVec2`, `HexIntoIVec3`, `IVec2IntoHex`. It has no changelog of its own; its first entry is
in the [CHANGELOG](../../CHANGELOG.md) section `[0.3.0]`, *Parity*. Dependencies: `glam = "0.5.0"`
and `hexx` 0.3.0.

## What the consumer must do

Add `hexx = "0.3.0"` and `hexx_glam = "0.3.0"`, and import the impls (`use hexx_glam::{HexGlamTrait,
HexIntoIVec2, IVec2IntoHex};`, or `use hexx_glam::*;`): without the import `.into()` fails with
E2311 (`crates/hexx_glam/README.md`).

## Checks before the go (COMMON.md §6)

- [ ] The commit is on main with every CI check green (the merge commit; to verify after the merge).
- [ ] Audits closed without blocker or major: parity audit of L-M3 — pending (orchestrator fills).
- [x] Changelog and version agree: `[0.3.0]` of `CHANGELOG.md` covers it; the workspace version is
      `0.3.0` (`version.workspace = true`); its `hexx` dependency says `0.3.0` and the README
      snippet `hexx = "0.3.0"`, `hexx_glam = "0.3.0"`.
- [ ] The gas tables are those of the commit (`docs/GAS.md`; CI's gas jobs green). No measured code
      changes in this PR.
- [~] `scarb package -p hexx_glam` from a clean worktree (same cap): **verification cannot pass
      before `hexx` 0.3.0 is on the registry.** At the head of the PR it fails with
      `error: failed to verify package tarball` / `cannot get dependencies of hexx_glam@0.3.0` /
      `cannot find package hexx ^0.3.0`, as expected. With `--no-verify`: `Packaged 8 files, 22.54
      KiB (7.39 KiB compressed)`, max RSS 776,988 kB; archive sha256 at the head of the PR
      `9b6f6166a03aadf5d77beff19738c5ba1e28b383721c511ffc6948e269baf9dd` (not binding). **The
      orchestrator re-runs `scarb package -p hexx_glam` without `--no-verify` once `hexx` 0.3.0 is
      visible, and ticks this.**
- [x] Name and version free on the registry: `hexx_glam` is absent —
      `https://scarbs.xyz/api/v1/index/he/xx/hexx_glam.json` answers HTTP 404 (read-only,
      2026-10-10); `hexx` lists `0.1.0-rc.1`, `0.1.0-rc.2`, `0.2.0` only (0.3.0 not yet).
- [x] No test dependency as a regular one: the packaged `[dependencies]` are
      `[dependencies.glam] version = "^0.5.0"` and `[dependencies.hexx] version = "^0.3.0"`;
      `snforge_std` is under `[dev-dependencies.snforge_std]` (`^0.64.0`). The `path` of `hexx` is
      rewritten to the registry.
- [x] Numeric results: none changed (CHANGELOG, *Results changed*: empty).

## Who approves

The owner (a stable version, a new package). The go holds for `hexx_glam` `0.3.0` from the commit
named in it only.

## Answer

Pending.
