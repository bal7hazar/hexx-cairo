# [Sonnet 5.5] LIB-04c — CI partitions

## Summary

The gas gate and the tests of `hexx` now run in partitions, and every job of the pull request's last run is under 6 minutes. The gate still measures every test exactly once, and a new job proves it. Pull request: https://github.com/bal7hazar/hexx-cairo/pull/58 (last run `36802592870`, all checks green). I am Sonnet 5.5, as the brief names.

- `bench.py check|run|repeat --partition I/T` passes `--partition` to snforge. `check` enforces the rule and the snapshot on the tests of that share only (their rows only). Each partition keeps `partition-<scope>-<I>of<T>.json` (the names it measured) in its artefact.
- `bench.py complete --package P --scope S --total T --reports DIR` is the completeness check (`completeness()` is pure and unit-tested). It fails when:
  - a declared test was measured in no partition or in two;
  - a test was measured that the sources do not declare;
  - a partition report is missing, repeated, or of another package, scope or total;
  - a snapshot row of the scope (or of a test that no longer exists) was measured by no partition.
- CI:
  - tests of `hexx`: 5 partitions;
  - gas `hexx` regular: 4 partitions;
  - gas `hexx` ignored: 2 partitions (not in the brief's scope: its unpartitioned job took 6 m 1 s);
  - new jobs `Gas completeness hexx regular` and `Gas completeness hexx ignored`, which download the artefacts of the run with `gh run download` and call `bench.py complete`; both are in `all-checks`.
- `snapshot` and `scripts/check.sh` are unchanged: unpartitioned runs behave as before (`--partition` is refused with `snapshot`).

## Files changed

- `scripts/bench.py` — `--partition`, `--total`, `--reports`, the `complete` command, partition reports, partition-aware `collect`, `reconcile` and `snapshot_differences`, `repeat --partition`.
- `scripts/tests/test_bench_partitions.py` — new: 20 unit tests (partition argument, the share, its snapshot rows only, completeness: test missing, test twice, stale row, missing or repeated report, undeclared test, reports read from disk).
- `.github/workflows/ci.yml` — partitions, the completeness jobs, artefact names with `tag`.

## Commands run

- `python3 -m unittest discover -s scripts/tests`: 200 tests, OK (9 skipped, as before).
- Locally, `snforge test -p hexx --detailed-resources --partition 1/3`: `Collected 375`, `341 passed, 34 ignored`, `included 375 out of total 1124`. So `Collected` is the share's count, ran plus ignored, which `reconcile` uses under a partition. snforge partitions all the tests of a package before the filter and before `--ignored` (checked on `takeover_tests`: 315 + 315 for 1/2 and 2/2, with and without `--ignored`). The partitions of a package are therefore the same whatever the scope.
- `scripts/check.sh` was not run locally (full gate; CI runs it). The unpartitioned `bench.py check` path was exercised only by the unit tests and by CI's `Gas takeover_tests` / `Gas consumer` jobs.

CI times (job, before → after):

| Job | Before (`main` `295ff3d`, run `36792754888`) | Run 1 (3/3/2 partitions) | Final run `36802592870` |
|---|---|---|---|
| Gas hexx (regular) | 9 m 4 s | 1/3 4 m 51 s, 2/3 5 m 44 s, 3/3 5 m 51 s | 1/4 5 m 22 s, 2/4 5 m 27 s, 3/4 5 m 12 s, 4/4 5 m 19 s |
| Gas hexx (ignored tests) | not given in the brief | 6 m 1 s | 1/2 3 m 56 s, 2/2 4 m 44 s |
| Build and test hexx | 1/2 6 m 49 s (2/2 not given) | 1/3 6 m 14 s, 2/3 5 m 53 s, 3/3 3 m 57 s | 1/5 5 m 38 s, 2/5 5 m 23 s, 3/5 4 m 44 s, 4/5 4 m 26 s, 5/5 5 m 43 s |
| Gas completeness hexx regular / ignored | — | 10 s (one job) | 7 s / 7 s |
| Gas takeover_tests | not retrieved | 2 m 37 s | 2 m 18 s |
| Build and test takeover_tests | not retrieved | 3 m 11 s | 3 m 13 s |
| Gas consumer / Build and test consumer | not retrieved | 27 s / 21 s | 20 s / 19 s |
| fmt, links, scripts, takeover, package, golden | not retrieved | all under 1 min | all under 1 min (6 s to 18 s) |

Four tests partitions (run 2) gave 5 m 34 s to 6 m 0 s, so I used five.

## Cost

—

## Deviations

- Three partitions did not reach 6 minutes, as the brief foresaw; the brief allows four and says to give the reason:
  - snforge partitions by hash, so the shares are uneven (3 m 57 s to 6 m 14 s for the tests at 3, 5 m 34 s to 6 m 0 s at 4), and the fixed cost of setup and build is about 2 to 3 minutes per job;
  - tests: 5 partitions (6 m 0 s was too close to the limit);
  - gas regular: 4 partitions (5 m 51 s at 3 had no room for M1-T6);
  - gas ignored: 2 partitions, beyond the brief's list, because AC-1 covers every job and it took 6 m 1 s.
- `gh run download` instead of `actions/download-artifact`: I could not resolve a pinned commit SHA for that action from this sandbox (no network lookup was allowed), and the repository pins every action by SHA. The job has `actions: read`.
- `repeat` (the double run of the Digger tests) runs inside each partition with `--partition`, so each Digger test is run twice, once over the partitions. A share with no Digger test does not fail (a whole package with none still does). Nothing checks that every Digger test was repeated in some share, because snforge assigns them. A partition mismatch, however, cannot hide a test from the budget rule: `complete` covers all of them.

## Escalations

None.

## Open questions

- Should `complete` also be run for `takeover_tests` and `consumer`? They are one job each, so I did not.
- The VPS build differs from CI (D-154), so I did not touch any snapshot; none moved in CI.
