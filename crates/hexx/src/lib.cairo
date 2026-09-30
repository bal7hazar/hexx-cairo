//! `hexx`: the port of [`hexx`](https://github.com/ManevilleF/hexx) 0.25.0 to Cairo, extended
//! with a bitmap board engine for Starknet (plan: `docs/research/LIB-03-porting-plan.md` of
//! `bal7hazar/hexx-cairo`).
//!
//! The board engine (`board`, `finders`, `generators`) is taken over from `origami_hexmap`
//! 1.8.0 (`dojoengine/origami`, commit `04ab30c`, MIT), see `LICENSE-origami`. The mirror of
//! `hexx` itself lands with the tasks of milestone L-M1 and L-M2: `Hex`, `EdgeDirection`, the
//! offset conversions and `HexOrientation` are here.

pub mod board;
pub use board::direction::{Arc, Direction};
pub use board::map::{HexMap, HexMapTrait};

pub mod conversions;
pub use conversions::{HexConversionsTrait, OffsetHexMode};

pub mod direction;
pub use direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};

pub mod finders;
pub mod generators;

pub mod hex;
pub use hex::{Hex, HexTrait};

pub mod orientation;
pub use orientation::HexOrientation;

#[cfg(test)]
pub mod tests;
