//! The directions of `hexx` (`src/direction/`): `EdgeDirection`, `VertexDirection`,
//! `DirectionWay` and the operators of the two direction types. The board's own `Direction`
//! (north up, `board::direction`) is a different type with the same indices (plan §3.2).

pub mod edge_direction;
pub mod impls;
pub mod vertex_direction;
pub mod way;
