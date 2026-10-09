//! `algorithms::pathfinding`: the counterpart of `hexx`'s `a_star`
//! (`src/algorithms/pathfinding.rs`) on a `HexMap`.

// Internal imports

use crate::board::map::{HexMap, HexMapTrait};
use crate::finders::dial::errors;

/// Largest number of cost classes of `Dial`.
const MAX_CLASSES: u32 = 3;

/// The cheapest path from `from` to `to`, both included, `None` if there is none.
///
/// A free function, by decision of the brief of M3-T1: it mirrors the free function of `hexx` at
/// the same path (`hexx::algorithms::a_star`), and the mirror keeps `hexx`'s names and paths
/// (principle 8), as `shapes` does. It forwards to `HexMapTrait::search_path_weighted`.
///
/// `costs[k]` is the bitmap of the tiles of entry cost `k + 2`, the other walkable tiles cost 1.
/// The closure of `hexx` is `cost(_, b) = None` if `b` is off the board, a wall, or an edge tile
/// other than `from` and `to` (a path of the board never crosses an edge tile; `hexx` evaluates
/// `cost(start, start)`, so an open edge `from` must be accepted), else `Some(c)` with `c` the
/// entry cost of `b`. `hexx`'s `a_star` adds the cost as given (`pathfinding.rs:134`): this is
/// not the mapping of `field_of_movement`, whose `hexx` side adds `1 +` to the cost of the
/// closure.
///
/// The total entry cost is `hexx`'s: every cost is at least 1, so the heuristic
/// `unsigned_distance_to` is consistent and `hexx`'s search is optimal as the board's is.
///
/// Mirrors `hexx::algorithms::a_star` (`src/algorithms/pathfinding.rs:110`).
///
/// #### Panics
///
/// * If there are more than 3 cost classes (`'Dial: too many costs'`).
///
/// #### Deviations
///
/// * Per-tile entry costs only, no directed `cost(a, b)`: `hexx`'s closure takes both tiles.
/// * At most 3 classes, so entry costs 1 to 4, against any `u32` cost.
/// * On a bounded board, an open edge tile is an endpoint only: a path never crosses it.
/// * Ties: the path is the board's (backtracking on the lowest tile index), which may differ
/// from `hexx`'s heap order among paths of equal cost; the total cost is equal.
/// * An endpoint outside the board is `None`, as a wall (`hexx` has no board).
/// * The path is a `Span<u8>` of tile indices, `hexx`'s a `Vec<Hex>`.
pub fn a_star(map: HexMap, from: u8, to: u8, costs: Span<felt252>) -> Option<Span<u8>> {
    assert(costs.len() <= MAX_CLASSES, errors::DIAL_TOO_MANY_COSTS);
    // `hexx`: `cost(end, end)?` and `cost(start, start)?`
    if !map.is_walkable(from) || !map.is_walkable(to) {
        return Option::None;
    }
    if from == to {
        return Option::Some(array![from].span());
    }
    // The board's path: from the target (included) to the start (excluded)
    let backwards = map.search_path_weighted(from, to, costs);
    if backwards.is_empty() {
        return Option::None;
    }
    let mut path = array![from];
    let mut index = backwards.len();
    while index != 0 {
        index -= 1;
        path.append(*backwards[index]);
    }
    Option::Some(path.span())
}

#[cfg(test)]
mod tests {
    // Internal imports

    use crate::board::bits::Bits;
    use crate::board::map::{HexMap, HexMapTrait};
    use crate::tests::bench_dial::{
        CAVE_17X14_COST_2, CAVE_17X14_COST_3, UNREACHABLE, check_path, dijkstra, random_costs,
    };
    use crate::tests::fixtures::{
        CAVE_17X14, CAVE_17X14_FAR_FROM, CAVE_17X14_FAR_TO, CAVE_17X14_NEAR_FROM,
        CAVE_17X14_NEAR_TO, CAVE_7X7, EMPTY_17X14, EMPTY_17X14_FAR_FROM, EMPTY_17X14_FAR_TO,
        EMPTY_7X7, MAZE_17X14, MAZE_17X14_FAR_FROM, MAZE_17X14_FAR_TO, MAZE_17X14_NEAR_FROM,
        MAZE_17X14_NEAR_TO, UNREACHABLE_7X7, UNREACHABLE_7X7_FAR_FROM, UNREACHABLE_7X7_FAR_TO,
    };

