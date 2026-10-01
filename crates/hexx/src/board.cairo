//! The board engine taken over from `origami_hexmap` 1.8.0 (plan §5): boards in one `felt252`,
//! generation, floods. One module per source file of the engine, unchanged.

pub mod assembly;
pub mod asserter;
pub mod bits;
pub mod cut;
pub mod direction;
pub mod geometry;
pub mod layout;
pub mod line;
pub mod map;

#[cfg(test)]
pub mod printer;
pub mod rng;
pub mod seams;
pub mod tables;
