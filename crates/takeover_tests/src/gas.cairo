//! Scope 5 of the brief: the gas of the 20 functions of the facade through `origami_hexmap` 1.8.0
//! and through `hexx`, measured as SPK-7 of the game does: a test that calls the function twice
//! minus a test that calls it once, on the same input. Reported in `REPORT.md`, not enforced (the
//! budgets of these tests follow the rule of every test).
//!
//! **These figures are the marginal costs of the measured call sites**, not of the functions in
//! general: one call on one input, with its argument helpers and the check of its result. The
//! input is `fixtures::CAVE_17X14` (a `17x14` cave of 1.8.0), its far endpoints 52 and 20, the
//! tile 191, the side tile 8, two cost classes, the seed `'seed'`. From the side tile 8 of that
//! cave both openings stop at once (the tile next to 8 is floor: the early exit of
//! `Digger::dig`), so `open_with_corridor_long` and `open_with_maze_long` measure a long dig
//! beside it: the side tile 8 of a `17x14` whose only open tile is 202, at the other end of the
//! board (the early exits add 1 tile, the long corridor 58 and the long maze 89: their grids
//! hold 59 and 90 open tiles against 1). Every value goes through an `#[inline(never)]` identity so
//! that no call is folded at compile time.
//!
//! Each result is checked against the value that the equality tests establish for both libraries
//! (the `EXPECTED_*` constants, read from 1.8.0; a check that fails on a wrong result, so that no
//! call is dropped and no call is measured on a wrong path). The check is part of the difference,
//! the same on both sides.
//!
//! `board` and `lone` also burn a fixed amount of gas in a loop (charged per iteration, exactly,
//! and the same in both tests of a pair, so it cancels in the difference): without it, the test
//! of one cheap call measures about 22,000 and the static pre-charge of its costliest branch
//! exceeds the 5 % margin of the budget rule.

use hexx::HexMapTrait as H;
use origami_hexmap::HexMapTrait as O;
use crate::fixtures::CAVE_17X14;

/// Iterations of the loop of `board` and `lone`.
const PADDING: u32 = 200;

/// The only open tile of the board of the long digs, 202 of a `17x14`.
const LONE: felt252 = 0x400000000000000000000000000000000000000000000000000;

#[inline(never)]
fn board() -> (felt252, u8, u8, felt252) {
    let mut count: u32 = 0;
    while count != PADDING {
        count += 1;
    }
    (CAVE_17X14, 17, 14, 'seed')
}

#[inline(never)]
fn lone() -> (felt252, u8, u8, felt252) {
    let mut count: u32 = 0;
    while count != PADDING {
        count += 1;
    }
    (LONE, 17, 14, 'seed')
}

#[inline(never)]
fn byte(value: u8) -> u8 {
    value
}

#[inline(never)]
fn steps(value: u16) -> u16 {
    value
}

/// Two cost classes on the `17x14`: cost 2 and cost 3.
#[inline(never)]
fn classes() -> Span<felt252> {
    array![0x3c00000000001e0000000f00000007800000000000, 0x780000000000000000000000000000000].span()
}

// The values the equality tests establish for both libraries, read from 1.8.0.

const EXPECTED_NEW: felt252 = 0xff803ffc3ffe1fffcfffe3fe71e238f01cf8ce7ff93ffc001f00000;

const EXPECTED_NEW_EMPTY: felt252 = 0xfffe7fff3fff9fffcfffe7fff3fff9fffcfffe7fff3fff9fffc0000;

const EXPECTED_NEW_MAZE: felt252 = 0x96dc3a99257309424b59c42983cb091d24b15c249919b31bb340000;

const EXPECTED_NEW_CAVE: felt252 = 0xfc003e313f0cffc7ff81ffc1ffc0f3f0797c3e1f3f9f83c600000;

const EXPECTED_NEW_RANDOM_WALK: felt252 = 0x1e003f001f80078037c2fcb3fff8bffc1f7e077f0e3f8787c0000;

const EXPECTED_NEW_HEXAGON: felt252 = 0x3f80ff01ff07fe0ffe3ffc7ffcfff0ffe1ff81ff03fc03f80000;