    // Local imports

    use super::a_star;

    // Constants

    /// Row 3 of a 7 x 7 board, x = 2..5.
    const SWAMP_7X7: felt252 = 0xf * 0x800000;
    /// Open edge tiles of a 7 x 7 board: 3 (bottom), 21 (x = 0), 27 (x = 6), 45 (top), the
    /// corner 48.
    const EDGES_7X7: [u8; 5] = [3, 21, 27, 45, 48];
    /// Open edge tiles of a 17 x 14 board: the bottom row, both sides, the top row and the
    /// corner 16.
    const EDGES_17X14: [u8; 6] = [5, 8, 16, 34, 67, 225];

    // Helpers

    /// The grid with its open edge tiles, the ring of the fixtures being all wall.
    fn open_edges(grid: felt252, edges: Span<u8>) -> felt252 {
        let mut grid = grid;
        for edge in edges {
            grid += Bits::pow(*edge);
        }
        grid
    }

    /// `a_star` from `from` to `to` against the oracle distance `expected` of the board (a
    /// `dijkstra` from `from`, `UNREACHABLE` if none): `None` exactly when an endpoint is not
    /// walkable or `to` is unreachable; otherwise a path of both ends, each step to a neighbour,
    /// that crosses no edge tile and costs `expected`.
    ///
    /// The optimum is `hexx`'s: every entry cost is at least 1, so the heuristic
    /// `unsigned_distance_to` never exceeds the cost of a step (it changes by at most 1) and is
    /// consistent, and `hexx`'s `a_star` returns a path of least total cost.
    fn check_pair(map: HexMap, from: u8, to: u8, costs: Span<felt252>, expected: u32) {
        let result = a_star(map, from, to, costs);
        if !map.is_walkable(from) || !map.is_walkable(to) {
            assert!(result.is_none(), "{} -> {}: an endpoint is a wall", from, to);
            return;
        }
        if from == to {
            assert!(result == Option::Some(array![from].span()), "{} -> {}", from, to);
            return;
        }
        if expected == UNREACHABLE {
            assert!(result.is_none(), "{} -> {}: unreachable", from, to);
            return;
        }
        let path = result.expect('path');
        assert!(*path[0] == from, "{} -> {}: the path starts at the start", from, to);
        assert!(*path[path.len() - 1] == to, "{} -> {}: the path ends at the target", from, to);
        // The board's own check wants the target first and the start excluded
        let mut backwards: Array<u8> = array![];
        let mut index = path.len() - 1;
        while index != 0 {
            backwards.append(*path[index]);
            index -= 1;
        }
        check_path(map.grid, map.width, map.height, from, to, costs, backwards.span(), expected);
    }

    /// Every ordered pair of the board.
    fn check_all_pairs(grid: felt252, width: u8, height: u8, costs: Span<felt252>) {
        let map = HexMap { width, height, grid, seed: 0 };
        let size = width * height;
        let mut from: u8 = 0;
        while from != size {
            let distances = if map.is_walkable(from) {
                dijkstra(grid, width, height, from, costs)
            } else {
                array![].span()
            };
            let mut to: u8 = 0;
            while to != size {
                let expected = if distances.is_empty() {
                    UNREACHABLE
                } else {
                    *distances[to.into()]
                };
                check_pair(map, from, to, costs, expected);
                to += 1;
            }
            from += 1;
        }
    }

    /// The listed pairs of a 17 x 14 board, with `count` random classes.
    fn check_pairs(grid: felt252, pairs: Span<(u8, u8)>, count: u32) {
        let map = HexMap { width: 17, height: 14, grid, seed: 0 };
        let costs = random_costs(grid, 17, 14, 'AST', count);
        for pair in pairs {
            let (from, to) = *pair;
            let expected = if map.is_walkable(from) {
                *dijkstra(grid, 17, 14, from, costs)[to.into()]
            } else {
                UNREACHABLE
            };
            check_pair(map, from, to, costs, expected);
        }
    }

    // Oracle: every ordered pair of 7 x 7 boards, the ring wall

