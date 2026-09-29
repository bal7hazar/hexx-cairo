//! Shared inputs and comparisons of the equality tests.
//!
//! Every input is fixed: a constant written here or in a test, or a Poseidon hash of a tag and an
//! index written in the test (`word`), never anything drawn at run time from elsewhere.

// Core imports

use core::poseidon::poseidon_hash_span;

/// The dimensions of the generators (brief, Scope 2): `3x3` to `83x3`, the window `15x16`.
pub const DIMENSIONS: [(u8, u8); 9] = [
    (3, 3), (7, 7), (15, 15), (15, 16), (17, 14), (19, 13), (25, 10), (83, 3), (3, 83),
];

/// Number of seeds of every generator input.
pub const SEEDS: u32 = 64;

/// The seed `index` of every generator (tag `'gen'`).
pub fn generator_seed(index: u32) -> felt252 {
    seed('gen', index)
}

/// The input grid of `Digger`, `Spreader` and `keep_component` for seed `index`, built by
/// `origami_hexmap` 1.8.0: a cave of order 3 for an even index, a random walk of `W * H` steps
/// for an odd one.
pub fn input_grid(width: u8, height: u8, index: u32) -> felt252 {
    let seed = seed('grid', index);
    if index % 2 == 0 {
        origami_hexmap::generators::caver::Caver::generate(width, height, 3, seed)
    } else {
        let steps: u16 = width.into() * height.into();
        origami_hexmap::generators::walker::Walker::generate(width, height, steps, seed)
    }
}

/// The seed `index` of the family `tag`.
pub fn seed(tag: felt252, index: u32) -> felt252 {
    poseidon_hash_span([tag, index.into()].span())
}

/// The seeded word `index` of the family `tag`, as a `u256`.
pub fn word(tag: felt252, index: u32) -> u256 {
    seed(tag, index).into()
}

/// A seeded integer in `[0, bound)`.
pub fn below(tag: felt252, index: u32, bound: u32) -> u32 {
    let value: u256 = word(tag, index);
    (value.low % bound.into()).try_into().unwrap()
}

/// `2^exp` as a `u256`, `exp < 256`, by squaring (independent of both libraries' tables).
pub fn two_pow(exp: u32) -> u256 {
    let mut value: u256 = 1;
    let mut base: u256 = 2;
    let mut count = exp;
    while count != 0 {
        if count % 2 == 1 {
            value = value * base;
        }
        count = count / 2;
        if count != 0 {
            base = base * base;
        }
    }
    value
}

/// The set bits of a bitmap, lowest index first.
pub fn tiles(grid: felt252) -> Array<u8> {
    let mut value: u256 = grid.into();
    let mut tiles: Array<u8> = array![];
    let mut index: u8 = 0;
    while value != 0 {
        if value.low % 2 == 1 {
            tiles.append(index);
        }
        value = value / 2;
        index += 1;
    }
    tiles
}

/// The edge tiles of a board that are not corners, lowest index first.
pub fn sides(width: u8, height: u8) -> Array<u8> {
    let mut sides: Array<u8> = array![];
    let mut y: u8 = 0;
    while y != height {
        let mut x: u8 = 0;
        while x != width {
            let edge = x == 0 || y == 0 || x == width - 1 || y == height - 1;
            let corner = (x == 0 || x == width - 1) && (y == 0 || y == height - 1);
            if edge && !corner {
                sides.append(y * width + x);
            }
            x += 1;
        }
        y += 1;
    }
    sides
}

/// Every valid dimension `(W, H)`: `W, H >= 3`, `W * H <= 251`, width first.
pub fn valid_dimensions() -> Array<(u8, u8)> {
    let mut dimensions: Array<(u8, u8)> = array![];
    let mut width: u16 = 3;
    while width * 3 <= 251 {
        let mut height: u16 = 3;
        while width * height <= 251 {
            dimensions.append((width.try_into().unwrap(), height.try_into().unwrap()));
            height += 1;
        }
        width += 1;
    }
    dimensions
}

/// The index of a direction of `origami_hexmap`, by a match written here.
pub fn origami_index(direction: origami_hexmap::Direction) -> u8 {
    match direction {
        origami_hexmap::Direction::East => 0,
        origami_hexmap::Direction::NorthEast => 1,
        origami_hexmap::Direction::NorthWest => 2,
        origami_hexmap::Direction::West => 3,
        origami_hexmap::Direction::SouthWest => 4,
        origami_hexmap::Direction::SouthEast => 5,
    }
}

/// The index of a direction of `hexx`, by a match written here.
pub fn hexx_index(direction: hexx::Direction) -> u8 {
    match direction {
        hexx::Direction::East => 0,
        hexx::Direction::NorthEast => 1,
        hexx::Direction::NorthWest => 2,
        hexx::Direction::West => 3,
        hexx::Direction::SouthWest => 4,
        hexx::Direction::SouthEast => 5,
    }
}

/// The direction `index` of `origami_hexmap`.
pub fn origami_direction(index: u8) -> origami_hexmap::Direction {
    match index {
        0 => origami_hexmap::Direction::East,
        1 => origami_hexmap::Direction::NorthEast,
        2 => origami_hexmap::Direction::NorthWest,
        3 => origami_hexmap::Direction::West,
        4 => origami_hexmap::Direction::SouthWest,
        _ => origami_hexmap::Direction::SouthEast,
    }
}

/// The direction `index` of `hexx`.
pub fn hexx_direction(index: u8) -> hexx::Direction {
    match index {
        0 => hexx::Direction::East,
        1 => hexx::Direction::NorthEast,
        2 => hexx::Direction::NorthWest,
        3 => hexx::Direction::West,
        4 => hexx::Direction::SouthWest,
        _ => hexx::Direction::SouthEast,
    }
}