const EXPECTED_OPEN_WITH_CORRIDOR: felt252 =
    0xff803ffc3ffe1fffcfffe3fe71e238f01cf8ce7ff93ffc001f00100;

const EXPECTED_OPEN_WITH_MAZE: felt252 = 0xff803ffc3ffe1fffcfffe3fe71e238f01cf8ce7ff93ffc001f00100;

const EXPECTED_OPEN_WITH_CORRIDOR_LONG: felt252 =
    0x384072304104174214c08a508ad03d14016a006a0009801d80100;

const EXPECTED_OPEN_WITH_MAZE_LONG: felt252 =
    0x3a385372364114d74a94c4aa528ad13d14816a316a0e899cdd80100;

const EXPECTED_KEEP_COMPONENT: felt252 = 0xff803ffc3ffe1fffcfffe3fe71e238f01cf8ce7ff93ffc001f00000;

const EXPECTED_COMPUTE_DISTRIBUTION: felt252 = 0x20000400008100000082000000000411000000000400000;

const EXPECTED_SEARCH_PATH: [u8; 24] = [
    20, 21, 22, 23, 24, 42, 43, 44, 61, 79, 96, 113, 129, 128, 127, 126, 125, 142, 141, 140, 122,
    105, 87, 70,
];

const EXPECTED_SEARCH_PATH_WEIGHTED: [u8; 24] = [
    20, 21, 22, 23, 24, 42, 43, 44, 61, 79, 96, 113, 129, 146, 145, 144, 143, 142, 141, 140, 122,
    105, 87, 70,
];

const EXPECTED_FIELD_OF_MOVEMENT: felt252 =
    0x78003fc01fe003fc03fe006700238001c000000000000000000000;

const EXPECTED_DISTANCE_TO: Option<u8> = Some(24);

const EXPECTED_HEX_DISTANCE: u8 = 3;

const EXPECTED_REACHABLE: felt252 = 0xff803ffc3ffe1fffcfffe3fe71e238f01cf8ce7ff93ffc001f00000;

const EXPECTED_RANGE: felt252 = 0x18000fc007e001fc00fc0026000000000000000000000000000000;

const EXPECTED_RING: felt252 = 0x100008000400010400840026000000000000000000000000000000;

const EXPECTED_NEIGHBOR: Option<u8> = Some(208);

const EXPECTED_IS_WALKABLE: bool = true;

#[test]
#[available_gas(l2_gas: 283910)]
fn test_gas_new_origami_once() {
    let (grid, width, height, seed) = board();
    let result = O::new(grid, width, height, seed);
    assert(result.grid == EXPECTED_NEW, 'result');
}

#[test]
#[available_gas(l2_gas: 284120)]
fn test_gas_new_origami_twice() {
    let (grid, width, height, seed) = board();
    let result = O::new(grid, width, height, seed);
    assert(result.grid == EXPECTED_NEW, 'result');
    let result = O::new(grid, width, height, seed);
    assert(result.grid == EXPECTED_NEW, 'result');
}

#[test]
#[available_gas(l2_gas: 283910)]
fn test_gas_new_hexx_once() {
    let (grid, width, height, seed) = board();
    let result = H::new(grid, width, height, seed);
    assert(result.grid == EXPECTED_NEW, 'result');
}

#[test]
#[available_gas(l2_gas: 284120)]
fn test_gas_new_hexx_twice() {
    let (grid, width, height, seed) = board();
    let result = H::new(grid, width, height, seed);
    assert(result.grid == EXPECTED_NEW, 'result');
    let result = H::new(grid, width, height, seed);
    assert(result.grid == EXPECTED_NEW, 'result');
}

#[test]
#[available_gas(l2_gas: 291869)]
fn test_gas_new_empty_origami_once() {
    let (_grid, width, height, seed) = board();
    let result = O::new_empty(width, height, seed);
    assert(result.grid == EXPECTED_NEW_EMPTY, 'result');
}

