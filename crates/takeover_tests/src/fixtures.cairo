//! The inputs of the finders: the fixtures of `origami_hexmap` 1.8.0 and 32 generated boards.
//!
//! The fixtures of 1.8.0 are `#[cfg(test)]` items of its crate, not visible from this package:
//! their values are copied here, each with the line of
//! `origami:crates/hexmap/src/tests/fixtures.cairo` (commit `04ab30c`) it comes from.

// Core imports

use origami_hexmap::HexMapTrait;
use crate::common::{seed, sides, tiles};

/// A board: grid, width, height.
#[derive(Copy, Drop)]
pub struct Board {
    pub grid: felt252,
    pub width: u8,
    pub height: u8,
}

// Fixtures of 1.8.0, `src/tests/fixtures.cairo`.

/// `EMPTY_17X14`, `:25`.
pub const EMPTY_17X14: felt252 = 0xfffe7fff3fff9fffcfffe7fff3fff9fffcfffe7fff3fff9fffc0000;
/// `CAVE_17X14`, `:50`.
pub const CAVE_17X14: felt252 = 0xff803ffc3ffe1fffcfffe3fe71e238f01cf8ce7ff93ffc001f00000;
/// `MAZE_17X14`, `:75`.
pub const MAZE_17X14: felt252 = 0x677a66231de40886cb5ca259d1222857642cd471450c2a9df340000;
/// `SERPENTINE_17X14`, `:100`.
pub const SERPENTINE_17X14: felt252 = 0x7fff00009fffc80007fff00009fffc80007fff00009fffc0000;
/// `UNREACHABLE_17X14`, `:125`.
pub const UNREACHABLE_17X14: felt252 = 0xfefe7f7f3fbf9fdfcfefe7f7f3fbf9fdfcfefe7f7f3fbf9fdfc0000;
/// `EMPTY_7X7`, `:143`.
pub const EMPTY_7X7: felt252 = 0x1f3e7cf9f00;
/// `CAVE_7X7`, `:161`.
pub const CAVE_7X7: felt252 = 0x1f3e3cf1f00;
/// `MAZE_7X7`, `:179`.
pub const MAZE_7X7: felt252 = 0x17325409f00;
/// `SERPENTINE_7X7`, `:197`.
pub const SERPENTINE_7X7: felt252 = 0x1f207c09f00;
/// `UNREACHABLE_7X7`, `:215`.
pub const UNREACHABLE_7X7: felt252 = 0x1b366cd9b00;

/// The endpoints of the fixtures, `(grid, width, from, to)`: `*_NEAR_FROM`, `*_NEAR_TO`,
/// `*_FAR_FROM`, `*_FAR_TO` of 1.8.0 (`:26-30`, `:51-55`, `:76-80`, `:101-105`, `:126-130`,
/// `:144-148`, `:162-166`, `:180-184`, `:198-202`, `:216-220`).
pub const ENDPOINTS: [(felt252, u8, u8, u8); 20] = [
    (EMPTY_17X14, 17, 129, 77), (EMPTY_17X14, 17, 202, 18), (CAVE_17X14, 17, 191, 139),
    (CAVE_17X14, 17, 52, 20), (MAZE_17X14, 17, 66, 47), (MAZE_17X14, 17, 149, 18),
    (SERPENTINE_17X14, 17, 93, 90), (SERPENTINE_17X14, 17, 202, 32),
    (UNREACHABLE_17X14, 17, 126, 128), (UNREACHABLE_17X14, 17, 18, 219), (EMPTY_7X7, 7, 30, 8),
    (EMPTY_7X7, 7, 40, 8), (CAVE_7X7, 7, 24, 8), (CAVE_7X7, 7, 40, 8), (MAZE_7X7, 7, 22, 9),
    (MAZE_7X7, 7, 26, 12), (SERPENTINE_7X7, 7, 15, 10), (SERPENTINE_7X7, 7, 36, 12),
    (UNREACHABLE_7X7, 7, 23, 25), (UNREACHABLE_7X7, 7, 8, 40),
];

/// The 10 fixtures of 1.8.0 as boards: the five `17X14` and their `7X7` forms.
pub fn fixtures() -> Array<Board> {
    array![
        Board { grid: EMPTY_17X14, width: 17, height: 14 },
        Board { grid: CAVE_17X14, width: 17, height: 14 },
        Board { grid: MAZE_17X14, width: 17, height: 14 },
        Board { grid: SERPENTINE_17X14, width: 17, height: 14 },
        Board { grid: UNREACHABLE_17X14, width: 17, height: 14 },
        Board { grid: EMPTY_7X7, width: 7, height: 7 },
        Board { grid: CAVE_7X7, width: 7, height: 7 },
        Board { grid: MAZE_7X7, width: 7, height: 7 },
        Board { grid: SERPENTINE_7X7, width: 7, height: 7 },
        Board { grid: UNREACHABLE_7X7, width: 7, height: 7 },
    ]
}

