# PENDING — publish `hexx_glam` 0.3.0 (a new package)

Opened by the M3-R prep thread (t-0124) for the orchestrator of track LIB, on 2026-10-10, under D-132
as the owner narrowed it and [`docs/RELEASING.md`](../RELEASING.md), on the model of
[D-211](D-211-publish-hexx-0.2.0.md). Nothing is published until the owner's go is recorded. No
agent publishes, tags or releases (COMMON.md §6). **Order: [`hexx` 0.3.0](D-281-publish-hexx-0.3.0.md)
first, published and visible on the registry (done: `hexx` 0.3.0 published 2026-10-12, D-281); only then this package**: it depends on
`hexx = "^0.3.0"`, so its verification cannot pass before that (see *Checks*).

## What is asked

| | |
|---|---|
| Package | `hexx_glam` (a **new** package name on the registry) |
| Version | `0.3.0` (a stable version: the owner's go; versioned with `hexx`, first publication) |
| Commit | `268136f4ebb80455fe43e5b3bd2d78d7d89bcee2` (the merge of #132 on `main`; the same as `hexx` 0.3.0) |
| Archive sha256 | `30e73f916ec7c4cd241e0a13dffd1a6a17fab6a4b2e97f08c6967cec66ba6621`: `target/package/hexx_glam-0.3.0.tar.zst`, `scarb package -p hexx_glam` at `268136f`, after `hexx` 0.3.0 was published. The registry's checksum must equal this value after publication. Tag to be created on publication: `hexx_glam-v0.3.0` |
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

- [x] The commit is on main with every CI check green (at `268136f`).
- [x] Audits closed without blocker or major: parity audit of L-M3 (thread t-0123): PASS WITH FINDINGS,
      notes only.
- [x] Changelog and version agree: `[0.3.0]` of `CHANGELOG.md` covers it; the workspace version is
      `0.3.0` (`version.workspace = true`); its `hexx` dependency says `0.3.0` and the README
      snippet `hexx = "0.3.0"`, `hexx_glam = "0.3.0"`.
- [x] The gas tables are those of the commit (`docs/GAS.md`; CI's gas jobs green at `268136f`).
- [x] `scarb package -p hexx_glam` from a clean clone at `268136f` (`git status` empty before and
      after), by hand on the VPS after `hexx` 0.3.0 was published: `RAYON_NUM_THREADS=1 prlimit
      --as=8589934592 -- /usr/bin/time -v scarb package -p hexx_glam`, rc 0. Output: `Verifying
      hexx_glam-0.3.0.tar.zst`, `Packaged 8 files, 22.74 KiB (7.42 KiB compressed)`, max RSS
      1,323,372 kB. The cap follows D-251 (VmPeak of the `hexx_glam` build 5,161,128 kB → 8 GiB).
      The verification resolved `hexx` from the registry: the packaged `Scarb.lock` has `hexx`
      0.3.0, source `registry+https://scarbs.xyz/`, checksum
      `sha256:2f2040388da65cfc8186f35f08aca63884e703222b0d70b15956672129e309b1`. `scarb package
      --list -p hexx_glam`: `VERSION`, `LICENSE`, `LICENSE-hexx`, `README.md`, `Scarb.orig.toml`,
      `Scarb.toml`, `VCS.json`, `src/lib.cairo`. Archive sha256 of `hexx_glam-0.3.0.tar.zst`:
      `30e73f916ec7c4cd241e0a13dffd1a6a17fab6a4b2e97f08c6967cec66ba6621`.
- [x] Name and version free on the registry: `hexx_glam` is absent —
      `https://scarbs.xyz/api/v1/index/he/xx/hexx_glam.json` (read-only, 2026-10-12)
      gives `HTTP 404`, so the name is free.
- [x] No test dependency as a regular one: the packaged `[dependencies]` are
      `[dependencies.glam] version = "^0.5.0"` and `[dependencies.hexx] version = "^0.3.0"`;
      `snforge_std` is under `[dev-dependencies]` only. The `path` of `hexx` is rewritten to the
      registry.
- [x] Numeric results: none changed (CHANGELOG, *Results changed*: empty).

## Who approves

The owner (a stable version, a new package). The go holds for `hexx_glam` `0.3.0` from the commit
named in it only.

## Answer

Pending: the owner's go, then publication, read-back and the tag `hexx_glam-v0.3.0` remain.

- [ ] The owner's go
- [ ] Publication
- [ ] Read-back
- [ ] Tag