#[test]
#[available_gas(l2_gas: 298757)]
fn test_gas_new_empty_origami_twice() {
    let (_grid, width, height, seed) = board();
    let result = O::new_empty(width, height, seed);
    assert(result.grid == EXPECTED_NEW_EMPTY, 'result');
    let result = O::new_empty(width, height, seed);
    assert(result.grid == EXPECTED_NEW_EMPTY, 'result');
}

#[test]
#[available_gas(l2_gas: 291869)]
fn test_gas_new_empty_hexx_once() {
    let (_grid, width, height, seed) = board();
    let result = H::new_empty(width, height, seed);
    assert(result.grid == EXPECTED_NEW_EMPTY, 'result');
}

#[test]
#[available_gas(l2_gas: 298757)]
fn test_gas_new_empty_hexx_twice() {
    let (_grid, width, height, seed) = board();
    let result = H::new_empty(width, height, seed);
    assert(result.grid == EXPECTED_NEW_EMPTY, 'result');
    let result = H::new_empty(width, height, seed);
    assert(result.grid == EXPECTED_NEW_EMPTY, 'result');
}

#[test]
#[available_gas(l2_gas: 3356402)]
fn test_gas_new_maze_origami_once() {
    let (_grid, width, height, seed) = board();
    let result = O::new_maze(width, height, byte(0), seed);
    assert(result.grid == EXPECTED_NEW_MAZE, 'result');
}

#[test]
#[available_gas(l2_gas: 6430595)]
fn test_gas_new_maze_origami_twice() {
    let (_grid, width, height, seed) = board();
    let result = O::new_maze(width, height, byte(0), seed);
    assert(result.grid == EXPECTED_NEW_MAZE, 'result');
    let result = O::new_maze(width, height, byte(0), seed);
    assert(result.grid == EXPECTED_NEW_MAZE, 'result');
}

#[test]
#[available_gas(l2_gas: 3356402)]
fn test_gas_new_maze_hexx_once() {
    let (_grid, width, height, seed) = board();
    let result = H::new_maze(width, height, byte(0), seed);
    assert(result.grid == EXPECTED_NEW_MAZE, 'result');
}

#[test]
#[available_gas(l2_gas: 6430595)]
fn test_gas_new_maze_hexx_twice() {
    let (_grid, width, height, seed) = board();
    let result = H::new_maze(width, height, byte(0), seed);
    assert(result.grid == EXPECTED_NEW_MAZE, 'result');
    let result = H::new_maze(width, height, byte(0), seed);
    assert(result.grid == EXPECTED_NEW_MAZE, 'result');
}

#[test]
#[available_gas(l2_gas: 424607)]
fn test_gas_new_cave_origami_once() {
    let (_grid, width, height, seed) = board();
    let result = O::new_cave(width, height, byte(3), seed);
    assert(result.grid == EXPECTED_NEW_CAVE, 'result');
}

#[test]
#[available_gas(l2_gas: 566900)]
fn test_gas_new_cave_origami_twice() {
    let (_grid, width, height, seed) = board();
    let result = O::new_cave(width, height, byte(3), seed);
    assert(result.grid == EXPECTED_NEW_CAVE, 'result');
    let result = O::new_cave(width, height, byte(3), seed);
    assert(result.grid == EXPECTED_NEW_CAVE, 'result');
}

#[test]
#[available_gas(l2_gas: 424607)]
fn test_gas_new_cave_hexx_once() {
    let (_grid, width, height, seed) = board();
    let result = H::new_cave(width, height, byte(3), seed);
    assert(result.grid == EXPECTED_NEW_CAVE, 'result');
}

#[test]
#[available_gas(l2_gas: 566900)]
fn test_gas_new_cave_hexx_twice() {
    let (_grid, width, height, seed) = board();
    let result = H::new_cave(width, height, byte(3), seed);
    assert(result.grid == EXPECTED_NEW_CAVE, 'result');
    let result = H::new_cave(width, height, byte(3), seed);
    assert(result.grid == EXPECTED_NEW_CAVE, 'result');
}

