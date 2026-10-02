# PENDING — `hexx` 0.1.0-rc.2: publication requested

Opened by the orchestrator of track LIB on 2026-10-02, under D-132 and
[`docs/RELEASING.md`](../RELEASING.md), on the model of
[D-132](D-132-publish-hexx-0.1.0-rc.1.md). Nothing is published until the go is recorded here.

## What is asked

| | |
|---|---|
| Package | `hexx` |
| Version | `0.1.0-rc.2` (a pre-release: the milestone gate is informational) |
| Commit | `TBD`: the merge commit of the release PR, on `main` |
| Release check | `TBD`: the run dispatched from `main` with that version and that sha, which must be **success**; its artifact `hexx-release-check-0.1.0-rc.2` |
| For | The game's ENG-05 |

## Content

The first release candidate built on Scarb 2.20.1 and starknet-foundry 0.64.0 (Cairo 2.20.0), and
the needs that `0.1.0-rc.1` lacked: N-1 (`new_cave_with_margins`, `smooth`), N-2 (`Seam::{side,
openings, is_open_across}`, `Layout::new_odd`) and N-6 (`hexagon`, `hexagon_ring`). See the
[CHANGELOG](../../CHANGELOG.md) section `[0.1.0-rc.2]`. Parity, deviations, gas and the results
changed are filled from the merge commit when the release PR is opened.

## Checks to pass before the go

1. **The release check**, dispatched from `main` on the exact sha, with the version `0.1.0-rc.2`:
   success. A run on another sha, or cancelled, is not evidence.
2. **One audit of the release** (D-177: this release is a published interface, which the reviews of
   its pull requests do not replace); no blocker or major finding open.
3. `CHANGELOG.md` has `[0.1.0-rc.2]` with its date, and the workspace `Scarb.toml` says
   `version = "0.1.0-rc.2"`; `crates/hexx` inherits it.
4. `scarb package -p hexx` from a clean checkout of the sha packages the same file names and sizes
   and the same packaged `Scarb.toml` as the release-check artifact; its archive sha256 is
   recorded.
5. Name and version free on the registry (`https://scarbs.xyz/api/v1/index/he/xx/hexx.json` does
   not list `0.1.0-rc.2`); no test dependency as a regular one.
6. **Numeric results**: every change against `0.1.0-rc.1` is in the CHANGELOG's *Results changed*.

## Constraint on class hashes

A class hash is reproducible on one machine, not across machines: the same CASM can come with
a different Sierra and class hash on two machines (programme finding, SPK-13). Nothing in this
request or in the release claims that a class hash is reproducible across machines. Every pin
(gas snapshots, class sizes, class hashes, checksums) is generated and checked on Linux only (the
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

The go of the project manager on `0.1.0-rc.2` from the commit above, yes or no, once checks 1 to 6
are met.

## Answer

Not given.
