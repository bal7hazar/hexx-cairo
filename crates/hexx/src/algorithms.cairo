//! `algorithms`: the counterparts of `hexx::algorithms` (`src/algorithms/mod.rs`) on a `HexMap`:
//! `field_of_movement` and `a_star` (M3-T1), `range_fov` and `directional_fov` (M3-T2).
//!
//! Each forwards to the one implementation of the board (`HexMapTrait`, `Dial`, plan §2.4): the
//! counterpart takes the position as a tile index of the map and maps `hexx`'s closures to the
//! board's cost classes and walls.

// The free function `field_of_movement` is
// `hexx::algorithms::field_of_movement::field_of_movement`:
// this module cannot re-export it, a module and a function cannot share the name
// `field_of_movement` here (E2118, as `hex`, plan §2.4); see the deviation of `field_of_movement`.
pub mod field_of_movement;
pub mod fov;
pub mod pathfinding;

pub use pathfinding::a_star;