#[test]
#[available_gas(l2_gas: 2763555)]
fn test_gas_new_random_walk_origami_once() {
    let (_grid, width, height, seed) = board();
    let result = O::new_random_walk(width, height, steps(500), seed);
    assert(result.grid == EXPECTED_NEW_RANDOM_WALK, 'result');
}

#[test]
#[available_gas(l2_gas: 5244587)]
fn test_gas_new_random_walk_origami_twice() {
    let (_grid, width, height, seed) = board();
    let result = O::new_random_walk(width, height, steps(500), seed);
    assert(result.grid == EXPECTED_NEW_RANDOM_WALK, 'result');
    let result = O::new_random_walk(width, height, steps(500), seed);
    assert(result.grid == EXPECTED_NEW_RANDOM_WALK, 'result');
}

#[test]
#[available_gas(l2_gas: 2763555)]
fn test_gas_new_random_walk_hexx_once() {
    let (_grid, width, height, seed) = board();
    let result = H::new_random_walk(width, height, steps(500), seed);
    assert(result.grid == EXPECTED_NEW_RANDOM_WALK, 'result');
}

#[test]
#[available_gas(l2_gas: 5244587)]
fn test_gas_new_random_walk_hexx_twice() {
    let (_grid, width, height, seed) = board();
    let result = H::new_random_walk(width, height, steps(500), seed);
    assert(result.grid == EXPECTED_NEW_RANDOM_WALK, 'result');
    let result = H::new_random_walk(width, height, steps(500), seed);
    assert(result.grid == EXPECTED_NEW_RANDOM_WALK, 'result');
}

#[test]
#[available_gas(l2_gas: 433472)]
fn test_gas_new_hexagon_origami_once() {
    let (_grid, _width, _height, seed) = board();
    let result = O::new_hexagon(byte(6), seed);
    assert(result.grid == EXPECTED_NEW_HEXAGON, 'result');
}

#[test]
#[available_gas(l2_gas: 582278)]
fn test_gas_new_hexagon_origami_twice() {
    let (_grid, _width, _height, seed) = board();
    let result = O::new_hexagon(byte(6), seed);
    assert(result.grid == EXPECTED_NEW_HEXAGON, 'result');
    let result = O::new_hexagon(byte(6), seed);
    assert(result.grid == EXPECTED_NEW_HEXAGON, 'result');
}

#[test]
#[available_gas(l2_gas: 433472)]
fn test_gas_new_hexagon_hexx_once() {
    let (_grid, _width, _height, seed) = board();
    let result = H::new_hexagon(byte(6), seed);
    assert(result.grid == EXPECTED_NEW_HEXAGON, 'result');
}

#[test]
#[available_gas(l2_gas: 582278)]
fn test_gas_new_hexagon_hexx_twice() {
    let (_grid, _width, _height, seed) = board();
    let result = H::new_hexagon(byte(6), seed);
    assert(result.grid == EXPECTED_NEW_HEXAGON, 'result');
    let result = H::new_hexagon(byte(6), seed);
    assert(result.grid == EXPECTED_NEW_HEXAGON, 'result');
}

#[test]
#[available_gas(l2_gas: 358783)]
fn test_gas_open_with_corridor_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR, 'result');
}

#[test]
#[available_gas(l2_gas: 432691)]
fn test_gas_open_with_corridor_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR, 'result');
    let mut copy = map;
    O::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR, 'result');
}

#[test]
#[available_gas(l2_gas: 358783)]
fn test_gas_open_with_corridor_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR, 'result');
}

#[test]
#[available_gas(l2_gas: 432691)]
fn test_gas_open_with_corridor_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR, 'result');
    let mut copy = map;
    H::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR, 'result');
}

#[test]
#[available_gas(l2_gas: 358783)]
fn test_gas_open_with_maze_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE, 'result');
}

#[test]
#[available_gas(l2_gas: 432691)]
fn test_gas_open_with_maze_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE, 'result');
    let mut copy = map;
    O::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE, 'result');
}

#[test]
#[available_gas(l2_gas: 358783)]
fn test_gas_open_with_maze_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE, 'result');
}

