//! The board engine taken over from `origami_hexmap` 1.8.0 (plan §5): boards in one `felt252`,
//! generation, floods. One module per source file of the engine, unchanged.

pub mod asserter;
pub mod bits;
pub mod direction;
pub mod geometry;
pub mod layout;
pub mod map;

#[cfg(test)]
pub mod printer;
pub mod rng;
