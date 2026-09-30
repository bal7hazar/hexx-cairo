//! Tests of `EdgeDirection` (`direction/edge_direction.cairo`) against plain oracles and the
//! table of plan §3.2. The golden vectors from the crate are in
//! `crates/hexx/tests/golden_direction.cairo`.

use hexx::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
use hexx::hex::{Hex, HexTrait};

/// The five names of each index (plan §3.2, `src/direction/edge_direction.rs:79-190`): written
/// here by hand from the table of the plan, independent of the generated vectors.
#[test]
#[available_gas(l2_gas: 14406)]
fn test_edge_direction_compass_aliases() {
    // Index 0.
    assert(EdgeDirectionTrait::X.index() == 0, 'X');
    assert(EdgeDirectionTrait::POINTY_EAST.index() == 0, 'POINTY_EAST');
    assert(EdgeDirectionTrait::POINTY_RIGHT.index() == 0, 'POINTY_RIGHT');
    assert(EdgeDirectionTrait::FLAT_SOUTH_EAST.index() == 0, 'FLAT_SOUTH_EAST');
    assert(EdgeDirectionTrait::FLAT_BOTTOM_RIGHT.index() == 0, 'FLAT_BOTTOM_RIGHT');
    // Index 1.
    assert(EdgeDirectionTrait::Y.index() == 1, 'Y');
    assert(EdgeDirectionTrait::POINTY_SOUTH_EAST.index() == 1, 'POINTY_SOUTH_EAST');
    assert(EdgeDirectionTrait::POINTY_BOTTOM_RIGHT.index() == 1, 'POINTY_BOTTOM_RIGHT');
    assert(EdgeDirectionTrait::FLAT_SOUTH.index() == 1, 'FLAT_SOUTH');
    assert(EdgeDirectionTrait::FLAT_BOTTOM.index() == 1, 'FLAT_BOTTOM');
    // Index 2.
    assert(EdgeDirectionTrait::NEG_X_Y.index() == 2, 'NEG_X_Y');
    assert(EdgeDirectionTrait::POINTY_SOUTH_WEST.index() == 2, 'POINTY_SOUTH_WEST');
    assert(EdgeDirectionTrait::POINTY_BOTTOM_LEFT.index() == 2, 'POINTY_BOTTOM_LEFT');
    assert(EdgeDirectionTrait::FLAT_SOUTH_WEST.index() == 2, 'FLAT_SOUTH_WEST');
    assert(EdgeDirectionTrait::FLAT_BOTTOM_LEFT.index() == 2, 'FLAT_BOTTOM_LEFT');
    // Index 3.
    assert(EdgeDirectionTrait::NEG_X.index() == 3, 'NEG_X');
    assert(EdgeDirectionTrait::POINTY_WEST.index() == 3, 'POINTY_WEST');
    assert(EdgeDirectionTrait::POINTY_LEFT.index() == 3, 'POINTY_LEFT');
    assert(EdgeDirectionTrait::FLAT_NORTH_WEST.index() == 3, 'FLAT_NORTH_WEST');
    assert(EdgeDirectionTrait::FLAT_TOP_LEFT.index() == 3, 'FLAT_TOP_LEFT');
    // Index 4.
    assert(EdgeDirectionTrait::NEG_Y.index() == 4, 'NEG_Y');
    assert(EdgeDirectionTrait::POINTY_NORTH_WEST.index() == 4, 'POINTY_NORTH_WEST');
    assert(EdgeDirectionTrait::POINTY_TOP_LEFT.index() == 4, 'POINTY_TOP_LEFT');
    assert(EdgeDirectionTrait::FLAT_NORTH.index() == 4, 'FLAT_NORTH');
    assert(EdgeDirectionTrait::FLAT_TOP.index() == 4, 'FLAT_TOP');
    // Index 5.
    assert(EdgeDirectionTrait::X_NEG_Y.index() == 5, 'X_NEG_Y');
    assert(EdgeDirectionTrait::POINTY_NORTH_EAST.index() == 5, 'POINTY_NORTH_EAST');
    assert(EdgeDirectionTrait::POINTY_TOP_RIGHT.index() == 5, 'POINTY_TOP_RIGHT');
    assert(EdgeDirectionTrait::FLAT_NORTH_EAST.index() == 5, 'FLAT_NORTH_EAST');
    assert(EdgeDirectionTrait::FLAT_TOP_RIGHT.index() == 5, 'FLAT_TOP_RIGHT');
}

#[test]
#[available_gas(l2_gas: 47544)]
fn test_edge_direction_all_directions_and_iter() {
    let all = EdgeDirectionTrait::ALL_DIRECTIONS;
    let all = all.span();
    let iter = EdgeDirectionTrait::iter();
    assert(all.len() == 6 && iter.len() == 6, 'six');
    let mut i: u8 = 0;
    while i < 6 {
        assert((*all.at(i.into())).index() == i, 'ALL_DIRECTIONS order');
        assert(*iter.at(i.into()) == *all.at(i.into()), 'iter is ALL_DIRECTIONS');
        i += 1;
    }
    let default: EdgeDirection = Default::default();
    assert(default == EdgeDirectionTrait::X, 'default is X');
}