#[test]
#[available_gas(l2_gas: 432691)]
fn test_gas_open_with_maze_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE, 'result');
    let mut copy = map;
    H::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE, 'result');
}

#[test]
#[available_gas(l2_gas: 2380964)]
fn test_gas_open_with_corridor_long_origami_once() {
    let (grid, width, height, seed) = lone();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR_LONG, 'result');
}

#[test]
#[available_gas(l2_gas: 4477051)]
fn test_gas_open_with_corridor_long_origami_twice() {
    let (grid, width, height, seed) = lone();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR_LONG, 'result');
    let mut copy = map;
    O::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR_LONG, 'result');
}

#[test]
#[available_gas(l2_gas: 2380964)]
fn test_gas_open_with_corridor_long_hexx_once() {
    let (grid, width, height, seed) = lone();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR_LONG, 'result');
}

#[test]
#[available_gas(l2_gas: 4477051)]
fn test_gas_open_with_corridor_long_hexx_twice() {
    let (grid, width, height, seed) = lone();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR_LONG, 'result');
    let mut copy = map;
    H::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_CORRIDOR_LONG, 'result');
}

#[test]
#[available_gas(l2_gas: 3689786)]
fn test_gas_open_with_maze_long_origami_once() {
    let (grid, width, height, seed) = lone();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE_LONG, 'result');
}

#[test]
#[available_gas(l2_gas: 7094695)]
fn test_gas_open_with_maze_long_origami_twice() {
    let (grid, width, height, seed) = lone();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE_LONG, 'result');
    let mut copy = map;
    O::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE_LONG, 'result');
}

#[test]
#[available_gas(l2_gas: 3689786)]
fn test_gas_open_with_maze_long_hexx_once() {
    let (grid, width, height, seed) = lone();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE_LONG, 'result');
}

#[test]
#[available_gas(l2_gas: 7094695)]
fn test_gas_open_with_maze_long_hexx_twice() {
    let (grid, width, height, seed) = lone();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE_LONG, 'result');
    let mut copy = map;
    H::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid == EXPECTED_OPEN_WITH_MAZE_LONG, 'result');
}

#[test]
#[available_gas(l2_gas: 764952)]
fn test_gas_keep_component_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::keep_component(ref copy, byte(191));
    assert(copy.grid == EXPECTED_KEEP_COMPONENT, 'result');
}

#[test]
#[available_gas(l2_gas: 1247484)]
fn test_gas_keep_component_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::keep_component(ref copy, byte(191));
    assert(copy.grid == EXPECTED_KEEP_COMPONENT, 'result');
    let mut copy = map;
    O::keep_component(ref copy, byte(191));
    assert(copy.grid == EXPECTED_KEEP_COMPONENT, 'result');
}

#[test]
#[available_gas(l2_gas: 764952)]
fn test_gas_keep_component_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::keep_component(ref copy, byte(191));
    assert(copy.grid == EXPECTED_KEEP_COMPONENT, 'result');
}

#[test]
#[available_gas(l2_gas: 1247484)]
fn test_gas_keep_component_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::keep_component(ref copy, byte(191));
    assert(copy.grid == EXPECTED_KEEP_COMPONENT, 'result');
    let mut copy = map;
    H::keep_component(ref copy, byte(191));
    assert(copy.grid == EXPECTED_KEEP_COMPONENT, 'result');
}

#[test]
#[available_gas(l2_gas: 425994)]
fn test_gas_compute_distribution_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::compute_distribution(map, byte(10), seed);
    assert(result == EXPECTED_COMPUTE_DISTRIBUTION, 'result');
}

#[test]
#[available_gas(l2_gas: 569569)]
fn test_gas_compute_distribution_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::compute_distribution(map, byte(10), seed);
    assert(result == EXPECTED_COMPUTE_DISTRIBUTION, 'result');
    let result = O::compute_distribution(map, byte(10), seed);
    assert(result == EXPECTED_COMPUTE_DISTRIBUTION, 'result');
}

