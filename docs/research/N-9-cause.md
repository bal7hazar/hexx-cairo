# N-9: the cause of `origami_hexmap` 1.8.0's defect

Task M1-N9, 2026-10-01. Status: **cause found**. The artifact is not the cause: Scarb's resolver
on 2.13.1 (earlier versions not tested) counts a dependency's `kind: test` entries as constraints, and Scarb 2.19.4 does not
("Reproduction", run by the orchestrator on both versions). Still unknown: the first Scarb release
that resolves correctly, in `(2.13.1, 2.19.4]` ("What remains unknown").

## The failure reported

`bal7hazar/grimworld`, `docs/needs/hexmap.md` § "N-9 in detail", failure 1 (read only): next to
`dojo_snf_test` 1.8.0 on Scarb 2.13.1, *"origami_hexmap 1.8.0 depends on snforge_std
>=0.61.0, <0.62.0"* — the consumer's own `snforge_std` (0.51.x) was in conflict with the range.

## Evidence

Items 1 to 4, by the agent on 2026-10-01, on Scarb 2.19.4 from this repository's worktree; the
section "Reproduction" below ran both 2.13.1 and 2.19.4.

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
   `snforge_std =0.60.0` (outside `^0.61.0`), builds and passes its test (the consumer check's run `36836722939` on pull request #70).

## Reproduction (the orchestrator, 2026-10-01)

Run by the orchestrator (`[Opus 5.5]`) with the two Scarb versions already installed on the VPS
through asdf (`asdf list scarb`: 2.13.1, 2.19.4; nothing downloaded). One consumer per row, in a
scratch directory, `scarb fetch`:

```toml
[dependencies]
origami_hexmap = "=1.8.0"        # or: hexx = "=0.1.0-rc.1"

[dev-dependencies]
snforge_std = "=0.51.2"
```

| Scarb | Dependency | Result |
|---|---|---|
| 2.13.1 (`a76aed717 2025-10-30`) | `origami_hexmap =1.8.0` | `error: version solving failed: … origami_hexmap 1.8.0 depends on snforge_std >=0.61.0, <0.62.0 … c 0.1.0 depends on snforge_std >=0.51.2, <0.51.3, c 0.1.0 is forbidden.` |
| 2.19.4 (`b45b74c03 2026-07-21`) | `origami_hexmap =1.8.0` | resolves; `Scarb.lock` holds `snforge_std` 0.51.2 only |
| 2.13.1 | `hexx =0.1.0-rc.1` | `error: version solving failed: … hexx 0.1.0-rc.1 depends on snforge_std >=0.61.0, <0.62.0 … c 0.1.0 is forbidden.` |
| 2.19.4 | `hexx =0.1.0-rc.1` | resolves; `Scarb.lock` holds `snforge_std` 0.51.2 only |

## Conclusion

- **The cause is Scarb's resolver on 2.13.1** (earlier versions not tested): it counts a registry dependency's `kind: test`
  entries as constraints of the consumer. The artifact and the index entry are not at fault: both
  packages, published the same way (`snforge_std` under `[dev-dependencies]`, `kind: test` in the
  index), fail on 2.13.1 and resolve on 2.19.4. Failure 1 of the game is reproduced without
  `dojo_snf_test`: a consumer's own `snforge_std` outside `^0.61.0` is enough.
- **N-9, reduced, holds for consumers on Scarb 2.19.4**, the game's toolchain since ADR-0007 and the
  library's (`.tool-versions`); it does not hold on Scarb 2.13.1. The first Scarb version that
  resolves correctly lies in `(2.13.1, 2.19.4]`; only those two are installed here, and a bisection
  would need downloads (not done).
- **The manifest**: no line is missing for consumers on Scarb 2.19.4. On 2.13.1 the constraint
  comes from the index's `kind: test` entry, which exists because `hexx` declares a
  dev-dependency; publishing `hexx` with no dev-dependency (its tests moved to an unpublished
  package) would remove that entry, and an entry with empty `deps` would then resolve on 2.13.1.
  That is an inference, not tested; whether a consumer on Scarb 2.13 is worth that restructuring
  is the owner's to decide. It has no beneficiary today: `hexx` declares `cairo-version = "2.19.4"`
  and does not compile on Cairo 2.13 (`BoundedInt` is not visible there,
  `docs/briefs/LIB-03b-compiler-target.md`), so a consumer that can build it already resolves
  correctly.

## What remains unknown

- The first Scarb release with the corrected resolution, between 2.13.1 and 2.19.4.
- Whether `dojo_snf_test` 1.8.0 added a constraint of its own in the game's original setup (not
  needed to reproduce the failure).

## Manifest

No line of `crates/hexx/Scarb.toml` is missing as far as this evidence goes: `snforge_std` is
under `[dev-dependencies]` and the published index lists it as `kind: test`, as for 1.8.0.
