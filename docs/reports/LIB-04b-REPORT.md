# [Sonnet 5.5] LIB-04b — tooling findings

## Summary

The three findings of the LIB-04 audit (pass 4) are fixed. Pull request: https://github.com/bal7hazar/hexx-cairo/pull/26 (CI green, all checks passed).

1. *New 1* (parity tool): `collect_use_statements` now resolves re-exports transitively. It follows a `pub use` of a `pub use` through private modules, follows names reached through globs, and closes the set of modules exposed by `pub use ...::*` transitively. `bridged[decl_path][name]` is now a sorted *list* of every exported name, so the same item exported twice (`Hex` and `Other`) keeps both. New `exported_names` and `exported_name_at`; `exported_name` is kept (first name). Both scanners (`parse_hexx`, `scan_cairo_tree`) make one pass per export rank, so every name yields its items. Unsupported forms raise `SystemExit` with file:line: a cycle of named re-exports, and the re-export of a module (`pub use a as b`, `pub use a::{self}`). A cycle through globs is legal Rust and resolves without error.
2. *New 2* (release check): `is_prerelease()` in `scripts/api_parity.py`, with a new `--is-prerelease VERSION` mode that prints `true`/`false`. A version is a pre-release iff the part before any `+` holds a hyphen. The workflow calls it; the shell pattern `*-*` is gone.
3. *P2-13* (release check): the list is no longer truncated (the `[:40]` is gone). In `--report-only` mode it goes to stdout. The enforced failure still goes to stderr. The workflow step captures both (`2>&1 | tee`) and writes the job summary even when the check fails (`|| status=$?`, then `exit "$status"`), so summary and artifact hold the whole list.

## Files changed

- `scripts/api_parity.py`: resolver, `exported_names`/`exported_name_at`/`export_ranks`, `is_prerelease`, `--is-prerelease`, untruncated report on stdout in report-only mode; `import itertools`.
- `scripts/tests/test_api_parity.py`: 15 new tests (`TransitiveReexports`, `VersionIsPrerelease`, `ReleaseReportIsComplete`).
- `.github/workflows/release-check.yml`: milestone step only. Contexts still reach `run` only through `env:` (`VERSION`, `MILESTONE`); no new `${{ }}` in any `run` body; no secret, no publication.
- `docs/RELEASING.md`: step 9 describes the new rule and the whole list.
- `docs/API_PARITY.md`, `docs/EXTENSIONS.md`: **not** changed. The generated documents are byte-identical on the tree as on `main`.

## Commands run

- `python3 -m unittest discover -s scripts/tests`: `Ran 100 tests ... OK` (85 before, 15 added).
- `python3 scripts/api_parity.py --check` and `--check --extensions`: both "up to date". `--refresh --hexx sources/hexx` (hexx 0.25.0 checkout) rewrote nothing (`git status` showed only my edits), so the hexx inventory is unchanged.
- `python3 scripts/api_parity.py --is-prerelease 0.1.0+build-1` → `false`; `1.0.0-rc.1+build-1` → `true`.
- `python3 scripts/api_parity.py --check-release L-M1 --report-only | wc -l` → 67 lines on stdout (heading + all 66 items), exit 0 (AC-2).
- `scripts/check.sh`: `all checks passed`.
- `gh pr checks 26 --watch`: all checks pass.

Not run: the workflow itself (it is `workflow_dispatch` on `main` only), so the new step was not exercised on a runner; its shell logic was only read, not run.

## Cost

—

## Deviations

- The brief's AC-1 names the auditor's scenarios; all three are unit tests (`test_chain_of_two_reexports_with_an_alias`, `test_two_root_exports_of_one_item_keep_both_names`, `VersionIsPrerelease`), plus a chain of three, globs in a chain, a glob cycle, a named cycle, a module re-export, and the versions `1.0.0-rc.1+build-1`, `1.0.0+a-b`, `1.0.0-`.
- Report-only output moved from stderr to stdout (an informational report is not an error). The enforced failure stays on stderr; the workflow captures both anyway.
- The re-export of a module now *raises* where it used to be silently ignored. It does not occur in the pinned hexx 0.25.0 (inventory unchanged) nor in the current Cairo tree.