#[test]
#[available_gas(l2_gas: 425994)]
fn test_gas_compute_distribution_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::compute_distribution(map, byte(10), seed);
    assert(result == EXPECTED_COMPUTE_DISTRIBUTION, 'result');
}

#[test]
#[available_gas(l2_gas: 569569)]
fn test_gas_compute_distribution_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::compute_distribution(map, byte(10), seed);
    assert(result == EXPECTED_COMPUTE_DISTRIBUTION, 'result');
    let result = H::compute_distribution(map, byte(10), seed);
    assert(result == EXPECTED_COMPUTE_DISTRIBUTION, 'result');
}

#[test]
#[available_gas(l2_gas: 1103976)]
fn test_gas_search_path_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::search_path(map, byte(52), byte(20));
    assert(result == EXPECTED_SEARCH_PATH.span(), 'result');
}

#[test]
#[available_gas(l2_gas: 1922760)]
fn test_gas_search_path_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::search_path(map, byte(52), byte(20));
    assert(result == EXPECTED_SEARCH_PATH.span(), 'result');
    let result = O::search_path(map, byte(52), byte(20));
    assert(result == EXPECTED_SEARCH_PATH.span(), 'result');
}

#[test]
#[available_gas(l2_gas: 1103976)]
fn test_gas_search_path_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::search_path(map, byte(52), byte(20));
    assert(result == EXPECTED_SEARCH_PATH.span(), 'result');
}

#[test]
#[available_gas(l2_gas: 1922760)]
fn test_gas_search_path_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::search_path(map, byte(52), byte(20));
    assert(result == EXPECTED_SEARCH_PATH.span(), 'result');
    let result = H::search_path(map, byte(52), byte(20));
    assert(result == EXPECTED_SEARCH_PATH.span(), 'result');
}

#[test]
#[available_gas(l2_gas: 1912144)]
fn test_gas_search_path_weighted_origami_once() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = O::new(grid, width, height, seed);
    let result = O::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result == EXPECTED_SEARCH_PATH_WEIGHTED.span(), 'result');
}

#[test]
#[available_gas(l2_gas: 3538362)]
fn test_gas_search_path_weighted_origami_twice() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = O::new(grid, width, height, seed);
    let result = O::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result == EXPECTED_SEARCH_PATH_WEIGHTED.span(), 'result');
    let result = O::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result == EXPECTED_SEARCH_PATH_WEIGHTED.span(), 'result');
}

#[test]
#[available_gas(l2_gas: 1912144)]
fn test_gas_search_path_weighted_hexx_once() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = H::new(grid, width, height, seed);
    let result = H::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result == EXPECTED_SEARCH_PATH_WEIGHTED.span(), 'result');
}

#[test]
#[available_gas(l2_gas: 3538362)]
fn test_gas_search_path_weighted_hexx_twice() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = H::new(grid, width, height, seed);
    let result = H::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result == EXPECTED_SEARCH_PATH_WEIGHTED.span(), 'result');
    let result = H::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result == EXPECTED_SEARCH_PATH_WEIGHTED.span(), 'result');
}

#[test]
#[available_gas(l2_gas: 577489)]
fn test_gas_field_of_movement_origami_once() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = O::new(grid, width, height, seed);
    let result = O::field_of_movement(map, byte(191), byte(6), costs);
    assert(result == EXPECTED_FIELD_OF_MOVEMENT, 'result');
}

#[test]
#[available_gas(l2_gas: 871824)]
fn test_gas_field_of_movement_origami_twice() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = O::new(grid, width, height, seed);
    let result = O::field_of_movement(map, byte(191), byte(6), costs);
    assert(result == EXPECTED_FIELD_OF_MOVEMENT, 'result');
    let result = O::field_of_movement(map, byte(191), byte(6), costs);
    assert(result == EXPECTED_FIELD_OF_MOVEMENT, 'result');
}

#[test]
#[available_gas(l2_gas: 577489)]
fn test_gas_field_of_movement_hexx_once() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = H::new(grid, width, height, seed);
    let result = H::field_of_movement(map, byte(191), byte(6), costs);
    assert(result == EXPECTED_FIELD_OF_MOVEMENT, 'result');
}

