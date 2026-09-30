//! `helpers::layout` of 1.8.0 against `hexx::board::layout`: `Layout`, `Dilation`,
//! `LayoutTrait::{new, board, even, interior, hexagon, with_interior, expand, expand_small,
//! dilation, edge_neighbours, neighbour_in, neighbour_mask, index, coords, parity, neighbor}`,
//! `DilationTrait::{dilate, expand_small}`. The three British-spelt helpers of 1.8.0 are
//! `edge_neighbors`, `neighbor_in` and `neighbor_mask` in `hexx` (plan §5.2): the tests keep the
//! names of 1.8.0 and call each side by its own.

use hexx::board::layout::{
    Dilation as HDilation, DilationTrait as HD, Layout as HLayout, LayoutTrait as H,
};
use origami_hexmap::helpers::layout::{
    Dilation as ODilation, DilationTrait as OD, Layout as OLayout, LayoutTrait as O,
};
use crate::common::{
    DIMENSIONS, hexx_direction, origami_direction, query_positions, two_pow, valid_dimensions, word,
};

/// Boards of at most 128 tiles, the domain of `expand_small`.
const SMALL: [(u8, u8); 8] = [
    (3, 3), (7, 7), (11, 11), (16, 8), (8, 16), (3, 42), (42, 3), (12, 10),
];

/// Seeded frontiers per board.
const FRONTIERS: u32 = 32;

fn assert_layouts(lhs: OLayout, rhs: HLayout) {
    assert(lhs.width == rhs.width, 'layout width');
    assert(lhs.height == rhs.height, 'layout height');
    assert(lhs.even == rhs.even, 'layout even');
    assert(lhs.up_even == rhs.up_even, 'layout up_even');
    assert(lhs.up_odd == rhs.up_odd, 'layout up_odd');
    assert(lhs.down_even == rhs.down_even, 'layout down_even');
    assert(lhs.down_odd == rhs.down_odd, 'layout down_odd');
}

fn assert_dilations(lhs: ODilation, rhs: HDilation) {
    assert(lhs.even_low == rhs.even_low, 'dilation even_low');
    assert(lhs.even_high == rhs.even_high, 'dilation even_high');
    assert(lhs.up == rhs.up, 'dilation up');
    assert(lhs.down == rhs.down, 'dilation down');
}

/// The frontiers of a board, interior tiles only (the border invariant): 32 seeded subsets of the
/// interior (tag `'frontier'`), the whole interior and the empty set.
fn frontiers(width: u8, height: u8) -> Array<u256> {
    let interior: u256 = O::interior(width, height).into();
    let size: u32 = width.into() * height.into();
    let mut frontiers: Array<u256> = array![interior, 0];
    let mut index: u32 = 0;
    while index != FRONTIERS {
        frontiers.append(word('frontier', size * 1000 + index) & interior);
        index += 1;
    }
    frontiers
}

/// Every valid dimension (675).
#[test]
#[available_gas(l2_gas: 17943954)]
fn test_layout_new() {
    for (width, height) in valid_dimensions() {
        assert_layouts(O::new(width, height), H::new(width, height));
    }
}

/// Every valid dimension.
#[test]
#[available_gas(l2_gas: 6325725)]
fn test_layout_board() {
    for (width, height) in valid_dimensions() {
        assert(O::board(width, height) == H::board(width, height), 'board');
    }
}

/// Every valid dimension.
#[test]
#[available_gas(l2_gas: 11189178)]
fn test_layout_even() {
    for (width, height) in valid_dimensions() {
        assert(O::even(width, height) == H::even(width, height), 'even');
    }
}

/// Every valid dimension.
#[test]
#[available_gas(l2_gas: 9926175)]
fn test_layout_interior() {
    for (width, height) in valid_dimensions() {
        assert(O::interior(width, height) == H::interior(width, height), 'interior');
    }
}

/// Every valid dimension.
#[test]
#[available_gas(l2_gas: 18405156)]
fn test_layout_with_interior() {
    for (width, height) in valid_dimensions() {
        let (lhs, left) = O::with_interior(width, height);
        let (rhs, right) = H::with_interior(width, height);
        assert_layouts(lhs, rhs);
        assert(left == right, 'with_interior');
    }
}

/// Every valid dimension.
#[test]
#[available_gas(l2_gas: 16951704)]
fn test_layout_dilation() {
    for (width, height) in valid_dimensions() {
        assert_dilations(O::new(width, height).dilation(), H::new(width, height).dilation());
    }
}

/// Every radius the facade accepts, 0 to 6.
#[test]
#[available_gas(l2_gas: 1129023)]
fn test_layout_hexagon() {
    let mut radius: u8 = 0;
    while radius != 7 {
        assert(O::hexagon(radius) == H::hexagon(radius), 'hexagon');
        radius += 1;
    }
}

