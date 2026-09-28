# hexx

The Cairo port of [`hexx`](https://github.com/ManevilleF/hexx) 0.25.0, extended with a bitmap
board engine for Starknet (the engine of
[`origami_hexmap`](https://github.com/dojoengine/origami/tree/main/crates/hexmap) 1.8.0, taken
over here). Part of the [`bal7hazar/hexx-cairo`](https://github.com/bal7hazar/hexx-cairo)
workspace: see the repository root for the plan, the decisions and the status.

## Status

**Not published.** This package is a placeholder: milestone L-M1 (task LIB-05) is the first task
that ports a mirror item or adds an extension. It exists now, with one trivial public item and
one test, so that every tool of the workspace — format, lint, build, test, the API parity table,
the gas budget rule, the class-size check, the reference generator, the publication pipeline —
has something to run on (task LIB-04).

No `starknet` dependency, no Dojo dependency: this package is pure Cairo. `snforge_std` is a
dev-dependency only.

## Checks

From the repository root:

```sh
scripts/check.sh                          # everything CI checks, locally, package-scoped
scarb build -p hexx
snforge test -p hexx
python3 scripts/api_parity.py --check     # docs/API_PARITY.md up to date
python3 scripts/deviations.py --check     # docs/DEVIATIONS.md up to date
python3 scripts/bench.py check            # every test has #[available_gas], budgets within 5 %
```

## License

MIT (workspace root [`LICENSE`](../../LICENSE)).