#[test]
#[available_gas(l2_gas: 871824)]
fn test_gas_field_of_movement_hexx_twice() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = H::new(grid, width, height, seed);
    let result = H::field_of_movement(map, byte(191), byte(6), costs);
    assert(result == EXPECTED_FIELD_OF_MOVEMENT, 'result');
    let result = H::field_of_movement(map, byte(191), byte(6), costs);
    assert(result == EXPECTED_FIELD_OF_MOVEMENT, 'result');
}

#[test]
#[available_gas(l2_gas: 834270)]
fn test_gas_distance_to_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::distance_to(map, byte(52), byte(20));
    assert(result == EXPECTED_DISTANCE_TO, 'result');
}

#[test]
#[available_gas(l2_gas: 1383768)]
fn test_gas_distance_to_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::distance_to(map, byte(52), byte(20));
    assert(result == EXPECTED_DISTANCE_TO, 'result');
    let result = O::distance_to(map, byte(52), byte(20));
    assert(result == EXPECTED_DISTANCE_TO, 'result');
}

#[test]
#[available_gas(l2_gas: 834270)]
fn test_gas_distance_to_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::distance_to(map, byte(52), byte(20));
    assert(result == EXPECTED_DISTANCE_TO, 'result');
}

#[test]
#[available_gas(l2_gas: 1383768)]
fn test_gas_distance_to_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::distance_to(map, byte(52), byte(20));
    assert(result == EXPECTED_DISTANCE_TO, 'result');
    let result = H::distance_to(map, byte(52), byte(20));
    assert(result == EXPECTED_DISTANCE_TO, 'result');
}

#[test]
#[available_gas(l2_gas: 296720)]
fn test_gas_hex_distance_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::hex_distance(map, byte(52), byte(20));
    assert(result == EXPECTED_HEX_DISTANCE, 'result');
}

#[test]
#[available_gas(l2_gas: 308774)]
fn test_gas_hex_distance_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::hex_distance(map, byte(52), byte(20));
    assert(result == EXPECTED_HEX_DISTANCE, 'result');
    let result = O::hex_distance(map, byte(52), byte(20));
    assert(result == EXPECTED_HEX_DISTANCE, 'result');
}

#[test]
#[available_gas(l2_gas: 296720)]
fn test_gas_hex_distance_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::hex_distance(map, byte(52), byte(20));
    assert(result == EXPECTED_HEX_DISTANCE, 'result');
}

#[test]
#[available_gas(l2_gas: 308774)]
fn test_gas_hex_distance_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::hex_distance(map, byte(52), byte(20));
    assert(result == EXPECTED_HEX_DISTANCE, 'result');
    let result = H::hex_distance(map, byte(52), byte(20));
    assert(result == EXPECTED_HEX_DISTANCE, 'result');
}

#[test]
#[available_gas(l2_gas: 764952)]
fn test_gas_reachable_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::reachable(map, byte(191));
    assert(result == EXPECTED_REACHABLE, 'result');
}

#[test]
#[available_gas(l2_gas: 1247484)]
fn test_gas_reachable_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::reachable(map, byte(191));
    assert(result == EXPECTED_REACHABLE, 'result');
    let result = O::reachable(map, byte(191));
    assert(result == EXPECTED_REACHABLE, 'result');
}

#[test]
#[available_gas(l2_gas: 764952)]
fn test_gas_reachable_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::reachable(map, byte(191));
    assert(result == EXPECTED_REACHABLE, 'result');
}

#[test]
#[available_gas(l2_gas: 1247484)]
fn test_gas_reachable_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::reachable(map, byte(191));
    assert(result == EXPECTED_REACHABLE, 'result');
    let result = H::reachable(map, byte(191));
    assert(result == EXPECTED_REACHABLE, 'result');
}

#[test]
#[available_gas(l2_gas: 406784)]
fn test_gas_range_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::range(map, byte(191), byte(4));
    assert(result == EXPECTED_RANGE, 'result');
}