    #[test]
    #[available_gas(l2_gas: 368741089)]
    fn test_a_star_empty_7x7_classes_0() {
        check_all_pairs(EMPTY_7X7, 7, 7, random_costs(EMPTY_7X7, 7, 7, 'AST', 0));
    }

    #[test]
    #[available_gas(l2_gas: 417905925)]
    fn test_a_star_empty_7x7_classes_1() {
        check_all_pairs(EMPTY_7X7, 7, 7, random_costs(EMPTY_7X7, 7, 7, 'AST', 1));
    }

    #[test]
    #[available_gas(l2_gas: 450313664)]
    fn test_a_star_empty_7x7_classes_2() {
        check_all_pairs(EMPTY_7X7, 7, 7, random_costs(EMPTY_7X7, 7, 7, 'AST', 2));
    }

    #[test]
    #[available_gas(l2_gas: 494455127)]
    fn test_a_star_empty_7x7_classes_3() {
        check_all_pairs(EMPTY_7X7, 7, 7, random_costs(EMPTY_7X7, 7, 7, 'AST', 3));
    }

    #[test]
    #[available_gas(l2_gas: 317447073)]
    fn test_a_star_cave_7x7_classes_0() {
        check_all_pairs(CAVE_7X7, 7, 7, random_costs(CAVE_7X7, 7, 7, 'AST', 0));
    }

    #[test]
    #[available_gas(l2_gas: 358325136)]
    fn test_a_star_cave_7x7_classes_1() {
        check_all_pairs(CAVE_7X7, 7, 7, random_costs(CAVE_7X7, 7, 7, 'AST', 1));
    }

    #[test]
    #[available_gas(l2_gas: 385188078)]
    fn test_a_star_cave_7x7_classes_2() {
        check_all_pairs(CAVE_7X7, 7, 7, random_costs(CAVE_7X7, 7, 7, 'AST', 2));
    }

    #[test]
    #[available_gas(l2_gas: 422099447)]
    fn test_a_star_cave_7x7_classes_3() {
        check_all_pairs(CAVE_7X7, 7, 7, random_costs(CAVE_7X7, 7, 7, 'AST', 3));
    }

    /// A board with unreachable tiles: `None` exactly for them.
    #[test]
    #[available_gas(l2_gas: 191444178)]
    fn test_a_star_unreachable_7x7() {
        check_all_pairs(UNREACHABLE_7X7, 7, 7, random_costs(UNREACHABLE_7X7, 7, 7, 'AST', 1));
    }

    /// Open edge tiles are endpoints, never crossed.
    #[test]
    #[available_gas(l2_gas: 653298404)]
    fn test_a_star_empty_7x7_edges_classes_2() {
        let grid = open_edges(EMPTY_7X7, EDGES_7X7.span());
        check_all_pairs(grid, 7, 7, random_costs(grid, 7, 7, 'AST', 2));
    }

    #[test]
    #[available_gas(l2_gas: 441554477)]
    fn test_a_star_cave_7x7_edges_classes_0() {
        let grid = open_edges(CAVE_7X7, EDGES_7X7.span());
        check_all_pairs(grid, 7, 7, random_costs(grid, 7, 7, 'AST', 0));
    }

    // Oracle: the far and near pairs of the 17 x 14 fixtures, both ways, with a wall and the
    // start as the target

    #[test]
    #[available_gas(l2_gas: 248838958)]
    fn test_a_star_empty_17x14_classes_2() {
        let pairs = array![
            (EMPTY_17X14_FAR_FROM, EMPTY_17X14_FAR_TO), (EMPTY_17X14_FAR_TO, EMPTY_17X14_FAR_FROM),
            (EMPTY_17X14_FAR_FROM, EMPTY_17X14_FAR_FROM), (EMPTY_17X14_FAR_FROM, 0), (0, 110),
        ];
        check_pairs(EMPTY_17X14, pairs.span(), 2);
    }

    #[test]
    #[available_gas(l2_gas: 188338687)]
    fn test_a_star_cave_17x14_classes_0() {
        check_pairs(CAVE_17X14, cave_pairs(), 0);
    }

