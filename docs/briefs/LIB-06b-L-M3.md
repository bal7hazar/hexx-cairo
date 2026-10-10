# LIB-06b — Milestone L-M3: algorithms, interop, closure of the table (release 0.3.0)

The index of the briefs of milestone L-M3, for the orchestrator. Each task has its own brief; this
file holds what concerns them all: the cut, the order, the files each task owns, the decisions the
plan leaves open, and the release.

L-M3 is what `docs/API_PARITY.md` still lists `missing | L-M3` at `main` (`f82f1cb`), 9 items:

| Items | Module of `hexx` 0.25.0 | Task |
|---|---|---|
| `field_of_movement`, `a_star` | `src/algorithms/{field_of_movement,pathfinding}.rs` | M3-T1 |
| `range_fov`, `directional_fov` | `src/algorithms/fov.rs` | M3-T2 |
| `as_ivec2`, `as_ivec3`, `From<Hex> for IVec2`, `From<Hex> for IVec3`, `From<IVec2> for Hex` | `src/hex/mod.rs:375, 390`, `src/hex/convert.rs:32, 46, 53` | M3-T3 |

The name `LIB-06b`: `PLAN.md` numbers a milestone `LIB-05` (L-M1), `LIB-06` (L-M2), and keeps
`LIB-07` for the final release (L-M4, cited by plan §8 and §10); L-M3 takes the follow-up suffix
of the track (`LIB-04b` … `LIB-04i`) rather than renumbering `LIB-07`. Tasks are `M3-T<n>`, as
`M2-T<n>`. What would reverse it: the orchestrator renumbers (`LIB-07` for L-M3, `LIB-08` for the
final release) and the plan's two citations of `LIB-07` with it.

## The cut

Plan §8, L-M3, "Size": "4 tasks with exclusive files: `algorithms/fov.cairo`;
`algorithms/{field_of_movement,pathfinding}.cairo`; `crates/hexx_glam/**`; the game's new needs".
The first three are kept as M3-T1 to M3-T3. The fourth has no content: the game's
`docs/needs/hexmap.md` (read in the Mac clone `/Users/bal7hazar/git/grimworld`, 2026-10-09) files
no need after N-9; see *Decisions needed*, 5. M3-T1 also lays the scaffold of the module
`algorithms` that M3-T2 would otherwise edit at the same lines, as M2-T0 did for L-M2.

| Task | Brief | Owns | Profile | Review | Runs after |
|---|---|---|---|---|---|
| M3-T1 | [algorithms](LIB-06b-M3-T1-algorithms.md) | `algorithms.cairo` (first), `algorithms/{field_of_movement,pathfinding}.cairo`, the scaffold of `algorithms/fov.cairo`, the `algorithms` block of `lib.cairo`, the `CAIRO_MODULE_OWNER` entries of `algorithms` in `scripts/api_parity.py`, the `refgen` arms of L-M3, the consumer's `mod` lines of L-M3 | `impl-sonnet` (two forwarding counterparts whose contracts this brief writes in full) | `review-opus` | 0.2.0 published (D-211, done) |
| M3-T2 | [fov](LIB-06b-M3-T2-fov.md) | `algorithms/fov.cairo`, `algorithms.cairo` (then, its one `pub use` line) | `impl-opus` (design open: the prefix of a line up to the first wall, from a bitmap or by a walk, and lines that leave the board) | `review` (Sonnet) | M3-T1 |
| M3-T3 | [glam](LIB-06b-M3-T3-glam.md) | `crates/hexx_glam/**`, the five interop rows of `scripts/api_parity.py` (then), the shared files of a new package (below) | `impl-sonnet` | `review-opus` | M3-T1 (shares `scripts/api_parity.py` and `crates/consumer/src/lib.cairo` with it) |
| M3-R | — (orchestrator) | — | — | parity audit (D-177) | every task above |

**Order and parallel groups**: `T1`; then `T2` with `T3` (disjoint files once T1 has merged). At
most two working threads at once, which is the pool rule of 2026-10-07 for LIB. M3-T2 is the
critical path: start it the moment M3-T1 merges, and M3-T3 beside it.

No task depends on an item of a task that does not precede it: M3-T1 and M3-T2 consume only items
of L-M1 and L-M2 (`HexMapTrait`, `Dial`, `LineTrait`, `HexagonTrait`, the board's `to_hex` /
`from_hex`, `HexTrait::{line_to, diagonal_way_to, z}`, `HexRingsTrait::ring`,
`EdgeDirection::vertex_directions`, `DirectionWay::contains`), all on `main`; M3-T3 consumes
`Hex` and `HexTrait::z` of L-M1.

## Shared files, and why the groups do not collide

