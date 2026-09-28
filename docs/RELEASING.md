# Releasing `hexx`

**Every publication needs the owner's explicit go, each time** (decision L-G2: "the orchestrator
does not publish and does not ask again: the project manager carries the question"). Nothing in
this repository — no workflow, no script, no agent profile — is allowed to publish, tag or
release on its own; `.github/workflows/publish.yml` only runs when the owner dispatches it by
hand, from `main`, and only after every guard in it passes.

## Prerequisites: settings of the owner, not something a workflow can create

These live in the repository's GitHub settings, outside any file this repository commits. A
workflow file cannot grant itself an approval gate or a secret; both are configured by the owner,
once, before the first release:

| Setting | Where | What it does |
|---|---|---|
| The `publish` environment | Repository → Settings → Environments → `publish` | `.github/workflows/publish.yml`'s job runs `environment: publish`; GitHub will not start that job until the environment's own rules are satisfied |
| A required reviewer on `publish` | Same environment, "Deployment protection rules" | The actual approval gate: someone (the owner, or whoever the owner names) must approve the run before it proceeds, even though the workflow's own guards (ref, actor, version, tag) already passed |
| `SCARB_REGISTRY_AUTH_TOKEN` | Same environment's own secrets (not the repository's) | The scarbs.xyz registry token, read only by the `Publish crates/hexx` step of `publish.yml`, and only once the environment's protection rules clear. Scoping it to the environment, not the repository, means no other workflow — including this one on a different ref — can ever read it |

Without the environment's required reviewer, `environment: publish` alone still restricts
*where* the secret is visible, but does not stop the workflow from running to completion by
itself once dispatched: the reviewer is what turns "an owner can dispatch this" into "an owner
must also confirm this specific run."

## What the workflow itself checks (`.github/workflows/publish.yml`)

Manual trigger only (`workflow_dispatch`, one input, `version`), never a tag push. Four guards,
each its own step, before the checks or the packaging run:

1. The ref is `refs/heads/main` — never a branch, never a fork's ref.
2. The actor is the repository owner (`github.actor == github.repository_owner`).
3. The `version` input equals the version `Scarb.toml`'s `[workspace.package]` actually declares
   — a typo in the dispatch form fails loudly instead of publishing the wrong version.
4. No tag `v<version>` exists yet on the remote — a version cannot be published twice under this
   process.

Then: the full local gate (`scripts/check.sh`), `scarb package -p hexx`, and only then
`scarb publish -p hexx` (`SCARB_REGISTRY_AUTH_TOKEN` from the `publish` environment). The workflow
never creates a tag itself (`permissions: contents: read` — it cannot write to the repository even
if a step tried to).

## Steps of a release

1. The owner decides a version is ready (through the project manager, per L-G2) and merges
   whatever pull request brings `crates/hexx`, `CHANGELOG.md` and `docs/API_PARITY.md` to that
   state, on `main`.
2. The owner (or whoever they name, confirmed by the `publish` environment's required reviewer)
   opens **Actions → Publish → Run workflow**, on `main`, with `version` set to the exact string
   `Scarb.toml`'s `[workspace.package].version` carries.
3. The four guards run; any failure stops the workflow before anything is built or packaged.
4. `scripts/check.sh` runs the full gate. `scarb package -p hexx` builds the archive.
5. The `publish` environment's required reviewer approves the run.
6. `scarb publish -p hexx` publishes to scarbs.xyz, reading the token from the environment's own
   secret.
7. The orchestrator tags the released commit **by hand**, `v<version>`, once publication is
   confirmed (`scarbs.xyz/packages/hexx`) — the workflow does not do this for them.
8. The orchestrator (or a following task) updates `CHANGELOG.md`'s heading from `[Unreleased]` to
   the released version and date, if that pull request had not already done so.

## What this task (LIB-04) rehearsed, and what it never touched

LIB-04 rehearsed the pipeline up to `scarb package -p hexx` only — a real, local run, whose
output and file list are in `docs/reports/LIB-04-REPORT.md`, "Fix loop 1" and the original
report's Scope item 7. It never ran `scarb publish` (its `implement` profile refuses the command
outright), never created a tag, and never asked for or touched a registry token. No environment,
no required reviewer and no registry secret were configured by this task either: those are the
owner's own settings, listed above, to put in place before the workflow is ever dispatched for
real.