#[test]
#[available_gas(l2_gas: 116319)]
fn test_edge_direction_into_hex_reads_the_neighbours() {
    let neighbors = HexTrait::NEIGHBORS_COORDS;
    let neighbors = neighbors.span();
    let mut i: u8 = 0;
    while i < 6 {
        let d = *EdgeDirectionTrait::iter().at(i.into());
        assert(d.into_hex() == *neighbors.at(i.into()), 'into_hex');
        let h: Hex = d.into();
        assert(h == d.into_hex(), 'Into');
        // Opposite directions cancel.
        let opposite = d.const_neg().into_hex();
        assert(h.x + opposite.x == 0 && h.y + opposite.y == 0, 'const_neg cancels');
        i += 1;
    }
    assert(EdgeDirectionTrait::X.into_hex() == HexTrait::new(1, 0), 'X');
    assert(EdgeDirectionTrait::Y.into_hex() == HexTrait::new(0, 1), 'Y');
    assert(EdgeDirectionTrait::NEG_X_Y.into_hex() == HexTrait::new(-1, 1), 'NEG_X_Y');
    assert(EdgeDirectionTrait::NEG_X.into_hex() == HexTrait::new(-1, 0), 'NEG_X');
    assert(EdgeDirectionTrait::NEG_Y.into_hex() == HexTrait::new(0, -1), 'NEG_Y');
    assert(EdgeDirectionTrait::X_NEG_Y.into_hex() == HexTrait::new(1, -1), 'X_NEG_Y');
}

/// The oracle of the rotations: repeat the one-step rotation `offset` times.
#[test]
#[available_gas(l2_gas: 2328785)]
fn test_edge_direction_rotations_are_repeated_steps() {
    let mut i: u8 = 0;
    while i < 6 {
        let d = *EdgeDirectionTrait::iter().at(i.into());
        let mut cw = d;
        let mut ccw = d;
        let mut offset: u8 = 0;
        while offset < 30 {
            assert(d.rotate_cw(offset) == cw, 'rotate_cw');
            assert(d.rotate_ccw(offset) == ccw, 'rotate_ccw');
            cw = cw.clockwise();
            ccw = ccw.counter_clockwise();
            offset += 1;
        }
        // The two senses undo each other, a full turn is the identity, three steps negate.
        assert(d.clockwise().counter_clockwise() == d, 'cw then ccw');
        assert(d.counter_clockwise().clockwise() == d, 'ccw then cw');
        assert(d.rotate_cw(6) == d && d.rotate_ccw(252) == d, 'full turns');
        assert(d.rotate_cw(3) == d.const_neg(), 'three steps are the opposite');
        assert(d.const_neg().const_neg() == d, 'const_neg twice');
        i += 1;
    }
    // The largest offset of `u8`: 255 = 42 * 6 + 3.
    assert(EdgeDirectionTrait::X.rotate_cw(255) == EdgeDirectionTrait::NEG_X, 'X + 255');
    assert(EdgeDirectionTrait::X.rotate_ccw(255) == EdgeDirectionTrait::NEG_X, 'X - 255');
    assert(EdgeDirectionTrait::X_NEG_Y.rotate_cw(255) == EdgeDirectionTrait::NEG_X_Y, '5 + 255');
    assert(EdgeDirectionTrait::X_NEG_Y.rotate_ccw(255) == EdgeDirectionTrait::NEG_X_Y, '5 - 255');
}

// `Serde`: a value read from calldata is always one of the six directions.

#[test]
#[available_gas(l2_gas: 53739)]
fn test_edge_direction_serde_round_trip() {
    let mut i: u8 = 0;
    while i < 6 {
        let d = *EdgeDirectionTrait::iter().at(i.into());
        let mut output: Array<felt252> = array![];
        d.serialize(ref output);
        assert(output.len() == 1 && *output.at(0) == i.into(), 'one felt, the index');
        let mut input = output.span();
        let back: EdgeDirection = Serde::deserialize(ref input).unwrap();
        assert(back == d, 'round trip');
        assert(input.len() == 0, 'consumed');
        i += 1;
    }
}

#[test]
#[available_gas(l2_gas: 1085522)]
fn test_edge_direction_serde_refuses_an_index_above_five() {
    // Every index of a `u8` above 5, then the felts that are no `u8` at all.
    let mut refused: u16 = 6;
    while refused <= 255 {
        let mut input = array![refused.into()].span();
        let read: Option<EdgeDirection> = Serde::deserialize(ref input);
        assert(read.is_none(), 'an index above 5 is refused');
        refused += 1;
    }
    let mut input = array![256].span();
    let read: Option<EdgeDirection> = Serde::deserialize(ref input);
    assert(read.is_none(), '256 is refused');
    let mut input = array![-1].span();
    let read: Option<EdgeDirection> = Serde::deserialize(ref input);
    assert(read.is_none(), 'felt -1 is refused');
}
