//! Scope 5 of the brief: the gas of the 20 functions of the facade through `origami_hexmap` 1.8.0
//! and through `hexx`, measured as SPK-7 of the game does: a test that calls the function twice
//! minus a test that calls it once, on the same input, is the cost of one call. Reported in
//! `REPORT.md`, not enforced (the budgets of these tests follow the rule of every test).
//!
//! The input is `fixtures::CAVE_17X14` (a `17x14` cave of 1.8.0), its far endpoints 52 and 20,
//! the tile 191, the side tile 8, two cost classes, the seed `'seed'`; every value goes through
//! an `#[inline(never)]` identity so that no call is folded at compile time. Each result is
//! checked against an impossible value, so that no call is dropped; the check is part of the
//! difference, the same on both sides.
//!
//! `board` also burns a fixed amount of gas in a loop (charged per iteration, exactly, and the
//! same in both tests of a pair, so it cancels in the difference): without it, the test of one
//! cheap call measures about 22,000 and the static pre-charge of its costliest branch exceeds the
//! 5 % margin of the budget rule.

use hexx::HexMapTrait as H;
use origami_hexmap::HexMapTrait as O;
use crate::fixtures::CAVE_17X14;

/// A value no result takes.
const SENTINEL: felt252 = 0x123456789;

/// Iterations of the loop of `board`.
const PADDING: u32 = 200;