    #[test]
    #[available_gas(l2_gas: 206979284)]
    fn test_a_star_cave_17x14_classes_1() {
        check_pairs(CAVE_17X14, cave_pairs(), 1);
    }

    #[test]
    #[available_gas(l2_gas: 230122193)]
    fn test_a_star_cave_17x14_classes_2() {
        check_pairs(CAVE_17X14, cave_pairs(), 2);
    }

    #[test]
    #[available_gas(l2_gas: 254908164)]
    fn test_a_star_cave_17x14_classes_3() {
        check_pairs(CAVE_17X14, cave_pairs(), 3);
    }

    #[test]
    #[available_gas(l2_gas: 109434408)]
    fn test_a_star_maze_17x14_classes_0() {
        check_pairs(MAZE_17X14, maze_pairs(), 0);
    }

    #[test]
    #[available_gas(l2_gas: 117012528)]
    fn test_a_star_maze_17x14_classes_1() {
        check_pairs(MAZE_17X14, maze_pairs(), 1);
    }

    #[test]
    #[available_gas(l2_gas: 124237221)]
    fn test_a_star_maze_17x14_classes_2() {
        check_pairs(MAZE_17X14, maze_pairs(), 2);
    }

    #[test]
    #[available_gas(l2_gas: 131477836)]
    fn test_a_star_maze_17x14_classes_3() {
        check_pairs(MAZE_17X14, maze_pairs(), 3);
    }

    // Oracle: the 17 x 14 fixtures with open edge tiles as endpoints (5, 16 the corner, 34, 67,
    // 225), edge to edge, edge to interior and back

    #[test]
    #[available_gas(l2_gas: 240705913)]
    fn test_a_star_cave_17x14_edges_classes_2() {
        let grid = open_edges(CAVE_17X14, EDGES_17X14.span());
        check_pairs(grid, edge_pairs(CAVE_17X14_FAR_FROM, CAVE_17X14_FAR_TO), 2);
    }

    #[test]
    #[available_gas(l2_gas: 166670047)]
    fn test_a_star_maze_17x14_edges_classes_1() {
        let grid = open_edges(MAZE_17X14, EDGES_17X14.span());
        check_pairs(grid, edge_pairs(MAZE_17X14_FAR_FROM, MAZE_17X14_FAR_TO), 1);
    }

    #[test]
    #[available_gas(l2_gas: 189321358)]
    fn test_a_star_maze_17x14_edges_classes_3() {
        let grid = open_edges(MAZE_17X14, EDGES_17X14.span());
        check_pairs(grid, edge_pairs(MAZE_17X14_FAR_FROM, MAZE_17X14_FAR_TO), 3);
    }

    fn cave_pairs() -> Span<(u8, u8)> {
        array![
            (CAVE_17X14_FAR_FROM, CAVE_17X14_FAR_TO), (CAVE_17X14_FAR_TO, CAVE_17X14_FAR_FROM),
            (CAVE_17X14_NEAR_FROM, CAVE_17X14_NEAR_TO), (CAVE_17X14_NEAR_TO, CAVE_17X14_NEAR_FROM),
            (CAVE_17X14_FAR_FROM, CAVE_17X14_FAR_FROM), (CAVE_17X14_FAR_FROM, 0), (17, 52),
        ]
            .span()
    }

    fn maze_pairs() -> Span<(u8, u8)> {
        array![
            (MAZE_17X14_FAR_FROM, MAZE_17X14_FAR_TO), (MAZE_17X14_FAR_TO, MAZE_17X14_FAR_FROM),
            (MAZE_17X14_NEAR_FROM, MAZE_17X14_NEAR_TO), (MAZE_17X14_NEAR_TO, MAZE_17X14_NEAR_FROM),
            (MAZE_17X14_FAR_FROM, MAZE_17X14_FAR_FROM), (MAZE_17X14_FAR_FROM, 0), (17, 149),
        ]
            .span()
    }

    fn edge_pairs(far_from: u8, far_to: u8) -> Span<(u8, u8)> {
        array![
            (5, far_to), (far_from, 5), (5, 225), (16, 34), (67, 5), (225, 16), (5, 5), (5, 0),
            (0, 5),
        ]
            .span()
    }

    // The contract

