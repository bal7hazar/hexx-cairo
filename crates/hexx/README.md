# hexx

The Cairo port of [`hexx`](https://github.com/ManevilleF/hexx) 0.25.0, extended with a bitmap
board engine for Starknet (the engine of
[`origami_hexmap`](https://github.com/dojoengine/origami/tree/main/crates/hexmap) 1.8.0, taken
over here). Part of the [`bal7hazar/hexx-cairo`](https://github.com/bal7hazar/hexx-cairo)
workspace: see the repository root for the plan, the decisions and the status.

## Status

**Not published.** This package holds the board engine of `origami_hexmap` 1.8.0, moved
unchanged into the module tree of the plan (`board`, `finders`, `generators`; task LIB-05
M1-T1a); the mirror of `hexx` itself and the extensions land with the next tasks of L-M1.

The board engine is taken over from `origami_hexmap` 1.8.0 (`dojoengine/origami`, commit
`04ab30c`, MIT): its notice is [`LICENSE-origami`](../../LICENSE-origami). The record of its gas
measurements is [`GAS-origami-1.8.0.md`](GAS-origami-1.8.0.md).

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
python3 scripts/bench.py check            # every test has #[available_gas], budget within 5 % of its
                                          # measurement (a fuzz test: its maximum), counts reconciled;
                                          # --package hexx measures one package
```

The gas rule has no exemption: every test of the package, the ones taken over from
`origami_hexmap` 1.8.0 included, carries `#[available_gas(l2_gas: N)]` with
`N = ceil(1.05 * measured)`. (The list of exemptions of the take-over, `gas/takeover-baseline.txt`,
was emptied and removed by task M1-T1c.)

## License

MIT (workspace root [`LICENSE`](../../LICENSE)).