/// The 9 dimensions of the generators, 34 frontiers each.
#[test]
#[available_gas(l2_gas: 16522910)]
fn test_layout_expand() {
    for (width, height) in DIMENSIONS.span() {
        let (width, height) = (*width, *height);
        let (lhs, rhs) = (O::new(width, height), H::new(width, height));
        for frontier in frontiers(width, height) {
            assert(lhs.expand(frontier) == rhs.expand(frontier), 'expand');
        }
    }
}

/// The 9 dimensions of the generators, 34 frontiers each.
#[test]
#[available_gas(l2_gas: 16470053)]
fn test_dilation_dilate() {
    for (width, height) in DIMENSIONS.span() {
        let (width, height) = (*width, *height);
        let (lhs, rhs) = (O::new(width, height).dilation(), H::new(width, height).dilation());
        for frontier in frontiers(width, height) {
            let felt: felt252 = frontier.try_into().unwrap();
            let left = OD::dilate(@lhs, frontier.low, frontier.high, felt);
            let right = HD::dilate(@rhs, frontier.low, frontier.high, felt);
            assert(left == right, 'dilate');
        }
    }
}

/// 8 boards of at most 128 tiles, 34 frontiers each.
#[test]
#[available_gas(l2_gas: 8893971)]
fn test_layout_expand_small() {
    for (width, height) in SMALL.span() {
        let (width, height) = (*width, *height);
        let (lhs, rhs) = (O::new(width, height), H::new(width, height));
        for frontier in frontiers(width, height) {
            assert(
                lhs.expand_small(frontier.low) == rhs.expand_small(frontier.low), 'expand_small',
            );
        }
    }
}

/// 8 boards of at most 128 tiles, 34 frontiers each.
#[test]
#[available_gas(l2_gas: 8656608)]
fn test_dilation_expand_small() {
    for (width, height) in SMALL.span() {
        let (width, height) = (*width, *height);
        let (lhs, rhs) = (O::new(width, height).dilation(), H::new(width, height).dilation());
        for frontier in frontiers(width, height) {
            let left = OD::expand_small(@lhs, frontier.low);
            let right = HD::expand_small(@rhs, frontier.low);
            assert(left == right, 'dilation expand_small');
        }
    }
}

/// Every position of the queries (`common::query_positions`).
#[test]
#[available_gas(l2_gas: 158118186)]
fn test_layout_edge_neighbours() {
    for (width, height, position) in query_positions() {
        let lhs = O::edge_neighbours(width, height, position);
        let rhs = H::edge_neighbors(width, height, position);
        assert(lhs == rhs, 'edge_neighbours');
    }
}

/// Every position of the queries, each with a seeded set of the board's tiles (tag `'set'`)
/// and with the empty set.
#[test]
#[available_gas(l2_gas: 515092320)]
fn test_layout_neighbour_in() {
    let mut index: u32 = 0;
    for (width, height, position) in query_positions() {
        let board = two_pow(width.into() * height.into()) - 1;
        let set = word('set', index) & board;
        let lhs = O::neighbour_in(width, height, position, set);
        let rhs = H::neighbor_in(width, height, position, set);
        assert(lhs == rhs, 'neighbour_in');
        let lhs = O::neighbour_in(width, height, position, 0);
        let rhs = H::neighbor_in(width, height, position, 0);
        assert(lhs == rhs, 'neighbour_in empty');
        index += 1;
    }
}

/// Every interior position of the queries (the domain of `neighbour_mask`).
#[test]
#[available_gas(l2_gas: 46833663)]
fn test_layout_neighbour_mask() {
    for (width, height, position) in query_positions() {
        let (x, y) = (position % width, position / width);
        if x != 0 && y != 0 && x != width - 1 && y != height - 1 {
            let lhs = O::new(width, height).neighbour_mask(position);
            let rhs = H::new(width, height).neighbor_mask(position);
            assert(lhs == rhs, 'neighbour_mask');
        }
    }
}

/// The coordinates of every position of the queries.
#[test]
#[available_gas(l2_gas: 24253707)]
fn test_layout_index() {
    for (width, _height, position) in query_positions() {
        let (x, y) = (position % width, position / width);
        assert(O::index(width, x, y) == H::index(width, x, y), 'index');
    }
}

/// Every position of the queries.
#[test]
#[available_gas(l2_gas: 22924260)]
fn test_layout_coords() {
    for (width, _height, position) in query_positions() {
        assert(O::coords(width, position) == H::coords(width, position), 'coords');
    }
}

/// Every position of the queries.
#[test]
#[available_gas(l2_gas: 27057669)]
fn test_layout_parity() {
    for (width, _height, position) in query_positions() {
        assert(O::parity(width, position) == H::parity(width, position), 'parity');
    }
}

/// Every position of the queries in every direction.
#[test]
#[available_gas(l2_gas: 137625273)]
fn test_layout_neighbor() {
    for (width, height, position) in query_positions() {
        let mut index: u8 = 0;
        while index != 6 {
            let lhs = O::neighbor(width, height, position, origami_direction(index));
            let rhs = H::neighbor(width, height, position, hexx_direction(index));
            assert(lhs == rhs, 'neighbor');
            index += 1;
        }
    }
}
