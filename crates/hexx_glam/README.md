# hexx_glam

The `glam` interop of [`hexx`](https://github.com/ManevilleF/hexx) 0.25.0 for Cairo: conversions
between `hexx::Hex` and the `IVec2` / `IVec3` of the Cairo
[`glam`](https://scarbs.xyz/packages/glam). Companion package of `hexx` in the
[`bal7hazar/hexx-cairo`](https://github.com/bal7hazar/hexx-cairo) workspace.

```toml
[dependencies]
hexx = "0.3.0"
hexx_glam = "0.3.0"
```

Requires Cairo >= 2.20.0 (Scarb 2.20.1).

## What it converts

| `hexx` 0.25.0 | `hexx_glam` |
|---|---|
| `Hex::as_ivec2` | `HexGlamTrait::as_ivec2`: `IVec2 { x, y }` |
| `Hex::as_ivec3` | `HexGlamTrait::as_ivec3`: `IVec3 { x, y, z }`, `z` being `HexTrait::z` (panics where `z` does, at the `i32` extremes) |
| `From<Hex> for IVec2` | `HexIntoIVec2`, an `Into<Hex, IVec2>` |
| `From<Hex> for IVec3` | `HexIntoIVec3`, an `Into<Hex, IVec3>` |
| `From<IVec2> for Hex` | `IVec2IntoHex`, an `Into<IVec2, Hex>` |

`hexx` has no `From<IVec3> for Hex`, and none is added.

## Importing the impls

Cairo's conversion trait is `Into`. The three impls are defined in this package, not in the
module of `Into`, `Hex` or `IVec2`, so a consumer must bring them into scope for `.into()` to find
them. Measured (Scarb 2.20.1): without the import, `let v: IVec2 = hex.into();` fails with
`E2311: Trait has no implementation in context: core::traits::Into::<hexx::hex::Hex,
glam_core::ivec2::IVec2>`.

```cairo
use glam::ivec2::IVec2;
use hexx::hex::{Hex, HexTrait};
use hexx_glam::{HexGlamTrait, HexIntoIVec2, IVec2IntoHex};

let hex = HexTrait::new(3, -5);
let v: IVec2 = hex.into();
let back: Hex = v.into();
let same = hex.as_ivec2();
```

`use hexx_glam::*;` works as well. Annotate the target type: `Into` of a `Hex` has other
implementations in `core`.

## Licence

Ported to Cairo from bevy hexx 0.25.0 (Apache-2.0); the code is a rewrite, not a copy. The
notice of `hexx` is [`LICENSE-hexx`](LICENSE-hexx); this package is MIT ([`LICENSE`](LICENSE)).