#[inline(never)]
fn board() -> (felt252, u8, u8, felt252) {
    let mut count: u32 = 0;
    while count != PADDING {
        count += 1;
    }
    (CAVE_17X14, 17, 14, 'seed')
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

#[test]
#[available_gas(l2_gas: 283910)]
fn test_gas_new_origami_once() {
    let (grid, width, height, seed) = board();
    let result = O::new(grid, width, height, seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 284120)]
fn test_gas_new_origami_twice() {
    let (grid, width, height, seed) = board();
    let result = O::new(grid, width, height, seed);
    assert(result.grid != SENTINEL, 'result');
    let result = O::new(grid, width, height, seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 283910)]
fn test_gas_new_hexx_once() {
    let (grid, width, height, seed) = board();
    let result = H::new(grid, width, height, seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 284120)]
fn test_gas_new_hexx_twice() {
    let (grid, width, height, seed) = board();
    let result = H::new(grid, width, height, seed);
    assert(result.grid != SENTINEL, 'result');
    let result = H::new(grid, width, height, seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 291869)]
fn test_gas_new_empty_origami_once() {
    let (_grid, width, height, seed) = board();
    let result = O::new_empty(width, height, seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 298757)]
fn test_gas_new_empty_origami_twice() {
    let (_grid, width, height, seed) = board();
    let result = O::new_empty(width, height, seed);
    assert(result.grid != SENTINEL, 'result');
    let result = O::new_empty(width, height, seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 291869)]
fn test_gas_new_empty_hexx_once() {
    let (_grid, width, height, seed) = board();
    let result = H::new_empty(width, height, seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 298757)]
fn test_gas_new_empty_hexx_twice() {
    let (_grid, width, height, seed) = board();
    let result = H::new_empty(width, height, seed);
    assert(result.grid != SENTINEL, 'result');
    let result = H::new_empty(width, height, seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 3356402)]
fn test_gas_new_maze_origami_once() {
    let (_grid, width, height, seed) = board();
    let result = O::new_maze(width, height, byte(0), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 6430595)]
fn test_gas_new_maze_origami_twice() {
    let (_grid, width, height, seed) = board();
    let result = O::new_maze(width, height, byte(0), seed);
    assert(result.grid != SENTINEL, 'result');
    let result = O::new_maze(width, height, byte(0), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 3356402)]
fn test_gas_new_maze_hexx_once() {
    let (_grid, width, height, seed) = board();
    let result = H::new_maze(width, height, byte(0), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 6430595)]
fn test_gas_new_maze_hexx_twice() {
    let (_grid, width, height, seed) = board();
    let result = H::new_maze(width, height, byte(0), seed);
    assert(result.grid != SENTINEL, 'result');
    let result = H::new_maze(width, height, byte(0), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 424607)]
fn test_gas_new_cave_origami_once() {
    let (_grid, width, height, seed) = board();
    let result = O::new_cave(width, height, byte(3), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 566900)]
fn test_gas_new_cave_origami_twice() {
    let (_grid, width, height, seed) = board();
    let result = O::new_cave(width, height, byte(3), seed);
    assert(result.grid != SENTINEL, 'result');
    let result = O::new_cave(width, height, byte(3), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 424607)]
fn test_gas_new_cave_hexx_once() {
    let (_grid, width, height, seed) = board();
    let result = H::new_cave(width, height, byte(3), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 566900)]
fn test_gas_new_cave_hexx_twice() {
    let (_grid, width, height, seed) = board();
    let result = H::new_cave(width, height, byte(3), seed);
    assert(result.grid != SENTINEL, 'result');
    let result = H::new_cave(width, height, byte(3), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 2763555)]
fn test_gas_new_random_walk_origami_once() {
    let (_grid, width, height, seed) = board();
    let result = O::new_random_walk(width, height, steps(500), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 5244587)]
fn test_gas_new_random_walk_origami_twice() {
    let (_grid, width, height, seed) = board();
    let result = O::new_random_walk(width, height, steps(500), seed);
    assert(result.grid != SENTINEL, 'result');
    let result = O::new_random_walk(width, height, steps(500), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 2763555)]
fn test_gas_new_random_walk_hexx_once() {
    let (_grid, width, height, seed) = board();
    let result = H::new_random_walk(width, height, steps(500), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 5244587)]
fn test_gas_new_random_walk_hexx_twice() {
    let (_grid, width, height, seed) = board();
    let result = H::new_random_walk(width, height, steps(500), seed);
    assert(result.grid != SENTINEL, 'result');
    let result = H::new_random_walk(width, height, steps(500), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 433472)]
fn test_gas_new_hexagon_origami_once() {
    let (_grid, _width, _height, seed) = board();
    let result = O::new_hexagon(byte(6), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 582278)]
fn test_gas_new_hexagon_origami_twice() {
    let (_grid, _width, _height, seed) = board();
    let result = O::new_hexagon(byte(6), seed);
    assert(result.grid != SENTINEL, 'result');
    let result = O::new_hexagon(byte(6), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 433472)]
fn test_gas_new_hexagon_hexx_once() {
    let (_grid, _width, _height, seed) = board();
    let result = H::new_hexagon(byte(6), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 582278)]
fn test_gas_new_hexagon_hexx_twice() {
    let (_grid, _width, _height, seed) = board();
    let result = H::new_hexagon(byte(6), seed);
    assert(result.grid != SENTINEL, 'result');
    let result = H::new_hexagon(byte(6), seed);
    assert(result.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 358783)]
fn test_gas_open_with_corridor_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 432691)]
fn test_gas_open_with_corridor_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
    let mut copy = map;
    O::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 358783)]
fn test_gas_open_with_corridor_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 432691)]
fn test_gas_open_with_corridor_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
    let mut copy = map;
    H::open_with_corridor(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 358783)]
fn test_gas_open_with_maze_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 432691)]
fn test_gas_open_with_maze_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
    let mut copy = map;
    O::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 358783)]
fn test_gas_open_with_maze_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 432691)]
fn test_gas_open_with_maze_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
    let mut copy = map;
    H::open_with_maze(ref copy, byte(8), byte(0));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 764952)]
fn test_gas_keep_component_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::keep_component(ref copy, byte(191));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 1247484)]
fn test_gas_keep_component_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let mut copy = map;
    O::keep_component(ref copy, byte(191));
    assert(copy.grid != SENTINEL, 'result');
    let mut copy = map;
    O::keep_component(ref copy, byte(191));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 764952)]
fn test_gas_keep_component_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::keep_component(ref copy, byte(191));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 1247484)]
fn test_gas_keep_component_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let mut copy = map;
    H::keep_component(ref copy, byte(191));
    assert(copy.grid != SENTINEL, 'result');
    let mut copy = map;
    H::keep_component(ref copy, byte(191));
    assert(copy.grid != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 425994)]