// Generated boards.

/// Kinds of the generated boards.
const CAVE: u8 = 0; // `new_cave` of order 3, then `keep_component` on its middle floor tile
const CAVE_RAW: u8 = 1; // `new_cave` of order 2, several components kept
const MAZE: u8 = 2; // `new_maze` of order 0
const SPARSE: u8 = 3; // `new_maze` of order 1
const WALK: u8 = 4; // `new_random_walk` of `W * H` steps

/// Openings of the generated boards, from a seeded side tile (an entrance on the edge).
const CLOSED: u8 = 0;
const CORRIDOR: u8 = 1; // `open_with_corridor`, order 0
const OPENED: u8 = 2; // `open_with_maze`, order 0

/// The recipes of the 32 generated boards, `(width, height, kind, opening)`; board `k` uses
/// the seed `seed('board', k)`. Eight are `15x16`, the size of the game's window.
pub const RECIPES: [(u8, u8, u8, u8); 32] = [
    (15, 16, CAVE, CLOSED), (15, 16, CAVE, CORRIDOR), (15, 16, MAZE, CLOSED),
    (15, 16, MAZE, OPENED), (15, 16, SPARSE, CLOSED), (15, 16, WALK, CLOSED),
    (15, 16, WALK, CORRIDOR), (15, 16, CAVE_RAW, CLOSED), (17, 14, CAVE, CLOSED),
    (17, 14, MAZE, CORRIDOR), (17, 14, SPARSE, CLOSED), (17, 14, WALK, CLOSED),
    (17, 14, CAVE_RAW, CLOSED), (17, 14, CAVE, OPENED), (19, 13, CAVE, CORRIDOR),
    (19, 13, MAZE, CLOSED), (19, 13, WALK, CLOSED), (19, 13, SPARSE, CORRIDOR),
    (25, 10, CAVE, CLOSED), (25, 10, MAZE, CORRIDOR), (25, 10, WALK, CLOSED),
    (25, 10, CAVE_RAW, CLOSED), (15, 15, CAVE, CORRIDOR), (15, 15, SPARSE, CLOSED),
    (15, 15, WALK, CLOSED), (15, 15, MAZE, CLOSED), (11, 11, CAVE, CORRIDOR),
    (11, 11, MAZE, CLOSED), (7, 7, CAVE, CLOSED), (7, 7, WALK, CORRIDOR), (83, 3, WALK, CORRIDOR),
    (3, 83, WALK, CORRIDOR),
];

/// The generated board `index`, built by `origami_hexmap` 1.8.0 from its recipe.
pub fn generate(index: u32) -> Board {
    let (width, height, kind, opening) = *RECIPES.span().at(index);
    let seed = seed('board', index);
    let mut map = if kind == CAVE || kind == CAVE_RAW {
        HexMapTrait::new_cave(width, height, if kind == CAVE {
            3
        } else {
            2
        }, seed)
    } else if kind == MAZE || kind == SPARSE {
        HexMapTrait::new_maze(width, height, kind - MAZE, seed)
    } else {
        let steps: u16 = width.into() * height.into();
        HexMapTrait::new_random_walk(width, height, steps, seed)
    };
    if kind == CAVE {
        let floor = tiles(map.grid);
        map.keep_component(*floor.at(floor.len() / 2));
    }
    if opening != CLOSED {
        let sides = sides(width, height);
        let start = *sides.at(index % sides.len());
        if opening == CORRIDOR {
            map.open_with_corridor(start, 0);
        } else {
            map.open_with_maze(start, 0);
        }
    }
    Board { grid: map.grid, width, height }
}

