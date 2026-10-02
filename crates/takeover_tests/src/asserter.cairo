//! `helpers::asserter` of 1.8.0 against `hexx::board::asserter`: `MAX_SIZE`, `errors`,
//! `Asserter::{is_edge, is_corner, assert_valid_dimension, assert_on_edge, assert_not_corner,
//! assert_inside}`.
//!
//! An `assert_*` returns nothing: on its accepting inputs, both sides must return (the test fails
//! if either panics); on its rejecting inputs, both sides must panic with the same message (the
//! `#[should_panic]` pairs below).

use hexx::board::asserter as h;
use hexx::board::asserter::Asserter as H;
use origami_hexmap::helpers::asserter as o;
use origami_hexmap::helpers::asserter::Asserter as O;
use crate::common::{DIMENSIONS, query_positions, sides, valid_dimensions};

#[test]
#[available_gas(l2_gas: 6311)]
fn test_asserter_constants() {
    assert(o::MAX_SIZE == h::MAX_SIZE, 'MAX_SIZE');
    assert(
        o::errors::ASSERTER_INVALID_DIMENSION == h::errors::ASSERTER_INVALID_DIMENSION, 'dimension',
    );
    assert(
        o::errors::ASSERTER_POSITION_IS_CORNER == h::errors::ASSERTER_POSITION_IS_CORNER, 'corner',
    );
    assert(o::errors::ASSERTER_POSITION_NOT_EDGE == h::errors::ASSERTER_POSITION_NOT_EDGE, 'edge');
    assert(
        o::errors::ASSERTER_POSITION_NOT_INSIDE == h::errors::ASSERTER_POSITION_NOT_INSIDE,
        'inside',
    );
}

/// The coordinates of every position of the queries (`common::query_positions`).
#[test]
#[available_gas(l2_gas: 28325838)]
fn test_asserter_is_edge_is_corner() {
    for (width, height, position) in query_positions() {
        let (x, y) = (position % width, position / width);
        assert(O::is_edge(width, height, x, y) == H::is_edge(width, height, x, y), 'is_edge');
        assert(O::is_corner(width, height, x, y) == H::is_corner(width, height, x, y), 'is_corner');
    }
}

/// Every valid dimension (`W, H >= 3`, `W * H <= 251`, 675 pairs): both accept.
#[test]
#[available_gas(l2_gas: 7012205)]
fn test_asserter_assert_valid_dimension() {
    for (width, height) in valid_dimensions() {
        O::assert_valid_dimension(width, height);
        H::assert_valid_dimension(width, height);
    }
}

/// Every side tile of the 9 dimensions of the generators: both accept.
#[test]
#[available_gas(l2_gas: 12973611)]
fn test_asserter_assert_on_edge() {
    for (width, height) in DIMENSIONS.span() {
        let (width, height) = (*width, *height);
        for position in sides(width, height) {
            O::assert_on_edge(width, height, position);
            H::assert_on_edge(width, height, position);
        }
    }
}

/// Every position of the queries that is not a corner: both accept.
#[test]
#[available_gas(l2_gas: 27147087)]
fn test_asserter_assert_not_corner() {
    for (width, height, position) in query_positions() {
        let (x, y) = (position % width, position / width);
        if !((x == 0 || x == width - 1) && (y == 0 || y == height - 1)) {
            O::assert_not_corner(width, height, position);
            H::assert_not_corner(width, height, position);
        }
    }
}

/// Every position of the queries: both accept.
#[test]
#[available_gas(l2_gas: 21969894)]
fn test_asserter_assert_inside() {
    for (width, height, position) in query_positions() {
        O::assert_inside(width, height, position);
        H::assert_inside(width, height, position);
    }
}

// Panics: one test per side, same input, same message.

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_asserter_width_too_small_origami() {
    O::assert_valid_dimension(2, 50);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_asserter_width_too_small_hexx() {
    H::assert_valid_dimension(2, 50);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_asserter_height_too_small_origami() {
    O::assert_valid_dimension(50, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_asserter_height_too_small_hexx() {
    H::assert_valid_dimension(50, 2);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_asserter_too_large_origami() {
    O::assert_valid_dimension(12, 21);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: invalid dimension')]
fn test_asserter_too_large_hexx() {
    H::assert_valid_dimension(12, 21);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_asserter_not_edge_origami() {
    O::assert_on_edge(7, 7, 24);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not an edge')]
fn test_asserter_not_edge_hexx() {
    H::assert_on_edge(7, 7, 24);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_asserter_corner_origami() {
    O::assert_not_corner(7, 7, 48);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position is a corner')]
fn test_asserter_corner_hexx() {
    H::assert_not_corner(7, 7, 48);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_asserter_not_inside_origami() {
    O::assert_inside(7, 7, 49);
}

#[test]
#[available_gas(l2_gas: 8201)]
#[should_panic(expected: 'Asserter: position not inside')]
fn test_asserter_not_inside_hexx() {
    H::assert_inside(7, 7, 49);
}
