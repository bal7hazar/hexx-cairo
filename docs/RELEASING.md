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

1. Confirms the pending file names a package, a version and a commit sha, and that the sha is on
   `main`.
2. Dispatches (or asks the orchestrator to dispatch) **Actions → Release check → Run workflow**
   with that exact `version` and `sha`, and waits for it to go green. The workflow (below) is the
   evidence, not a formality: it fails loudly if the sha is not an ancestor of `main`, if the
   version does not match the manifest, if the version is not valid semver, if the tag already
   exists, if any check of `scripts/check.sh` (golden vectors included) fails, or if an item the
   version's milestone requires is still `missing` in `docs/API_PARITY.md`.
3. Inspects the uploaded artifact (the packaged `Scarb.toml` and a listing of the archive's
   contents) for anything unexpected — an extra file, a missing one, a dependency that should not
   be there.
4. Records the go: renames the pending file, or replaces its content with the decision and its
   date, per `docs/decisions/README.md`'s convention.

## `.github/workflows/release-check.yml`: what it verifies, not what it does

Manual trigger only (`workflow_dispatch`, inputs `version` and `sha`), `permissions: contents:
read` — it cannot write to the repository, create a tag or a release, even if a step tried to.
No secret, no `environment:`, no `scarb publish`. In order:

1. Checks out exactly the input `sha`.
2. Verifies that `sha` is an ancestor of `origin/main` — never a fork's ref, never an unmerged
   branch.
3. Verifies that the input `version` equals `Scarb.toml`'s `[workspace.package].version`.
4. Verifies that `version` has valid semver syntax.
5. Verifies that no tag `v<version>` exists yet on the remote.
6. Runs `scripts/check.sh` with the golden-vector check mandatory (it installs the Rust
   toolchain itself, so `tools/refgen`'s check can never be silently skipped here).
7. Derives the milestone the version implies from the table below, and runs
   `python3 scripts/api_parity.py --check-release <milestone>`: fails if an item that milestone
   requires is still `missing`.
8. Runs `scarb package -p hexx` and uploads the packaged `Scarb.toml` and a listing of the
   archive's contents (not the archive itself: a workflow that does not publish has no reason to
   keep the compressed bytes around).

| Version | Milestone |
|---|---|
| `0.1.x` | L-M1 |
| `0.2.x` | L-M2 |
| `0.3.x` | L-M3 |
| `1.x` | L-M4 |

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
no `snforge_std` dependency. This check runs after every publication, against the published
package, never against the manifest alone — the manifest already declaring `[dev-dependencies]`
correctly did not stop 1.8.0's defect (plan §2.1, R-17).

## What LIB-04 rehearsed, and what it never touched

LIB-04 rehearsed the pipeline up to `scarb package -p hexx` only, and wrote
`.github/workflows/release-check.yml` as a check, never a publish step. It never ran `scarb
publish`, never created a tag, never configured a registry secret, and never asked for one: under
D-132, no workflow of this repository ever will.