#[test]
#[available_gas(l2_gas: 531149)]
fn test_gas_range_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::range(map, byte(191), byte(4));
    assert(result == EXPECTED_RANGE, 'result');
    let result = O::range(map, byte(191), byte(4));
    assert(result == EXPECTED_RANGE, 'result');
}

#[test]
#[available_gas(l2_gas: 406784)]
fn test_gas_range_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::range(map, byte(191), byte(4));
    assert(result == EXPECTED_RANGE, 'result');
}

#[test]
#[available_gas(l2_gas: 531149)]
fn test_gas_range_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::range(map, byte(191), byte(4));
    assert(result == EXPECTED_RANGE, 'result');
    let result = H::range(map, byte(191), byte(4));
    assert(result == EXPECTED_RANGE, 'result');
}

#[test]
#[available_gas(l2_gas: 404453)]
fn test_gas_ring_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::ring(map, byte(191), byte(4));
    assert(result == EXPECTED_RING, 'result');
}

#[test]
#[available_gas(l2_gas: 526592)]
fn test_gas_ring_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::ring(map, byte(191), byte(4));
    assert(result == EXPECTED_RING, 'result');
    let result = O::ring(map, byte(191), byte(4));
    assert(result == EXPECTED_RING, 'result');
}

#[test]
#[available_gas(l2_gas: 404453)]
fn test_gas_ring_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::ring(map, byte(191), byte(4));
    assert(result == EXPECTED_RING, 'result');
}

#[test]
#[available_gas(l2_gas: 526592)]
fn test_gas_ring_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::ring(map, byte(191), byte(4));
    assert(result == EXPECTED_RING, 'result');
    let result = H::ring(map, byte(191), byte(4));
    assert(result == EXPECTED_RING, 'result');
}

#[test]
#[available_gas(l2_gas: 292709)]
fn test_gas_neighbor_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::neighbor(map, byte(191), origami_hexmap::Direction::NorthEast);
    assert(result == EXPECTED_NEIGHBOR, 'result');
}

#[test]
#[available_gas(l2_gas: 300752)]
fn test_gas_neighbor_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::neighbor(map, byte(191), origami_hexmap::Direction::NorthEast);
    assert(result == EXPECTED_NEIGHBOR, 'result');
    let result = O::neighbor(map, byte(191), origami_hexmap::Direction::NorthEast);
    assert(result == EXPECTED_NEIGHBOR, 'result');
}

#[test]
#[available_gas(l2_gas: 292709)]
fn test_gas_neighbor_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::neighbor(map, byte(191), hexx::Direction::NorthEast);
    assert(result == EXPECTED_NEIGHBOR, 'result');
}

#[test]
#[available_gas(l2_gas: 300752)]
fn test_gas_neighbor_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::neighbor(map, byte(191), hexx::Direction::NorthEast);
    assert(result == EXPECTED_NEIGHBOR, 'result');
    let result = H::neighbor(map, byte(191), hexx::Direction::NorthEast);
    assert(result == EXPECTED_NEIGHBOR, 'result');
}

#[test]
#[available_gas(l2_gas: 292954)]
fn test_gas_is_walkable_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::is_walkable(map, byte(191));
    assert(result == EXPECTED_IS_WALKABLE, 'result');
}

#[test]
#[available_gas(l2_gas: 300926)]
fn test_gas_is_walkable_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::is_walkable(map, byte(191));
    assert(result == EXPECTED_IS_WALKABLE, 'result');
    let result = O::is_walkable(map, byte(191));
    assert(result == EXPECTED_IS_WALKABLE, 'result');
}

#[test]
#[available_gas(l2_gas: 292954)]
fn test_gas_is_walkable_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::is_walkable(map, byte(191));
    assert(result == EXPECTED_IS_WALKABLE, 'result');
}

#[test]
#[available_gas(l2_gas: 300926)]
fn test_gas_is_walkable_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::is_walkable(map, byte(191));
    assert(result == EXPECTED_IS_WALKABLE, 'result');
    let result = H::is_walkable(map, byte(191));
    assert(result == EXPECTED_IS_WALKABLE, 'result');
}