fn test_gas_compute_distribution_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::compute_distribution(map, byte(10), seed);
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 569569)]
fn test_gas_compute_distribution_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::compute_distribution(map, byte(10), seed);
    assert(result != SENTINEL, 'result');
    let result = O::compute_distribution(map, byte(10), seed);
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 425994)]
fn test_gas_compute_distribution_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::compute_distribution(map, byte(10), seed);
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 569569)]
fn test_gas_compute_distribution_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::compute_distribution(map, byte(10), seed);
    assert(result != SENTINEL, 'result');
    let result = H::compute_distribution(map, byte(10), seed);
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 1047097)]
fn test_gas_search_path_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::search_path(map, byte(52), byte(20));
    assert(result.len() != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 1811775)]
fn test_gas_search_path_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::search_path(map, byte(52), byte(20));
    assert(result.len() != 255, 'result');
    let result = O::search_path(map, byte(52), byte(20));
    assert(result.len() != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 1047097)]
fn test_gas_search_path_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::search_path(map, byte(52), byte(20));
    assert(result.len() != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 1811775)]
fn test_gas_search_path_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::search_path(map, byte(52), byte(20));
    assert(result.len() != 255, 'result');
    let result = H::search_path(map, byte(52), byte(20));
    assert(result.len() != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 1855265)]
fn test_gas_search_path_weighted_origami_once() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = O::new(grid, width, height, seed);
    let result = O::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result.len() != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 3427377)]
fn test_gas_search_path_weighted_origami_twice() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = O::new(grid, width, height, seed);
    let result = O::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result.len() != 255, 'result');
    let result = O::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result.len() != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 1855265)]
fn test_gas_search_path_weighted_hexx_once() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = H::new(grid, width, height, seed);
    let result = H::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result.len() != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 3427377)]
fn test_gas_search_path_weighted_hexx_twice() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = H::new(grid, width, height, seed);
    let result = H::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result.len() != 255, 'result');
    let result = H::search_path_weighted(map, byte(52), byte(20), costs);
    assert(result.len() != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 577489)]
fn test_gas_field_of_movement_origami_once() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = O::new(grid, width, height, seed);
    let result = O::field_of_movement(map, byte(191), byte(6), costs);
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 871824)]
fn test_gas_field_of_movement_origami_twice() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = O::new(grid, width, height, seed);
    let result = O::field_of_movement(map, byte(191), byte(6), costs);
    assert(result != SENTINEL, 'result');
    let result = O::field_of_movement(map, byte(191), byte(6), costs);
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 577489)]
fn test_gas_field_of_movement_hexx_once() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = H::new(grid, width, height, seed);
    let result = H::field_of_movement(map, byte(191), byte(6), costs);
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 871824)]
fn test_gas_field_of_movement_hexx_twice() {
    let (grid, width, height, seed) = board();
    let costs = classes();
    let map = H::new(grid, width, height, seed);
    let result = H::field_of_movement(map, byte(191), byte(6), costs);
    assert(result != SENTINEL, 'result');
    let result = H::field_of_movement(map, byte(191), byte(6), costs);
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 834375)]
fn test_gas_distance_to_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::distance_to(map, byte(52), byte(20));
    assert(result != Some(255), 'result');
}

#[test]
#[available_gas(l2_gas: 1383978)]
fn test_gas_distance_to_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::distance_to(map, byte(52), byte(20));
    assert(result != Some(255), 'result');
    let result = O::distance_to(map, byte(52), byte(20));
    assert(result != Some(255), 'result');
}

#[test]
#[available_gas(l2_gas: 834375)]
fn test_gas_distance_to_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::distance_to(map, byte(52), byte(20));
    assert(result != Some(255), 'result');
}

#[test]
#[available_gas(l2_gas: 1383978)]
fn test_gas_distance_to_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::distance_to(map, byte(52), byte(20));
    assert(result != Some(255), 'result');
    let result = H::distance_to(map, byte(52), byte(20));
    assert(result != Some(255), 'result');
}

