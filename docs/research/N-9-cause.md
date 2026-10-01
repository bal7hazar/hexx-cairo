# N-9: what is known about `origami_hexmap` 1.8.0's defect

Task M1-N9, 2026-10-01. Status: **partly answered**. The artifact is not the cause; the
component that turned the test dependency into a constraint, and the Scarb version from which it
no longer does, are **not established**, because the reproduction on Scarb 2.13.1 could not be run
(see "What remains unknown").

## The failure reported

`bal7hazar/grimworld`, `docs/needs/hexmap.md` § "N-9 in detail", failure 1 (read only): next to
`dojo_snf_test` 1.8.0 on Scarb 2.13.1, *"origami_hexmap 1.8.0 depends on snforge_std
>=0.61.0, <0.62.0"* — the consumer's own `snforge_std` (0.51.x) was in conflict with the range.

## Evidence

All on 2026-10-01, Scarb 2.19.4, from this repository's worktree.

1. **The registry entry of `origami_hexmap` 1.8.0 and of `hexx` 0.1.0-rc.1 have the same form.**

   ```
   $ curl -s https://scarbs.xyz/api/v1/index/or/ig/origami_hexmap.json
   [{"v": "1.8.0", "deps": [{"name": "snforge_std", "req": "^0.61.0", "kind": "test"}], "cksum": "sha256:789ecf7b…444bd"}]
   $ curl -s https://scarbs.xyz/api/v1/index/he/xx/hexx.json
   [{"v": "0.1.0-rc.1", "deps": [{"name": "snforge_std", "req": "^0.61.0", "kind": "test"}], "cksum": "sha256:9313e06b…ca1500"}]
   ```

   Both list `snforge_std ^0.61.0` with `"kind": "test"`. Note: `docs/RELEASING.md` § "After
   publication: need N-9" says the index entry "lists no `snforge_std` dependency"; the real entry
   lists it as a `test` dependency. The wording is inaccurate (a proposal, not an edit: that file
   is the orchestrator's).

2. **The published archive of `origami_hexmap` 1.8.0 declares it as a dev-dependency.**
   `curl -fsSL https://scarbs.xyz/api/v1/dl/origami_hexmap/1.8.0` → `Scarb.toml` of the archive:

   ```toml
   [dependencies]

   [dev-dependencies.snforge_std]
   version = "^0.61.0"
   ```

   The manifest is correct; the artifact does not put `snforge_std` among the regular
   dependencies.

3. **Scarb 2.19.4 does not turn it into a constraint on the consumer.** A package depending on
   `origami_hexmap = "=1.8.0"` with `[dev-dependencies] snforge_std = "=0.51.2"` (the failing
   shape of failure 1, minus `dojo_snf_test`) resolves and builds:

   ```
   $ scarb build
      Compiling n9_repro v0.0.0 (…/work/n9/Scarb.toml)
       Finished `dev` profile target(s) in 2 seconds
   ```

   Its `Scarb.lock` has `origami_hexmap 1.8.0` with no dependency, and one `snforge_std 0.51.2`
   (the consumer's) — no 0.61.x.

4. **The same holds for `hexx`**, tested by the deliverable of this task (`tools/consumer_check/`):
   against `hexx 0.1.0-rc.1`, `plain`'s lock has no `snforge_std`, and `with_tests`, pinned on
   `snforge_std =0.60.0` (outside `^0.61.0`), builds and passes its test (see `REPORT.md`).

## Conclusion

- The defect is **not in the published artifact's manifest**, and the index entry is the same as
  `hexx`'s. With Scarb 2.19.4 the shape that failed on 2.13.1 resolves.
- The lead of the brief (a Scarb version's resolution of a dependency's test dependencies) is
  **consistent with the evidence but not proved**: it needs the failure itself reproduced.

## What remains unknown, and why

- Reproduction on Scarb 2.13.1: the release archive was downloaded under `work/scarb-2.13.1/`
  (git-ignored) but the permission profile refused to execute it ("This command requires
  approval"). Not worked around. Needed: permission to run
  `work/scarb-2.13.1/scarb-v2.13.1-x86_64-unknown-linux-gnu/bin/scarb build` in `work/n9/` (the
  consumer of evidence 3, same `Scarb.toml`).
- Which component (Scarb's resolver, or its handling of the registry index's `kind`) added the
  constraint, and from which Scarb version it no longer does: undetermined. Once the 2.13.1 failure
  is reproduced, bisecting the Scarb releases between 2.13.1 and 2.19.4 with the same `Scarb.toml`
  answers it.
- Whether the game's failure also involved `dojo_snf_test` 1.8.0's own manifest: not tested.

## Manifest

No line of `crates/hexx/Scarb.toml` is missing as far as this evidence goes: `snforge_std` is
under `[dev-dependencies]` and the published index lists it as `kind: test`, as for 1.8.0.