/// The 32 generated boards, `generate(0)` to `generate(31)` as printed by `origami_hexmap` 1.8.0
/// (`test_boards_provenance` regenerates them).
pub const BOARDS: [Board; 32] = [
    Board { grid: 0xf00ff0ffe1ffe33f807f80ff00fc01c003d81fe01c80000, width: 15, height: 16 },
    Board {
        grid: 0x3000f103e603fe01ff01ff07e63bc0870100c202821ac4d487590004, width: 15, height: 16,
    },
    Board {
        grid: 0xeed931633445564aa689190cca332c92a8dca201a3524adb136d0000, width: 15, height: 16,
    },
    Board {
        grid: 0xdb31695112a15b42c89d150bca402cf9a90aa31465d6841587e60010, width: 15, height: 16,
    },
    Board {
        grid: 0x800100020004000803920c262042408700c900e20022004800880000, width: 15, height: 16,
    },
    Board {
        grid: 0x1e007c01f806180c200c00e003c00f801f803e007e00f801f000000, width: 15, height: 16,
    },
    Board {
        grid: 0xf800f801f801f0078006001f801fc0df81fb03fc077c0f401fc00080, width: 15, height: 16,
    },
    Board { grid: 0x1800398473bc47f80f807003f0c7c387c70f9c1fbc7e7070c0000, width: 15, height: 16 },
    Board { grid: 0x1c000600030001c001e00230033803fc07fc0fde1fc707c180000, width: 17, height: 14 },
    Board {
        grid: 0x8d9c253114af16b04943232552ed5089a45b5a691116e904cb80400, width: 17, height: 14,
    },
    Board {
        grid: 0x90843839242111908870830440c3c011100c084003307207e700000, width: 17, height: 14,
    },
    Board { grid: 0xae007f003f803fc01fe005f005f8013c00fe003f001e000780000, width: 17, height: 14 },
    Board {
        grid: 0x602638ff3cff9effcfefe3fbf3ff80f240f0383c9c3cfe180c00000, width: 17, height: 14,
    },
    Board {
        grid: 0x381c0fcf0fff0fffcfffe7ffc3ffc0fff073f81cfe0cff043984000, width: 17, height: 14,
    },
    Board { grid: 0x9c781fff03ffe03ffc06ff80dc301f8401f8007e003bc008000, width: 19, height: 13 },
    Board {
        grid: 0x79fcc1c0a965ed26c42380788701139ed1804a6266c5732869dd00000, width: 19, height: 13,
    },
    Board {
        grid: 0x3c00078001fc003f8007b800e6001ee003fc007f800ff000ff0000000, width: 19, height: 13,
    },
    Board {
        grid: 0x71e043040810610384c04c7030901c0e00024007c00f087900f880000, width: 19, height: 13,
    },
    Board {
        grid: 0x241c00ff0f00ffe380fff8f8e7c0fc39f9ff1cffff0327f9c000000, width: 25, height: 10,
    },
    Board {
        grid: 0xf9af7642ac66392b00924d5fc6d9502608937179664863aeec100000, width: 25, height: 10,
    },
    Board { grid: 0x7fc0003ff0007ff0001f7c001f20000f80001f800003c00000000, width: 25, height: 10 },
    Board {
        grid: 0x2640c67f3e73ff27f8ff99f87ffdf83ffffc3ffffc0478400000000, width: 25, height: 10,
    },
    Board { grid: 0x62038d87898f360f3e1e7c1efc7cfbfcf1ffc07fc0f900300000, width: 15, height: 15 },
    Board { grid: 0x11c73cf2400000000000000000000000000000000000000000000, width: 15, height: 15 },
    Board { grid: 0x10006001c0038187033e01fc03f801f0000, width: 15, height: 15 },
    Board { grid: 0x11b33d3241dcb8808ef164228b096b92b4311656e83259cc60000, width: 15, height: 15 },
    Board { grid: 0x300380300e00f01e01e03e07e000, width: 11, height: 11 },
    Board { grid: 0x1363a6428950d10bc484e093f000, width: 11, height: 11 },
    Board { grid: 0x70c0c18300, width: 7, height: 7 },
    Board { grid: 0x183e7ef9f00, width: 7, height: 7 },
    Board { grid: 0x7fff8000000000000000000080000000, width: 83, height: 3 },
    Board { grid: 0x2493492492480000, width: 3, height: 83 },
];

/// The 10 fixtures and the 32 generated boards, the inputs of every finder.
pub fn boards() -> Array<Board> {
    let mut boards = fixtures();
    for board in BOARDS.span() {
        boards.append(*board);
    }
    boards
}

#[cfg(test)]
mod tests {
    use super::{BOARDS, generate};

    /// The generated boards are what `origami_hexmap` 1.8.0 builds from their recipes.
    /// 32 boards, one generation each.
    #[test]
    #[available_gas(l2_gas: 75836047)]
    fn test_boards_provenance() {
        let mut index: u32 = 0;
        for board in BOARDS.span() {
            let expected = generate(index);
            assert(*board.grid == expected.grid, 'board grid');
            assert(*board.width == expected.width, 'board width');
            assert(*board.height == expected.height, 'board height');
            index += 1;
        }
    }
}
