//! `hexx`: the port of [`hexx`](https://github.com/ManevilleF/hexx) 0.25.0 to Cairo, extended
//! with a bitmap board engine for Starknet (plan: `docs/research/LIB-03-porting-plan.md` of
//! `bal7hazar/hexx-cairo`).
//!
//! The board engine (`board`, `finders`, `generators`) is taken over from `origami_hexmap`
//! 1.8.0 (`dojoengine/origami`, commit `04ab30c`, MIT), see `LICENSE-origami`; the notice of
//! `hexx` 0.25.0 (Apache-2.0) is `LICENSE-hexx`. Both are shipped in this package, next to
//! `Scarb.toml`. The mirror of `hexx`
//! itself is published up to milestone L-M2 (0.2.0): `Hex`, the directions, the conversions,
//! `HexBounds`, `HexOrientation` and the shapes are here. The rest of `hexx` 0.25.0 (L-M3:
//! the `hexx_glam` interop and the algorithms) is not ported yet.

pub mod board;
pub use board::direction::{Arc, Direction};
pub use board::map::{HexMap, HexMapTrait};

pub mod bounds;
pub use bounds::{HexBounds, HexBoundsTrait};

pub mod conversions;
pub use conversions::{DoubledHexMode, HexConversionsTrait, OffsetHexMode};

pub mod direction;
pub use direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
pub use direction::vertex_direction::{VertexDirection, VertexDirectionTrait};
pub use direction::way::{DirectionWay, DirectionWayTrait};

pub mod finders;

pub mod generators;

// The free function `hex` is `hexx::hex::hex`: the root cannot re-export it, a module and a
// function cannot share the name `hex` there (E2118, plan §2.4); see the deviation of `hex`.
pub mod hex;
pub use hex::grid::edge::{GridEdge, GridEdgeTrait};
pub use hex::grid::vertex::{GridVertex, GridVertexTrait};
pub use hex::{Hex, HexSpanExt, HexTrait};

pub mod orientation;
pub use orientation::HexOrientation;

pub mod shapes;

#[cfg(test)]
pub mod tests;
