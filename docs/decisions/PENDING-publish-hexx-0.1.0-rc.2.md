# PENDING — `hexx` 0.1.0-rc.2: publication requested

Opened by the orchestrator of track LIB on 2026-10-02, under D-132 and
[`docs/RELEASING.md`](../RELEASING.md), on the model of
[D-132](D-132-publish-hexx-0.1.0-rc.1.md). Nothing is published until the go is recorded here.

## What is asked

| | |
|---|---|
| Package | `hexx` |
| Version | `0.1.0-rc.2` (a pre-release: the milestone gate is informational) |
| Commit | `c60e05ad548907b313faaeae98eb9af0b6ea586f` (on `main`, merge of pull request #101) |
| Release check | run `37075327908`, dispatched from `main` with version `0.1.0-rc.2`: **in progress** (queued when read; to be updated when it completes, and it must be **success**); its artifact `hexx-release-check-0.1.0-rc.2` |
| Archive sha256 | `c4bf8aef830ca5ed0d9ebc02ad82aeea637ae96ab7311bbf522fc8d4d613a753`: taken by the orchestrator on the VPS, `scarb package -p hexx` at `c60e05a` (the archive's `VCS.json` says sha1 `c60e05ad548907b313faaeae98eb9af0b6ea586f`, path `crates/hexx`). The registry's checksum must equal this value after publication |
| Packed files | 39, including `LICENSE`, `LICENSE-hexx`, `LICENSE-origami` and `README.md` |
| For | The game's ENG-05 |

## Content

The first release candidate built on Scarb 2.20.1 and starknet-foundry 0.64.0 (Cairo 2.20.0), and
the needs that `0.1.0-rc.1` lacked: N-1 (`new_cave_with_margins`, `smooth`), N-2 (`SeamTrait::{side,
openings, is_open_across}`, `LayoutTrait::new_odd`) and N-6 (`hexagon`, `hexagon_ring`). See the
[CHANGELOG](../../CHANGELOG.md) section `[0.1.0-rc.2]`. Parity (unchanged, 10.0 %), extensions (240), deviations
(59) and the results changed (none) are in that section.

## Checks to pass before the go

1. **The release check**, dispatched from `main` on the exact sha, with the version `0.1.0-rc.2`:
   success. A run on another sha, or cancelled, is not evidence.
2. **One audit of the release** (D-177: this release is a published interface, which the reviews of
   its pull requests do not replace); no blocker or major finding open.
3. `CHANGELOG.md` has `[0.1.0-rc.2]`; it is dated after publication (`docs/RELEASING.md`
   step 5). The workspace `Scarb.toml` says `version = "0.1.0-rc.2"`; `crates/hexx` inherits it.
4. `scarb package -p hexx` from a clean checkout of the sha packages the same file names and sizes
   and the same packaged `Scarb.toml` as the release-check artifact; its archive sha256 is
   recorded.
5. Name and version free on the registry (`https://scarbs.xyz/api/v1/index/he/xx/hexx.json` does
   not list `0.1.0-rc.2`); no test dependency as a regular one.
6. **Numeric results**: every change against `0.1.0-rc.1` is in the CHANGELOG's *Results changed*.
7. **The consumer's toolchain**: the consumer (the game, ENG-05) is on Scarb >= 2.20.1, or waits
   for it; the N-9 consumer check after publication runs on 2.20.1.

Audits so far: release audit at `29a8360` FAIL (finding F1, the notice of `origami_hexmap` was not
in the package); fixed in the release-fix PR, which makes the new release commit.

- Release audit re-done at `646c451` (PR #101 head), PASS WITH FINDINGS (two notes, no blocker, no
  major); it covers the release commit `c60e05a`, whose only difference from `646c451` is
  `docs/briefs/LIB-04g-ci-path-filters.md` (merged in between, not packaged).
- Review of #101: PASS WITH FINDINGS (notes).
- `LICENSE-hexx` is byte-identical to `LICENSE` of hexx 0.25.0 (checked with `cmp` by the
  orchestrator).
- The release check at the release commit: run `37075327908`, in progress.

## Constraint on class hashes

Class hashes and Sierra file hashes depend on the absolute build path, so they differ between a
worktree and CI even on Linux (programme finding, SPK-13b); gas, Sierra felt counts and CASM do not.
No check, pin or comparison in this request or in the release uses a class hash or a Sierra file
hash: the figures compared are gas, Sierra felt counts and CASM. Class hash: not compared until the
build-root rule (programme OPERATIONS). The package checksum of the registry (the sha256 of the
`scarb package` archive) is a different thing and stays. Every pin is generated on Linux only (the
VPS or CI), never on a Mac.

## Who approves

The project manager, under D-132 (the owner delegated the release candidates `0.1.0-rc.N` to the
project manager; the stable versions stay the owner's). The go holds for `hexx` `0.1.0-rc.2` from
the commit above only.

## How it is published

By hand, as `docs/RELEASING.md` says, after the go is merged:

1. A clean clone checked out at the commit; `scarb package -p hexx`; the archive sha256 compared
   with the project manager's and the release check's.
2. `scarb publish -p hexx`, with the registry token taken from the environment by name
   (`SCARB_REGISTRY_AUTH_TOKEN`); its value is never printed, logged or written.
3. The registry's index shows `0.1.0-rc.2` with its `cksum`; only then the tag `v0.1.0-rc.2` on
   the commit and the GitHub release, marked a pre-release.

## Decisions needed

The go of the project manager on `0.1.0-rc.2` from the commit above, yes or no, once checks 1 to 7
are met.

## Answer

Not given.
