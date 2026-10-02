# hexx

The Cairo port of [`hexx`](https://github.com/ManevilleF/hexx) 0.25.0, extended with a bitmap
board engine for Starknet (the engine of
[`origami_hexmap`](https://github.com/dojoengine/origami/tree/main/crates/hexmap) 1.8.0, taken
over here). Part of the [`bal7hazar/hexx-cairo`](https://github.com/bal7hazar/hexx-cairo)
workspace: see the repository root for the plan, the decisions and the status.

## Status

Published as release candidates (`0.1.0-rc.N`); the stable `0.1.0` is not out yet. The package holds
the mirror of `hexx` 0.25.0 (the items listed in
[`docs/API_PARITY.md`](https://github.com/bal7hazar/hexx-cairo/blob/main/docs/API_PARITY.md)), the
extensions of milestone L-M1 (`docs/EXTENSIONS.md`) and the board engine of `origami_hexmap` 1.8.0
(`board`, `finders`, `generators`).

```toml
[dependencies]
hexx = "0.1.0-rc.2"
```

Requires Cairo >= 2.20.0 (Scarb 2.20.1).

Ported to Cairo from bevy hexx 0.25.0 (Apache-2.0); the code is a rewrite, not a copy.

Two origins, each with its notice shipped in this package:

- the port of [`hexx`](https://github.com/ManevilleF/hexx) 0.25.0 (Apache-2.0; its `Cargo.toml`
  names Felix de Maneville as author): [`LICENSE-hexx`](LICENSE-hexx), a copy of the `LICENSE` of
  the crate (it has no NOTICE file);
- the board engine taken over from `origami_hexmap` 1.8.0 (`dojoengine/origami`, commit
  `04ab30c`, MIT, Copyright (c) 2023 Dojo): [`LICENSE-origami`](LICENSE-origami).

The record of the gas measurements of the engine is
[`GAS-origami-1.8.0.md`](https://github.com/bal7hazar/hexx-cairo/blob/main/crates/hexx/GAS-origami-1.8.0.md).

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

MIT (workspace root [`LICENSE`](https://github.com/bal7hazar/hexx-cairo/blob/main/LICENSE)); the
notices of the two origins are [`LICENSE-hexx`](LICENSE-hexx) (Apache-2.0) and
[`LICENSE-origami`](LICENSE-origami) (MIT).