| File | Who writes it |
|---|---|
| `crates/hexx/src/lib.cairo` | M3-T1 only: one block, `pub mod algorithms;` |
| `crates/hexx/src/algorithms.cairo` | M3-T1 (the three `pub mod` lines and its own `pub use` lines), then M3-T2 (its one `pub use` line) |
| `crates/hexx/src/algorithms/fov.cairo` | M3-T1 creates it with its module doc only; M3-T2 owns it after |
| `scripts/api_parity.py` and `scripts/tests/test_api_parity.py` | M3-T1 (the three `CAIRO_MODULE_OWNER` entries of `algorithms`), then M3-T3 (the scan of `crates/hexx_glam/src` for the five interop items, *Decisions needed* 3) |
| `tools/refgen/src/main.rs` | M3-T1 only: the arms `algorithms` and `fov` (M3-T2 owns `fov.rs` and `specs/fov.toml`) |
| `crates/consumer/src/lib.cairo` | M3-T1 (`mod mirror_algorithms;`, `mod mirror_fov;`), then M3-T3 (`mod mirror_glam;`) |
| `crates/consumer/Scarb.toml` | M3-T3 only (the `hexx_glam` path dependency) |
| `Scarb.toml` (root), `Scarb.lock`, `.github/workflows/ci.yml`, `scripts/tests/test_bench_gate_split.py`, `gas/hexx_glam.snap` | M3-T3 only: what AGENTS.md ("Golden tests") requires of a new package. `ci.yml` is edited with the file-editing tool, in M3-T3's own pull request, and said in its report; a refusal is an escalation |
| `crates/golden_lm2/tests/` | M3-T1 (`golden_algorithms.cairo`) and M3-T2 (`golden_fov.cairo`): distinct files of one package, each at most 2,000 lines, so the package stays under 8,000 (3,241 at `main`; AGENTS.md "Golden tests"). No new golden package, so no change to `ci.yml` for them |
| `docs/API_PARITY.md`, `EXTENSIONS.md`, `DEVIATIONS.md`, `GAS.md`, `gas/hexx.snap`, `gas/golden_lm2.snap`, `gas/bytecode.size` | every task, **generated**: never hand-merged; a task whose pull request conflicts after another merge merges `origin/main` into its branch and regenerates them on Linux (the `hexx` pins from CI's artefact, AGENTS.md "Gas pins from CI") |

## What every brief carries

The contract of each counterpart, normative (plan §1.4), with its hexx-side statement so that
`tools/refgen` can check it against the real crate; the targets derived from the L-M1 and L-M2
measurements in `gas/hexx.snap` at `f82f1cb` (plan §7 has none for L-M3), with the stop at twice
the upper bound; the programme rule on measurements (Linux only for every committed pin, both
figures for a Mac/Linux difference, no class hash claimed reproducible across machines); the
memory rule (AGENTS.md, "How tests are scoped": `hexx` test targets on CI or the Mac only, D-212;
an unknown peak is measured first); whether an audit is expected (none per task, D-177); the
reviewer's model, another than the implementer's.

## Decisions needed

Points where the plan, read against the code since L-M1 and L-M2, is wrong, impossible or silent.
Each has a recommendation, which the task briefs follow until the orchestrator rules otherwise.

1. **`range_fov` at the edge of the board** (plan §4.4, `range_fov` row). The plan's sketch takes
   "every tile of `hexagon_ring(from, range)`", which is the ring *clipped to the board*. `hexx`
   walks the whole ring (`fov.rs:31-32`): a tile seen only along a line towards a ring tile off the
   board (from `(2, 7)` at range 6, the tile `(1, 7)` lies only on lines to targets of column ≤ −4)
   is visible in `hexx` with `blocking = wall or off the board`, and missing from the sketch. The
   board's `line` cannot serve those lines either: it takes two positions inside the board and
   returns `None` for a line that leaves it (D-27). **Recommendation (b)**: the contract is `hexx`'s
   `range_fov` on the whole ring with `blocking(h) = h off the board or a wall`; the line walk stops
   at the first such tile. Equal to the sketch whenever the ring lies within the board, which is the
   game's sight (radius 6 from `(7, 7)` or `(7, 8)` on the 15 × 16 window). Option (a), the
   sketch, is cheaper and loses those tiles: what would choose it is a cost the game cannot pay,
   with the loss written as a deviation.
2. **The tie rule of the lines of the fov** (plan §4.4: "the lines carry the game's tie rule
   (§6.6)"). The plan is kept: the game's rule (lower tile index), so that the fov and
   `line_of_sight` agree on every line they share; `tools/refgen` has the rule in Rust
   (`line::rule`) and lists the cases where it differs from `hexx`'s `line_to`. The alternative is
   exact parity through the mirror's `HexTrait::line_to`. **Recommendation: keep the plan.** What
   would reverse it: the orchestrator ruling that a counterpart of the mirror must equal `hexx`
   bit for bit where it can.
3. **The five interop items can never read `ported`** (plan §8, L-M3 exit: "No `missing` item").
   `scripts/api_parity.py:181-200` scans `crates/hexx/src` only and says so by design (LIB-04 fix
   loop 2, finding 3: a mapping to code another package holds "must read `missing` forever"), so
   the exit criterion cannot be met by any code. **Recommendation**: M3-T3 extends the scan to
   `crates/hexx_glam/src` for exactly those five keys (`_INTEROP_ITEMS`), with its unit tests; the
   rows then read `ported` or `renamed` only once the items exist there. M3-T3's allowlist carries
   the edit. What would reverse it: the orchestrator prefers the five as `dropped` with a reason
   ("in the companion package `hexx_glam`"), which the exit criterion would then need to say.
4. **`glam` exists in Cairo** (plan §2.1, §4.4: "`IVec2`/`IVec3` of `glam-cairo`"). Verified on
   2026-10-09: `glam` 0.5.0 is on scarbs.xyz (`glam_core` holds `pub struct IVec2 { pub x: i32,
   pub y: i32 }` and `IVec3 { x, y, z: i32 }`, derives `Copy, Drop, Serde, PartialEq, Debug,
   Default, Hash`; `cairo-version = "^2.20.0"`, the toolchain of this repository). So nothing is
   `dropped`: the interop is ported as the plan says, in `crates/hexx_glam`. Not a decision; the
   choice of dependency (`glam` or `glam_core`) is made in M3-T3's brief.
5. **The fourth task of the plan, "the game's new needs"**: none is filed (the game's
   `docs/needs/hexmap.md` stops at N-9 and the D-134 borders). **Recommendation**: L-M3 ships with
   three tasks; a need filed before M3-R becomes M3-T4 with its own brief, and 0.3.0 waits for it
   only if the project manager says so. The orchestrator confirms with the project manager that no
   need is pending (the clone read may be stale).
6. **`uint252` at L-M3** (plan §8 L-M3 "Content": "the `uint252` dependency if the owner decides on
   `u252`-typed bitmaps"). No decision is recorded; no task of this cut adds the dependency.
   **Recommendation**: none in L-M3; it stays with the owner's question of §12.
7. **`Sum` and `Product` of `Hex`** stay `dropped` as deferred (`PLAN.md`, Deferred, #107), so they
   do not stop the L-M3 exit. One fact for that deferral: `glam_int` 0.5.0, a published package of
   the same house, sets `experimental-features = ["associated_item_constraints"]` in its published
   manifest, which is what the deferral waited for. **Recommendation**: leave them deferred in L-M3
   (out of its scope); the project manager may reopen them as their own lot.

### Decided in these briefs (reversible)

Contracts the plan's rows leave silent, chosen to follow `hexx` where it costs one check:

- `a_star` accepts an open edge `from`: its closure excludes edge tiles other than both endpoints
  (review of #129).
- `a_star` returns `None` (not a panic) when an endpoint is a wall or outside the board, as `hexx`'s
  `cost(end, end)?` and `cost(start, start)?` (`pathfinding.rs:114, 117`); `Some([from])` when
  `from == to`. Its cost model is not `field_of_movement`'s: `hexx`'s `a_star` adds the cost as
  given (`:134`), its `field_of_movement` adds `1 +` (`field_of_movement.rs:90`), so the same board
  `costs` maps to two different `hexx` closures (M3-T1, Scope 2). Reverse: a consumer that wants
  the board's panic.
- `field_of_movement` from a wall returns what `hexx` does (the start, plus what it reaches: `hexx`
  never pays the start's cost, `:69`), not the board's panic `'Dial: position not walkable'`.
- `budget` and `range` are `u8` (the board's), `hexx`'s are `u32`: a documented deviation.
- `hexx_glam` is versioned with the workspace (`0.3.0`) and published after `hexx` 0.3.0, on which
  it depends by published version.

## M3-R — release 0.3.0

The orchestrator's, as M2-R: `python3 scripts/api_parity.py --check-release L-M3` passes (no
`missing` item in a kept or adapted module), every deviation documented, benches for every
non-trivial function, `CHANGELOG.md` with its four headings (`Results changed` empty: L-M3 adds
items and changes no result of 0.2.0), then the publication procedure of COMMON.md §6, repeated:

- No sub-agent publishes, ever (not a registry, not a tag, not a release); the orchestrator's
  session publishes, after a go that names the package, the version and the commit.
- The request is `docs/decisions/PENDING-publish-hexx-0.3.0.md` (and `…-hexx_glam-0.3.0.md`):
  package, version, commit, what changed, what the consumer must do; one message to the project
  manager with its path.
- Checked before the go: the commit on `main` with every CI check green; audits closed without
  blocker or major; changelog and version agree; the gas tables are those of that commit; `scarb
  package` from a clean checkout and the archive sha256 on Linux (D-182); name and version free on
  the registry (`hexx_glam` is a **new package name**: check it first); no test dependency
  declared as a regular one.
- Order: `hexx` 0.3.0 published and visible on the registry, then `hexx_glam` 0.3.0 (its manifest
  depends on `hexx = "0.3.0"`); each tagged and released when the registry shows it.

0.3.0 is a stable version: the go is the owner's (D-132 as narrowed: release candidates are the
project manager's, stable versions the owner's). **One audit** before publication, under D-177's
"a published interface once before its publication": the parity lens over the published interface
of L-M3, the four counterparts and `hexx_glam`'s first publication together. No task of L-M3 is a
D-177 exception (no value, no access control, no randomness: the algorithms are deterministic,
their ties fixed by the board's lowest-index rule), so no per-task audit.