/// Both maps are equal, field by field.
pub fn assert_maps(origami: origami_hexmap::HexMap, hexx: hexx::HexMap) {
    assert(origami.width == hexx.width, 'map width');
    assert(origami.height == hexx.height, 'map height');
    assert(origami.grid == hexx.grid, 'map grid');
    assert(origami.seed == hexx.seed, 'map seed');
}

/// Number of seeded positions or pairs on the `17x14` and on the `15x16` (brief, Scope 2).
pub const SEEDED_POSITIONS: u32 = 512;

/// The positions of the queries, `(width, height, position)`: every position of a `7x7`, then
/// 512 seeded positions of a `17x14` and 512 of a `15x16` (tag `'query'`).
pub fn query_positions() -> Array<(u8, u8, u8)> {
    let mut positions: Array<(u8, u8, u8)> = array![];
    let mut position: u8 = 0;
    while position != 49 {
        positions.append((7, 7, position));
        position += 1;
    }
    for (width, height) in [(17_u8, 14_u8), (15, 16)].span() {
        let (width, height) = (*width, *height);
        let size: u32 = width.into() * height.into();
        let mut index: u32 = 0;
        while index != SEEDED_POSITIONS {
            let position = below('query', size * 1000 + index, size);
            positions.append((width, height, position.try_into().unwrap()));
            index += 1;
        }
    }
    positions
}

/// The pairs of positions of the queries, `(width, height, from, to)`: every pair of a `7x7`,
/// then 512 seeded pairs of a `17x14` and 512 of a `15x16` (tag `'pair'`).
pub fn query_pairs() -> Array<(u8, u8, u8, u8)> {
    let mut pairs: Array<(u8, u8, u8, u8)> = array![];
    let mut from: u8 = 0;
    while from != 49 {
        let mut to: u8 = 0;
        while to != 49 {
            pairs.append((7, 7, from, to));
            to += 1;
        }
        from += 1;
    }
    for (width, height) in [(17_u8, 14_u8), (15, 16)].span() {
        let (width, height) = (*width, *height);
        let size: u32 = width.into() * height.into();
        let mut index: u32 = 0;
        while index != SEEDED_POSITIONS {
            let from = below('pair', size * 2000 + 2 * index, size);
            let to = below('pair', size * 2000 + 2 * index + 1, size);
            pairs.append((width, height, from.try_into().unwrap(), to.try_into().unwrap()));
            index += 1;
        }
    }
    pairs
}

/// The walkable edge tiles of a board: its entrances.
pub fn entrances(grid: felt252, width: u8, height: u8) -> Array<u8> {
    let mut entrances: Array<u8> = array![];
    for tile in tiles(grid) {
        let (y, x) = DivRem::div_rem(tile, width.try_into().unwrap());
        if x == 0 || y == 0 || x == width - 1 || y == height - 1 {
            entrances.append(tile);
        }
    }
    entrances
}

/// Number of seeded pairs and sources per board.
pub const PAIRS: u32 = 12;
pub const SOURCES: u32 = 6;

/// The endpoints of the finders on board `board` (an index of `fixtures::boards`), all walkable:
/// 12 seeded pairs (tag `'ends'`), `from == to` once, and every entrance paired with a seeded
/// tile both ways and with the next entrance.
pub fn endpoints(board: u32, grid: felt252, width: u8, height: u8) -> Array<(u8, u8)> {
    let open = tiles(grid);
    let count = open.len();
    let mut pairs: Array<(u8, u8)> = array![];
    let mut index: u32 = 0;
    while index != PAIRS {
        let from = *open.at(below('ends', board * 1000 + 2 * index, count));
        let to = *open.at(below('ends', board * 1000 + 2 * index + 1, count));
        pairs.append((from, to));
        index += 1;
    }
    let same = *open.at(below('same', board, count));
    pairs.append((same, same));
    let entrances = entrances(grid, width, height);
    let edges = entrances.len();
    let mut index: u32 = 0;
    while index != edges {
        let edge = *entrances.at(index);
        let other = *open.at(below('edge', board * 1000 + index, count));
        pairs.append((edge, other));
        pairs.append((other, edge));
        pairs.append((edge, *entrances.at((index + 1) % edges)));
        index += 1;
    }
    pairs
}

/// The sources of the floods on board `board`, all walkable: 6 seeded tiles (tag `'source'`)
/// and every entrance.
pub fn sources(board: u32, grid: felt252, width: u8, height: u8) -> Array<u8> {
    let open = tiles(grid);
    let count = open.len();
    let mut sources: Array<u8> = array![];
    let mut index: u32 = 0;
    while index != SOURCES {
        sources.append(*open.at(below('source', board * 1000 + index, count)));
        index += 1;
    }
    for edge in entrances(grid, width, height) {
        sources.append(edge);
    }
    sources
}

/// The radii of `range` and `ring`, and the budgets of `field_of_movement`.
pub const RADII: [u8; 9] = [0, 1, 2, 3, 4, 6, 9, 14, 40];

/// The cost classes of input `index` on a board: `index % 4` classes (0 to 3), each a seeded
/// bitmap of the board's tiles, walls included (tag `'costs'`).
pub fn costs(index: u32, width: u8, height: u8) -> Span<felt252> {
    let board = two_pow(width.into() * height.into()) - 1;
    let mut costs: Array<felt252> = array![];
    let mut class: u32 = 0;
    while class != index % 4 {
        let value = word('costs', index * 4 + class) & board;
        costs.append(value.try_into().unwrap());
        class += 1;
    }
    costs.span()
}
