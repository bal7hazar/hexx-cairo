//! `hexx`: the port of [`hexx`](https://github.com/ManevilleF/hexx) 0.25.0 to Cairo, extended
//! with a bitmap board engine for Starknet (plan: `docs/research/LIB-03-porting-plan.md` of
//! `bal7hazar/hexx-cairo`).
//!
//! The board engine (`board`, `finders`, `generators`) is taken over from `origami_hexmap`
//! 1.8.0 (`dojoengine/origami`, commit `04ab30c`, MIT), see `LICENSE-origami`. The mirror of
//! `hexx` itself lands with the later tasks of milestone L-M1 and L-M2.

pub mod board;
pub use board::direction::Direction;
pub use board::map::{HexMap, HexMapTrait};

pub mod finders;
pub mod generators;

#[cfg(test)]
pub mod tests;
