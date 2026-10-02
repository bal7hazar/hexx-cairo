# LIB-06 — Milestone L-M2: the mirror completed (release 0.2.0)

The index of the briefs of milestone L-M2, for the orchestrator. Each task has its own brief; this
file holds what concerns them all: the cut, the order, the files each task owns, and the release.

## The cut

The plan's own cut, unchanged ([plan](../research/LIB-03-porting-plan.md) §8, L-M2, row "Tasks,
exclusive files, dependency edges"), with §14 #43 applied to M2-T3, and one addition to M2-T0: the
scaffold of the module tree, of `tools/refgen`'s dispatch, of `crates/consumer`'s per-task files and
of the two script entries every later task would otherwise edit at the same line.

| Task | Brief | Files it owns in `crates/hexx/src` | Profile | Runs after |
|---|---|---|---|---|
| M2-T0 | [bootstrap](LIB-06-M2-T0-bootstrap.md) | `hex.cairo` (first), the scaffold | `impl-sonnet` | 0.1.0 released, LIB-04f |
| M2-T1 | [directions](LIB-06-M2-T1-directions.md) | `direction.cairo`, `direction/*` | `impl-sonnet` | M2-T0 |
| M2-T2 | [hex](LIB-06-M2-T2-hex.md) | `hex.cairo` (then) | `impl-sonnet` | M2-T0, M2-T1 |
| M2-T3 | [operators](LIB-06-M2-T3-operators.md) | `hex/{impls,swizzle,euclidean,convert}.cairo`, `conversions.cairo` | `impl-opus` | M2-T0, M2-T1 |
| M2-T4 | [rings](LIB-06-M2-T4-rings.md) | `hex/rings.cairo` | `impl-sonnet` | M2-T1, M2-T2, M2-T3 |
| M2-T5 | [bounds](LIB-06-M2-T5-bounds.md) | `bounds.cairo`, `hex/iter.cairo` | `impl-sonnet` | M2-T1, M2-T2, M2-T3 |
| M2-T6 | [shapes](LIB-06-M2-T6-shapes.md) | `shapes.cairo` | `impl-sonnet` | M2-T2 |
| M2-T7 | [grid](LIB-06-M2-T7-grid.md) | `hex/grid/{edge,vertex}.cairo` | `impl-sonnet` | M2-T1 (scheduled with M2-T4) |
| M2-R | — (orchestrator) | — | — | every task above |

**Parallel groups** (plan §8): `T0`; `T1`; `T2` with `T3`; then `T4`, `T5`, `T6`, `T7` together.
At most four threads at once, in the last group.

## Shared files, and why the groups do not collide

| File | Who writes it |
|---|---|
| `crates/hexx/src/lib.cairo` | M2-T0 lays it out in one block per module; then one line each in its own block: M2-T1 (`direction`), M2-T3 (`conversions`), M2-T5 (`bounds`), M2-T7 (`hex`). Git merges lines of distinct blocks without conflict |
| `crates/hexx/src/hex.cairo` | M2-T0, then M2-T2 (plan §8) |
| `tools/refgen/src/main.rs` | M2-T0 only (every arm of L-M2 registered); each task owns its generator files |
| `crates/consumer/src/lib.cairo` | M2-T0 only (`mod` lines; its own calls in `HexxMirror`); each task owns its `mirror_*.cairo` |
| `scripts/takeover_check.py`, `scripts/api_parity.py` | M2-T0 only, the entries its brief lists |
| `src/tests.cairo` | nobody: benches live in each module's `#[cfg(test)] mod tests` |
| `docs/API_PARITY.md`, `EXTENSIONS.md`, `DEVIATIONS.md`, `GAS.md`, `gas/hexx.snap`, `gas/bytecode.size` | every task, **generated**: never hand-merged; a task whose pull request conflicts after another merge merges `origin/main` into its branch and regenerates them on Linux |

## What every brief carries

The targets derived from the L-M1 measurements of the mirror (plan §7 has none for L-M2), with the
stop at twice the upper bound; the programme rule on measurements (Linux only for every committed
pin, both figures for a Mac/Linux difference, no class hash claimed reproducible across machines);
whether an audit is expected (none per task, D-177); the reviewer's model, another than the
implementer's.

## M2-R — release 0.2.0

The orchestrator's, as M1-R: `--check-release L-M2` passes (the only `missing` items are those of
L-M3), every deviation documented, benches for every non-trivial function, `CHANGELOG.md` with its
four headings (`Results changed` empty: L-M2 adds items and changes no result of 0.1.0), then the
publication procedure of COMMON.md §6. 0.2.0 is a stable version: its go is the owner's (D-132 as
narrowed: release candidates are the project manager's, stable versions the owner's). **One audit** before publication, under D-177's "a published interface once before its
publication": the parity lens over the whole of L-M2.
