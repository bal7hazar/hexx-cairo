//! Equality tests of the `board` extension against the published `origami_hexmap` 1.8.0 it takes
//! over (plan, §5.4, layer 2). Depends on `origami_hexmap` from the registry and on `hexx` by
//! path: never published alongside `hexx`, which must not carry this dependency (`Scarb.toml`,
//! `publish = false`).
//!
//! One module per module of the engine; each test calls the function of `origami_hexmap` and the
//! function of `hexx` on the same fixed inputs and asserts that the whole results are equal, or
//! that both panic with the same message (`#[should_panic]` pairs). `gas` compares the cost of the
//! 20 functions of the facade through both libraries (reported, not enforced). Everything is
//! test-only.
//!
//! A test that loops over many inputs states them in its doc comment; each stays below the
//! default step limit of snforge (10,000,000 steps), so the inputs of a heavy function are split
//! over several tests by seed or by board.

#[cfg(test)]
pub mod asserter;
#[cfg(test)]
pub mod bfs;
#[cfg(test)]
pub mod bits;
#[cfg(test)]
pub mod caver;
#[cfg(test)]
pub mod common;
#[cfg(test)]
pub mod dial;
#[cfg(test)]
pub mod digger;
#[cfg(test)]
pub mod direction;
#[cfg(test)]
pub mod fixtures;
#[cfg(test)]
pub mod gas;
#[cfg(test)]
pub mod geometry;
#[cfg(test)]
pub mod layout;
#[cfg(test)]
pub mod map;
#[cfg(test)]
pub mod mazer;
#[cfg(test)]
pub mod rng;
#[cfg(test)]
pub mod spreader;
#[cfg(test)]
pub mod walker;
