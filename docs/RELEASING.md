# Releasing `hexx`

**D-132: no agent and no workflow publishes.** A publication is made by the orchestrator
session, by hand, from a clean checkout of a named commit — never by a CI job, never by a script
running unattended, never by any agent acting on its own judgement. It happens only after a go
from the project manager that names the package, the version and the commit, and the tag and the
GitHub release come only after the registry itself shows the version. No workflow of this
repository holds or reads the registry token: there is no `environment:` block, no
`SCARB_REGISTRY_AUTH_TOKEN` secret and no `scarb publish` step anywhere under
`.github/workflows/`. This supersedes the previous (fix loop 1) design, in which
`.github/workflows/publish.yml` ran `scarb publish` itself, gated by a required-reviewer
environment; that workflow is deleted.

## The pending file

Before a release, the orchestrator opens `docs/decisions/PENDING-publish-hexx-<version>.md`
(the naming convention of `docs/decisions/README.md`: `PENDING-<gate>.md`, renamed once decided).
It records:

- the package (`hexx`) and the exact version string to publish;
- the exact commit sha the release is cut from (a commit already on `main`);
- a link to the green run of `.github/workflows/release-check.yml` dispatched against that
  version and that sha — the evidence the project manager reviews, not a re-run of the checks by
  hand;
- anything the project manager needs to sign off: the milestone the version implies
  (`docs/RELEASING.md`'s table below), `docs/API_PARITY.md`'s state, open deviations.

## What the project manager checks

The project manager's go is bound to a specific commit, not to "the current state of `main`" or
to a branch name: a later commit on `main`, even one that only fixes a typo, needs a new go. Before
giving it, the project manager:

1. Confirms the pending file names a package, a version and a full 40-character commit sha, and
   that the sha is on `main`.
2. Dispatches (or asks the orchestrator to dispatch) **Actions → Release check → Run workflow**
   **from `main`** — the dropdown's "Use workflow from" field, not just the `sha` input — with
   that exact `version` and `sha`, and waits for it to go green. A run dispatched from any other
   branch fails its own first step and is not evidence for a go (fix loop 3 decision P2-2: a
   workflow file modified on another branch could weaken or remove every guard below while still
   checking out a legitimate `main` commit afterward). The workflow (below) is the evidence, not a
   formality: it fails loudly if `sha` is not a full commit hash, if the checked-out commit does
   not exactly match it, if it is not an ancestor of `main`, if the version does not match the
   manifest, if the version is not valid semver, if the tag already exists (or the tag lookup
   itself failed — network and auth errors fail the guard closed, fix loop 3 finding 17), if any
   check of `scripts/check.sh` (golden vectors included) fails, or — for a **stable** version only
   — if an item the version's milestone requires is still `missing` in `docs/API_PARITY.md`. For a
   **pre-release** version, that last check is informational (below): read its job summary, don't
   rely on its exit code.
3. Inspects the uploaded artifact (the packaged `Scarb.toml`, a listing of the archive's contents,
   and the milestone-check report) for anything unexpected — an extra file, a missing one, a
   dependency that should not be there, or, for a pre-release, a missing item the project manager
   did not expect to still be open.
4. Records the go: renames the pending file, or replaces its content with the decision and its
   date, per `docs/decisions/README.md`'s convention.

## `.github/workflows/release-check.yml`: what it verifies, not what it does

Manual trigger only (`workflow_dispatch`, inputs `version` and `sha`), `permissions: contents:
read` — it cannot write to the repository, create a tag or a release, even if a step tried to.
No secret, no `environment:`, no `scarb publish`. In order:

1. Verifies that this run's own workflow revision is `refs/heads/main` (`GITHUB_REF`, a shell
   environment variable GitHub Actions itself sets — never a `${{ }}` expression interpolated into
   a script) — fix loop 3 decision P2-2: `workflow_dispatch` lets any branch be selected as "Use
   workflow from"; a run from elsewhere is not evidence for a go, whatever `sha` it later checks
   out.
2. Verifies that the input `sha` is a full 40-character lowercase hex commit hash.
3. Checks out exactly the input `sha`, then verifies `git rev-parse HEAD` equals it exactly.
4. Verifies that `sha` is an ancestor of `origin/main` — never a fork's ref, never an unmerged
   branch.
5. Verifies that the input `version` equals `Scarb.toml`'s `[workspace.package].version`.
6. Verifies that `version` has valid semver syntax.
7. Verifies that no tag `v<version>` exists yet on the remote — `git ls-remote --exit-code`'s exit
   code 2 ("no match") is the only one read as "absent"; any other nonzero code (a network or auth
   failure) fails the job closed instead of silently passing this guard (fix loop 3 finding 17).