## Escalations

None.

## Open questions

Noticed, not fixed (out of scope):

- `USE_STATEMENT_RE` only recognises `pub` and `pub(crate)`. A `pub(super) use` / `pub(in path) use` line does not match at all and is silently skipped.
- A `use` inside an inline `mod x { ... }` block or a function body is seen only if it begins a line, and is attributed to the enclosing file's module path, not the inline module's.
- Impl methods and constants of a type exported under an alias are still scoped by the declared name (`Hex.method`), not the alias, as before; only the declaration items (struct/enum/trait/fields/variants) follow every exported name.
- A `--is-prerelease` on an invalid version (`1.0.0-`) just applies the rule; semver validity is checked by an earlier workflow step.

## Follow-up 1

**Merge.** `origin/main` (take-over, PR 28) merged into the branch with `git merge`: no conflict, none of my files touched by it.

**Generated documents.** With my version of the parity tool, on the tree that now holds the engine, `python3 scripts/api_parity.py --check` and `--check --extensions` both say "up to date": `docs/API_PARITY.md` and `docs/EXTENSIONS.md` are byte-identical to `main`'s. So there is **no difference** to list (no item appears, disappears or is renamed). The engine's only re-exports are `crates/hexx/src/lib.cairo:10-11` (`pub use board::direction::Direction;`, `pub use board::map::{HexMap, HexMapTrait};`), plain and unaliased; a `--refresh` against `sources/hexx` still rewrites nothing. `scripts/check.sh`: `all checks passed`.

**The four defects of "Open questions".**

1. `pub(super) use` / `pub(in path) use` silently skipped: **fixed** (`USE_STATEMENT_RE`). Any `pub(...)` visibility now matches. Its names count as `used_names`, and only the bare `pub` bridges (a restricted re-export is not visible from outside). Test `test_restricted_visibility_use_is_recognised_and_never_bridges`.
2. `use` inside an inline `mod`, or not at the start of a line. Two parts. *Attribution to the wrong module*: my first report was **wrong** on this. `split_own_and_children` makes every inline module its own node and blanks its span out of the parent, so a `use` is attributed to the inline module (test `test_use_in_an_inline_module_is_attributed_to_that_module` confirms it; no code change). *Not at the start of a line*: `mod a { pub use b::C; }` on one line worked, but `pub fn f() {} pub use x::Y;` was silently skipped. **Fixed**: the pattern is no longer anchored to a line start (`(?<![\w:])`). Test `test_use_not_at_the_start_of_a_line_is_seen`.
3. Members of a type exported under an alias are scoped by the declared name: **made to raise**, not supported. New `reject_scoped_aliases`, called from `parse_hexx` and `build_cairo_tree`: a type or trait exported under a name other than its declared one, while it has an impl / a trait of members, raises with file:line. An alias of a member-less type stays supported. Not used by hexx 0.25.0 nor the crate. Tests for the Cairo and Rust forms. This is a heuristic (regex over impl headers), not a proof; it errs towards raising.
4. `--is-prerelease` on an invalid version: **changed** to raise (`not valid semver`, same syntax as the workflow's own check) instead of answering `true` for `1.0.0-`; the pure function `is_prerelease` is unchanged. This cannot affect the workflow, which validates semver in an earlier step. Test `test_cli_refuses_an_invalid_version`.

Tests: `Ran 161 tests ... OK` (the merge brought new ones of main; six more of mine).

**Not run / limits:** a `use` inside a string or comment is masked before matching (unchanged). Still unhandled and unchanged: a `pub use` of a name defined by a macro, and `use` groups with `self` in a private module (only raise when public).
