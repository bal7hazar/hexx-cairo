# hexx-cairo

The hexagonal map library of **Grim World**, an on-chain game written in Cairo: track **LIB**
of the game's plan. Its subject is the Rust crate [`hexx`](https://github.com/ManevilleF/hexx)
and the Cairo library [`origami_hexmap`](https://github.com/dojoengine/origami/tree/main/crates/hexmap)
that the game consumes today (version 1.8.0).

## Status

**Planning.** No code yet. The owner decided on 2026-09-28
([L-G1](docs/decisions/L-G1-hexx-port.md)) that this repository is the library: a port of
`hexx` to Cairo at feature parity wherever that makes sense on-chain, extended with what Cairo
and the network require (boards stored as bitmaps in one felt, generation, floods, assembly).
The engine of `origami_hexmap` is taken over here, and `origami_hexmap` is decommissioned once
the port is complete. Task LIB-03 writes the porting plan; the owner accepts it at gate L-G2.
The live state is in [STATUS.md](STATUS.md), the order of work in [PLAN.md](PLAN.md).

## Where things are

| Path | What |
|---|---|
| [PLAN.md](PLAN.md) | Track LIB: tasks, gates, milestone L-M1. Owned here |
| [STATUS.md](STATUS.md) | Live state, dated, rewritten at every check-in |
| [docs/briefs/](docs/briefs/COMMON.md) | One committed brief per task; `COMMON.md` holds the shared rules |
| [docs/research/](docs/research/README.md) | Research reports |
| [docs/decisions/](docs/decisions/README.md) | Decisions of the owner; `PENDING-*.md` for the open ones |
| `docs/reports/` | Archived `REPORT.md` of merged tasks |
| `docs/audits/` | Audit reports, titled with the model that wrote them |
| `scripts/` | The launcher of sub-agents (`agent.sh`), its permission profiles and the build lock, copied from the game's repository |

## Relation to the game

| | |
|---|---|
| Game repository | [`bal7hazar/grimworld`](https://github.com/bal7hazar/grimworld): `PLAN.md` § *Track LIB*, `docs/needs/hexmap.md` (needs N-1 to N-8), `OPERATIONS.md`, `docs/CAIRO.md` |
| Direction of needs | The game writes what it needs; this repository answers by releases and a changelog |
| Consumption | By **published version** on [scarbs.xyz](https://scarbs.xyz), never by git revision |
| Rules | The game's `OPERATIONS.md` and `docs/CAIRO.md` bind every task here |

## License

[MIT](LICENSE).