8. Runs `scripts/check.sh` with the golden-vector check mandatory (it installs the Rust
   toolchain itself, so `tools/refgen`'s check can never be silently skipped here).
9. Derives the milestone the version implies from the table below, and runs
   `python3 scripts/api_parity.py --check-release <milestone>` — **enforced** (fails on any
   `missing` item the milestone requires) for a **stable** version; **informational**
   only (`--report-only`: the same missing-item list prints, to the job summary and the uploaded
   artifact, the whole list, but the step always exits 0) for a **pre-release** version (a hyphen in
   the part of the version before any `+`, `0.1.0-rc.N`; `0.1.0+build-1` is stable — decided by
   `python3 scripts/api_parity.py --is-prerelease <version>`, not by a pattern in the workflow) — fix loop 3 decision P2-13, plan §9.1/§9.2: a release candidate carries only part
   of the milestone it maps to by design, so failing it on the rest of that milestone would make
   every planned release candidate red by construction.
10. Runs `scarb package -p hexx` and uploads the packaged `Scarb.toml`, a listing of the archive's
    contents, and the milestone-check report (not the archive itself: a workflow that does not
    publish has no reason to keep the compressed bytes around).

Every version in this table maps to a milestone; whether that milestone's gate is enforced or only
reported depends on whether the version itself carries a pre-release identifier (a hyphen before any `+`), not on
which row it falls into — plan §9.1 lists the release candidates this predates each stable version:

| Version | Milestone | Content (plan §9.1) | Gate |
|---|---|---|---|
| `0.1.0-rc.1` | L-M1 | The take-over (M1-T1), the mirror items of L-M1, N-3, N-4, N-5, N-7, N-8: the content agreed with the project manager for the game's ENG-02 (2026-09-29), which supersedes plan §9.1's "take-over alone" | Informational |
| `0.1.0-rc.2` … | L-M1 | N-1 and N-2 (for the game's ENG-05), then N-6 | Informational |
| `0.1.0` | L-M1 | L-M1 complete (plan §9.2: the mirror items of L-M1 are API from here) | Enforced |
| `0.2.0-rc.N` | L-M2 | L-M2 work in progress | Informational |
| `0.2.0` | L-M2 | L-M2 complete | Enforced |
| `0.3.0-rc.N` | L-M3 | L-M3 work in progress | Informational |
| `0.3.0` | L-M3 | L-M3 complete | Enforced |
| `1.0.0-rc.N` | L-M4 | Parity or documented exclusions, in progress | Informational |
| `1.0.0` | L-M4 | Parity or documented exclusions; `origami_hexmap` decommissioned | Enforced |

## Publication itself: the orchestrator session, by hand

Once the project manager's go is recorded:

1. The orchestrator session clones (or fetches into) a clean checkout of the repository, then
   checks out exactly the commit sha the go names — not `main`'s tip, not a rebase, not a merge:
   the same sha the release-check workflow ran green against.
2. The orchestrator session runs `scarb package -p hexx` and `scarb publish -p hexx` from that
   checkout, by hand, with a registry token it holds itself (never a repository or environment
   secret — no workflow of this repository has one to hand it).
3. The orchestrator session confirms the version on the registry (`scarbs.xyz/packages/hexx`)
   before doing anything else. Nothing below happens until the registry shows the version.
4. Once confirmed, the orchestrator session tags the released commit by hand, `v<version>`, and
   creates the GitHub release from that tag.
5. `CHANGELOG.md`'s `[Unreleased]` heading is updated to the released version and date, if the
   pull request that reached this state had not already done so.

## After publication: need N-9

N-9 (`snforge_std` a dev-dependency of `hexx`, so it must not resolve as a regular dependency of
a consumer of the *published* package — the defect that hit `origami_hexmap` 1.8.0, plan §2.1)
is demonstrated on the artifact the registry actually serves, not on `Scarb.toml`: the two
consumer packages of `tools/consumer_check/` (task M1-N9, not LIB-04) resolve and build against
`hexx = "<version>"` from the registry, and the registry's own index entry for that version lists
`snforge_std` only as a dependency of kind `test`. This check runs after every publication,
against the published package (`.github/workflows/consumer_check.yml`), never against the
manifest alone. The cause of 1.8.0's defect is the consumer's resolver, not the artifact: Scarb
2.13.1 counts a dependency's `kind: test` entries as constraints, Scarb 2.19.4 does not, for
`origami_hexmap` 1.8.0 and `hexx` 0.1.0-rc.1 alike (`docs/research/N-9-cause.md`). N-9 therefore
holds for consumers on Scarb 2.19.4, the game's toolchain.

## What LIB-04 rehearsed, and what it never touched

LIB-04 rehearsed the pipeline up to `scarb package -p hexx` only, and wrote
`.github/workflows/release-check.yml` as a check, never a publish step. It never ran `scarb
publish`, never created a tag, never configured a registry secret, and never asked for one: under
D-132, no workflow of this repository ever will.
