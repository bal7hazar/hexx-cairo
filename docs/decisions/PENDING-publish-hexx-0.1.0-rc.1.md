# PENDING — Publish `hexx` 0.1.0-rc.1?

Opened by the orchestrator of track LIB (`[Opus 5.5]`) on 2026-10-01, under D-132 and
[`docs/RELEASING.md`](../RELEASING.md). Nothing is published until the go is recorded here.

## What is asked

| | |
|---|---|
| Package | `hexx` |
| Version | `0.1.0-rc.1` (a pre-release: the milestone gate is informational) |
| Commit | `fe2b529de22db14ae29aa2072d75af10e50e4217` (on `main`, pull request #60) |
| Release check | [run 36813005979](https://github.com/bal7hazar/hexx-cairo/actions/runs/36813005979), dispatched from `main` (`27a682f`) with that version and that sha: **success**. Artifact `hexx-release-check-0.1.0-rc.1` (30 days) |
| For | The game's ENG-02 |

Two earlier runs on the same sha are not evidence: run `36807402272` was cancelled at the
workflow's old 20-minute timeout (raised to 120 by #61), and run `36809681077` passed the full gate
and the milestone, then failed at `scarb package` on an untracked report (fixed by #62).

## Content

The take-over of `origami_hexmap` 1.8.0, the mirror items of milestone L-M1, and needs N-3
(assembly of the window), N-4 (`cut`), N-5 (line of sight), N-7 (directions, arcs, board
coordinates, distance on global coordinates) and N-8 (the flood and the steps of the walkers).
Not in it: N-1 and N-2 (they wait for SPK-14), N-6 (M1-T5, running). See the
[CHANGELOG](../../CHANGELOG.md) section `[0.1.0-rc.1]`.

- **Parity** (`docs/API_PARITY.md`): 67 ported and 2 renamed of 692 items of `hexx` 0.25.0
  (10.0 %), 316 excluded with their reasons; the milestone report of the run: "every item
  scheduled by L-M1 is present".
- **Deviations**: 59 documented (`docs/DEVIATIONS.md`); `line_to`'s differences with `hexx` in
  `docs/deviations/line_ties.md`.
- **Results changed** against `origami_hexmap` 1.8.0: none on the equality and panic tests of
  `crates/takeover_tests`; three helpers renamed (`edge_neighbors`, `neighbor_in`,
  `neighbor_mask`).
- **Gas**: every test budgeted (`docs/GAS.md`); the figures accepted above the plan's ranges, with
  their reasons, at its end. Only `FloodTrait::depth` (670 against [200, 250]) is on the tick, 8
  calls, about 5,400, under 0.6 % of a worst tick (1,064,209); the others are not called by it.
- **Audits and reviews**: every lot of the release was audited (the reports in `docs/reports/`;
  LIB-04 merged with open findings by the project manager's decision, closed by LIB-04b); every
  pull request since D-162 (2026-09-29) was reviewed by Codex, except the brief #63 and the
  release-check fix #62, merged without one (Codex unavailable, quota; the project manager's
  decision of 2026-10-01): they change no code of the package.

## What the artifact shows (inspected by the orchestrator)

- The packaged `Scarb.toml` has **no regular dependency**; `snforge_std` (`^0.61.0`) is under
  `[dev-dependencies]` only: the defect of 1.8.0 (N-9) is not in the manifest. N-9's real proof,
  on the artifact the registry serves, is task M1-N9 and runs after publication.
- 35 files: `src/**` of the library, `README.md`, `LICENSE`, the manifests, `VERSION`, `VCS.json`.
  `src/tests.cairo` is shipped without the `src/tests/` directory: the module is declared
  `#[cfg(test)]` in `lib.cairo`, so a consumer never compiles it, and the package's own
  verification build passed. To clean in a later version, not a blocker.

## Decisions needed

1. **The owner, first (D-132)**: confirm that the decision to publish `hexx` release candidates
   is delegated to the project manager. Until then, the go below is the owner's.
2. **The go** (the project manager under that delegation, or the owner): publish `hexx`
   `0.1.0-rc.1` from `fe2b529`, yes or no.
3. **The registry token (the owner)**: `scarb publish` needs a scarbs.xyz token, and providing
   credentials is the owner's act. Either the owner makes it available to the orchestrator's
   session as an environment variable, used by name and never printed, or the owner runs
   `scarb publish -p hexx` from a clean checkout of `fe2b529` by hand.

**Recommendation**: yes. The content is what ENG-02 needs, the evidence is a green release check on
the exact sha, and a release candidate is informational on the milestone.

## Answer

(empty until decided)