    #[test]
    #[available_gas(l2_gas: 215801)]
    fn test_a_star_path_both_ends() {
        //  0 0 0 0 0 0 0
        // 0 S 1 1 1 1 0
        //  0 * 1 1 1 1 0
        // 0 1 * 1 1 1 0
        //  0 1 * 1 1 1 0
        // 0 1 1 * * E 0
        //  0 0 0 0 0 0 0
        let map = HexMap { width: 7, height: 7, grid: EMPTY_7X7, seed: 0 };
        let path = a_star(map, 40, 8, array![].span()).expect('path');
        assert!(path == array![40, 33, 25, 18, 10, 9, 8].span());
    }

    #[test]
    #[available_gas(l2_gas: 353033)]
    fn test_a_star_detour() {
        // Cost 4 on x = 2..5 of row 3: 7 tiles of cost 1 instead of 6 tiles of cost 9
        let map = HexMap { width: 7, height: 7, grid: EMPTY_7X7, seed: 0 };
        let costs = array![0, 0, SWAMP_7X7].span();
        let path = a_star(map, 40, 8, costs).expect('path');
        assert!(path == array![40, 33, 32, 31, 30, 22, 15, 8].span());
    }

    #[test]
    #[available_gas(l2_gas: 108290)]
    fn test_a_star_start_is_target() {
        let map = HexMap { width: 7, height: 7, grid: EMPTY_7X7, seed: 0 };
        let path = a_star(map, 24, 24, array![SWAMP_7X7].span()).expect('path');
        assert!(path == array![24].span());
        // Adjacent: both ends, whatever the cost of the target
        let path = a_star(map, 31, 24, array![0, 0, SWAMP_7X7].span()).expect('path');
        assert!(path == array![31, 24].span());
    }

    #[test]
    #[available_gas(l2_gas: 34449)]
    fn test_a_star_endpoint_not_walkable_or_outside_is_none() {
        let map = HexMap { width: 7, height: 7, grid: EMPTY_7X7, seed: 0 };
        let costs = array![SWAMP_7X7].span();
        // A wall: the start, the target, both (a wall to itself)
        assert!(a_star(map, 0, 24, costs).is_none());
        assert!(a_star(map, 24, 0, costs).is_none());
        assert!(a_star(map, 0, 0, costs).is_none());
        // Outside the board: no panic
        assert!(a_star(map, 49, 24, costs).is_none());
        assert!(a_star(map, 24, 49, costs).is_none());
        assert!(a_star(map, 255, 255, costs).is_none());
    }

    #[test]
    #[available_gas(l2_gas: 103324)]
    fn test_a_star_unreachable_is_none() {
        let map = HexMap { width: 7, height: 7, grid: UNREACHABLE_7X7, seed: 0 };
        let costs = array![].span();
        assert!(a_star(map, UNREACHABLE_7X7_FAR_FROM, UNREACHABLE_7X7_FAR_TO, costs).is_none());
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Dial: too many costs')]
    fn test_a_star_revert_too_many_costs() {
        let map = HexMap { width: 7, height: 7, grid: EMPTY_7X7, seed: 0 };
        a_star(map, 40, 8, array![0, 0, 0, 0].span());
    }

    /// More than 3 classes panic even when the answer would be `None` (a wall).
    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Dial: too many costs')]
    fn test_a_star_revert_too_many_costs_wall() {
        let map = HexMap { width: 7, height: 7, grid: EMPTY_7X7, seed: 0 };
        a_star(map, 0, 8, array![0, 0, 0, 0].span());
    }

    // Bench (AGENTS.md: L = the engine's `bench_dial_cave_17x14` 1,399,134 + 2,100 for the call by
    // value + 7,358 per element of the span built by a loop, 26 for the path of n = 25 tiles
    // measured: L = 1,592,542, U = ceil(1.25 L) = 1,990,678)

    #[test]
    #[available_gas(l2_gas: 1543595)]
    fn bench_a_star_cave_17x14_far_classes_2() {
        let map = HexMap { width: 17, height: 14, grid: CAVE_17X14, seed: 0 };
        let costs = array![CAVE_17X14_COST_2, CAVE_17X14_COST_3].span();
        a_star(map, CAVE_17X14_FAR_FROM, CAVE_17X14_FAR_TO, costs);
    }
}