#[test]
#[available_gas(l2_gas: 296615)]
fn test_gas_hex_distance_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::hex_distance(map, byte(52), byte(20));
    assert(result != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 308564)]
fn test_gas_hex_distance_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::hex_distance(map, byte(52), byte(20));
    assert(result != 255, 'result');
    let result = O::hex_distance(map, byte(52), byte(20));
    assert(result != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 296615)]
fn test_gas_hex_distance_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::hex_distance(map, byte(52), byte(20));
    assert(result != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 308564)]
fn test_gas_hex_distance_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::hex_distance(map, byte(52), byte(20));
    assert(result != 255, 'result');
    let result = H::hex_distance(map, byte(52), byte(20));
    assert(result != 255, 'result');
}

#[test]
#[available_gas(l2_gas: 764952)]
fn test_gas_reachable_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::reachable(map, byte(191));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 1247484)]
fn test_gas_reachable_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::reachable(map, byte(191));
    assert(result != SENTINEL, 'result');
    let result = O::reachable(map, byte(191));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 764952)]
fn test_gas_reachable_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::reachable(map, byte(191));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 1247484)]
fn test_gas_reachable_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::reachable(map, byte(191));
    assert(result != SENTINEL, 'result');
    let result = H::reachable(map, byte(191));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 406784)]
fn test_gas_range_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::range(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 531149)]
fn test_gas_range_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::range(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
    let result = O::range(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 406784)]
fn test_gas_range_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::range(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 531149)]
fn test_gas_range_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::range(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
    let result = H::range(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 404453)]
fn test_gas_ring_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::ring(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 526592)]
fn test_gas_ring_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::ring(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
    let result = O::ring(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 404453)]
fn test_gas_ring_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::ring(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 526592)]
fn test_gas_ring_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::ring(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
    let result = H::ring(map, byte(191), byte(4));
    assert(result != SENTINEL, 'result');
}

#[test]
#[available_gas(l2_gas: 292814)]
fn test_gas_neighbor_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::neighbor(map, byte(191), origami_hexmap::Direction::NorthEast);
    assert(result != Some(255), 'result');
}

#[test]
#[available_gas(l2_gas: 300962)]
fn test_gas_neighbor_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::neighbor(map, byte(191), origami_hexmap::Direction::NorthEast);
    assert(result != Some(255), 'result');
    let result = O::neighbor(map, byte(191), origami_hexmap::Direction::NorthEast);
    assert(result != Some(255), 'result');
}

#[test]
#[available_gas(l2_gas: 292814)]
fn test_gas_neighbor_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::neighbor(map, byte(191), hexx::Direction::NorthEast);
    assert(result != Some(255), 'result');
}

#[test]
#[available_gas(l2_gas: 300962)]
fn test_gas_neighbor_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::neighbor(map, byte(191), hexx::Direction::NorthEast);
    assert(result != Some(255), 'result');
    let result = H::neighbor(map, byte(191), hexx::Direction::NorthEast);
    assert(result != Some(255), 'result');
}

#[test]
#[available_gas(l2_gas: 292744)]
fn test_gas_is_walkable_origami_once() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::is_walkable(map, byte(191));
    assert(result || !result, 'result');
}

#[test]
#[available_gas(l2_gas: 300506)]
fn test_gas_is_walkable_origami_twice() {
    let (grid, width, height, seed) = board();
    let map = O::new(grid, width, height, seed);
    let result = O::is_walkable(map, byte(191));
    assert(result || !result, 'result');
    let result = O::is_walkable(map, byte(191));
    assert(result || !result, 'result');
}

#[test]
#[available_gas(l2_gas: 292744)]
fn test_gas_is_walkable_hexx_once() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::is_walkable(map, byte(191));
    assert(result || !result, 'result');
}

#[test]
#[available_gas(l2_gas: 300506)]
fn test_gas_is_walkable_hexx_twice() {
    let (grid, width, height, seed) = board();
    let map = H::new(grid, width, height, seed);
    let result = H::is_walkable(map, byte(191));
    assert(result || !result, 'result');
    let result = H::is_walkable(map, byte(191));
    assert(result || !result, 'result');
}
