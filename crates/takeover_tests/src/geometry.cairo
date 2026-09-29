//! `helpers::geometry` of 1.8.0 against `hexx::board::geometry`: `Geometry::{to_axial,
//! distance}`.

use hexx::board::geometry::Geometry as H;
use origami_hexmap::helpers::geometry::Geometry as O;
use crate::common::{query_pairs, query_positions};

/// Every position of a `7x7`, 512 seeded positions of a `17x14` and of a `15x16`.
#[test]
#[available_gas(l2_gas: 26867535)]
fn test_geometry_to_axial() {
    for (width, _height, position) in query_positions() {
        assert(O::to_axial(width, position) == H::to_axial(width, position), 'to_axial');
    }
}

/// Every pair of a `7x7`, 512 seeded pairs of a `17x14` and of a `15x16`.
#[test]
#[available_gas(l2_gas: 112318181)]
fn test_geometry_distance() {
    for (width, _height, from, to) in query_pairs() {
        assert(O::distance(width, from, to) == H::distance(width, from, to), 'distance');
    }
}
