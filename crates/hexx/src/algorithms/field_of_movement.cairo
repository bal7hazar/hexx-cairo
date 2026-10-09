//! `algorithms::field_of_movement`: the counterpart of `hexx`'s `field_of_movement`
//! (`src/algorithms/field_of_movement.rs`) on a `HexMap`.

// Internal imports

use crate::board::asserter::Asserter;
use crate::board::bits::Bits;
use crate::board::map::{HexMap, HexMapTrait};

/// Every tile reachable from `from` with a total entry cost of at most `budget`, as a bitmap
/// of the board, `from` included.
///
/// A free function, by decision of the brief of M3-T1: it mirrors the free function of `hexx`
/// (`hexx::algorithms::field_of_movement`), and the mirror keeps `hexx`'s names (principle 8), as
/// `shapes` does. It forwards to `HexMapTrait::field_of_movement`: the extension is the
/// implementation (plan §2.4), this function the counterpart.
///
/// `costs[k]` is the bitmap of the tiles of the class `k`. The closure of `hexx` is, for a tile
/// `h`: `None` if `h` is off the board or a wall, `Some(k + 1)` if `h` is in the class `k` (the
/// highest class wins), `Some(0)` for any other walkable tile; `hexx` pays `1 + cost(h)` on
/// entering `h` (`field_of_movement.rs:90`), which is the board's entry cost `k + 2`, or 1.
///
/// Mirrors `hexx::algorithms::field_of_movement` (`src/algorithms/field_of_movement.rs:63`).
///
/// #### Panics
///
/// * If `from` is outside the board (`'Asserter: position not inside'`, no counterpart in
/// `hexx`).
/// * If there are more than 3 cost classes (`'Dial: too many costs'`).
///
/// #### Deviations
///
/// * The path is `hexx::algorithms::field_of_movement::field_of_movement`, not
/// `hexx::algorithms::field_of_movement`: Cairo does not let the module and the function of one
/// name share `algorithms` (E2118), as for `hexx::hex::hex`. The module keeps the name of the
/// source file of `hexx`.
/// * `budget` is a `u8`, `hexx`'s a `u32`.
/// * Per-tile entry costs only, no directed `cost(a, b)`: `hexx`'s closure takes one tile.
/// * At most 3 classes, so entry costs 1 to 4, against any `u32` cost.
/// * On a board whose open edge tiles are not all wall, an open edge tile is reached and never
/// crossed (the board's rule, `Dial`): the field stops there. `hexx` has no board, and crosses
/// every tile that `cost` accepts.
/// * `from` is in the field even when it is a wall, and the field expands from it, as `hexx`
/// never pays the cost of the start (`field_of_movement.rs:69`). The caller's map is unchanged.
/// * The result is a bitmap of tile indices, `hexx`'s a `HashSet<Hex>`.
pub fn field_of_movement(map: HexMap, from: u8, budget: u8, costs: Span<felt252>) -> felt252 {
    Asserter::assert_inside(map.width, map.height, from);
    // `hexx` never pays the cost of the start: open it in a copy, when it is a wall
    let mut start = map;
    if !map.is_walkable(from) {
        start.grid += Bits::pow(from);
    }
    HexMapTrait::field_of_movement(start, from, budget, costs)
}

#[cfg(test)]
mod tests {
    // Internal imports

    use crate::board::asserter::errors;
    use crate::board::bits::Bits;
    use crate::board::map::HexMap;
    use crate::tests::bench_dial::{
        CAVE_17X14_COST_2, CAVE_17X14_COST_3, dijkstra, field_oracle, random_costs,
    };
    use crate::tests::fixtures::{
        CAVE_17X14, CAVE_17X14_FAR_FROM, CAVE_17X14_NEAR_FROM, EMPTY_17X14, EMPTY_7X7, MAZE_17X14,
        MAZE_17X14_FAR_FROM, MAZE_17X14_NEAR_FROM,
    };

    // Local imports

    use super::field_of_movement;

    // Constants

    /// Open edge tiles of a 7 x 7 board: 3 (bottom), 21 (x = 0), 27 (x = 6), 45 (top), the
    /// corner 48.
    const EDGES_7X7: [u8; 5] = [3, 21, 27, 45, 48];
    /// Open edge tiles of a 17 x 14 board: the bottom row, both sides, the top row and the
    /// corner 16.
    const EDGES_17X14: [u8; 6] = [5, 8, 16, 34, 67, 225];

    // Helpers

    /// The budgets of the oracle: the small ones, and the whole board.
    fn budgets() -> Span<u8> {
        array![0, 1, 2, 3, 4, 5, 6, 7, 8, 255].span()
    }

    /// The grid with its open edge tiles, the ring of the fixtures being all wall.
    fn open_edges(grid: felt252, edges: Span<u8>) -> felt252 {
        let mut grid = grid;
        for edge in edges {
            grid += Bits::pow(*edge);
        }
        grid
    }

    /// `field_of_movement` from one start against the Dijkstra of the board on every budget of
    /// `budgets`, `hexx` never paying the cost of the start: the oracle opens it.
    fn check_start(grid: felt252, width: u8, height: u8, from: u8, costs: Span<felt252>) {
        let map = HexMap { width, height, grid, seed: 0 };
        let open: u256 = grid.into();
        let oracle = if Bits::get(open, from) {
            grid
        } else {
            grid + Bits::pow(from)
        };
        let distances = dijkstra(oracle, width, height, from, costs);
        for budget in budgets() {
            let field = field_of_movement(map, from, *budget, costs);
            assert!(field == field_oracle(distances, *budget), "from {} budget {}", from, *budget);
            assert!(Bits::get(field.into(), from), "from {} is in the field", from);
        }
        // The caller's map is unchanged
        assert!(map.grid == grid);
    }

    /// Every start of the board.
    fn check_all_starts(grid: felt252, width: u8, height: u8, costs: Span<felt252>) {
        let mut from: u8 = 0;
        while from != width * height {
            check_start(grid, width, height, from, costs);
            from += 1;
        }
    }

    /// The oracle of a 7 x 7 board with `count` random classes, on every start.
    fn check_7x7(grid: felt252, count: u32) {
        let costs = random_costs(grid, 7, 7, 'FOM', count);
        if count != 0 {
            assert!(*costs[0] != 0, "the first class is empty");
        }
        check_all_starts(grid, 7, 7, costs);
    }

    /// The oracle of a 17 x 14 board with `count` random classes, on four starts: the far and
    /// the near start of the fixture, then `first` and `second` (walls, or open edge tiles).
    fn check_17x14(grid: felt252, far: u8, near: u8, first: u8, second: u8, count: u32) {
        let costs = random_costs(grid, 17, 14, 'FOM', count);
        check_start(grid, 17, 14, far, costs);
        check_start(grid, 17, 14, near, costs);
        check_start(grid, 17, 14, first, costs);
        check_start(grid, 17, 14, second, costs);
    }

    // Oracle: EMPTY_7X7, every start, the ring wall

    #[test]
    #[available_gas(l2_gas: 414927373)]
    fn test_field_of_movement_empty_7x7_classes_0() {
        check_7x7(EMPTY_7X7, 0);
    }

    #[test]
    #[available_gas(l2_gas: 454776204)]
    fn test_field_of_movement_empty_7x7_classes_1() {
        check_7x7(EMPTY_7X7, 1);
    }

    #[test]
    #[available_gas(l2_gas: 483264831)]
    fn test_field_of_movement_empty_7x7_classes_2() {
        check_7x7(EMPTY_7X7, 2);
    }

    #[test]
    #[available_gas(l2_gas: 510877676)]
    fn test_field_of_movement_empty_7x7_classes_3() {
        check_7x7(EMPTY_7X7, 3);
    }

    // Oracle: EMPTY_7X7, every start, open edge tiles (reached, never crossed)

    #[test]
    #[available_gas(l2_gas: 442365234)]
    fn test_field_of_movement_empty_7x7_edges_classes_0() {
        check_7x7(open_edges(EMPTY_7X7, EDGES_7X7.span()), 0);
    }

    #[test]
    #[available_gas(l2_gas: 546655834)]
    fn test_field_of_movement_empty_7x7_edges_classes_3() {
        check_7x7(open_edges(EMPTY_7X7, EDGES_7X7.span()), 3);
    }

    // Oracle: the 17 x 14 fixtures, the ring wall: far and near starts, and two wall starts
    // (the corner 0, the ring tile 17)

    #[test]
    #[available_gas(l2_gas: 106131353)]
    fn test_field_of_movement_cave_17x14_classes_0() {
        check_17x14(CAVE_17X14, CAVE_17X14_FAR_FROM, CAVE_17X14_NEAR_FROM, 0, 17, 0);
    }

    #[test]
    #[available_gas(l2_gas: 114617569)]
    fn test_field_of_movement_cave_17x14_classes_1() {
        check_17x14(CAVE_17X14, CAVE_17X14_FAR_FROM, CAVE_17X14_NEAR_FROM, 0, 17, 1);
    }

    #[test]
    #[available_gas(l2_gas: 123576301)]
    fn test_field_of_movement_cave_17x14_classes_2() {
        check_17x14(CAVE_17X14, CAVE_17X14_FAR_FROM, CAVE_17X14_NEAR_FROM, 0, 17, 2);
    }

    #[test]
    #[available_gas(l2_gas: 134229503)]
    fn test_field_of_movement_cave_17x14_classes_3() {
        check_17x14(CAVE_17X14, CAVE_17X14_FAR_FROM, CAVE_17X14_NEAR_FROM, 0, 17, 3);
    }

    #[test]
    #[available_gas(l2_gas: 95351501)]
    fn test_field_of_movement_maze_17x14_classes_0() {
        check_17x14(MAZE_17X14, MAZE_17X14_FAR_FROM, MAZE_17X14_NEAR_FROM, 0, 17, 0);
    }

    #[test]
    #[available_gas(l2_gas: 101349535)]
    fn test_field_of_movement_maze_17x14_classes_1() {
        check_17x14(MAZE_17X14, MAZE_17X14_FAR_FROM, MAZE_17X14_NEAR_FROM, 0, 17, 1);
    }

    #[test]
    #[available_gas(l2_gas: 104981049)]
    fn test_field_of_movement_maze_17x14_classes_2() {
        check_17x14(MAZE_17X14, MAZE_17X14_FAR_FROM, MAZE_17X14_NEAR_FROM, 0, 17, 2);
    }

    #[test]
    #[available_gas(l2_gas: 107239209)]
    fn test_field_of_movement_maze_17x14_classes_3() {
        check_17x14(MAZE_17X14, MAZE_17X14_FAR_FROM, MAZE_17X14_NEAR_FROM, 0, 17, 3);
    }

    // Oracle: the 17 x 14 fixtures with open edge tiles: starts on an open edge tile (5), on the
    // open corner (16), and on a wall (0, 17)

    #[test]
    #[available_gas(l2_gas: 108585250)]
    fn test_field_of_movement_cave_17x14_edges_classes_0() {
        let grid = open_edges(CAVE_17X14, EDGES_17X14.span());
        check_17x14(grid, CAVE_17X14_FAR_FROM, 5, 16, 17, 0);
    }

    #[test]
    #[available_gas(l2_gas: 125065831)]
    fn test_field_of_movement_cave_17x14_edges_classes_2() {
        let grid = open_edges(CAVE_17X14, EDGES_17X14.span());
        check_17x14(grid, CAVE_17X14_FAR_FROM, 5, 16, 17, 2);
    }

    #[test]
    #[available_gas(l2_gas: 103814696)]
    fn test_field_of_movement_maze_17x14_edges_classes_1() {
        let grid = open_edges(MAZE_17X14, EDGES_17X14.span());
        check_17x14(grid, MAZE_17X14_FAR_FROM, 5, 16, 0, 1);
    }

    #[test]
    #[available_gas(l2_gas: 110448151)]
    fn test_field_of_movement_maze_17x14_edges_classes_3() {
        let grid = open_edges(MAZE_17X14, EDGES_17X14.span());
        check_17x14(grid, MAZE_17X14_FAR_FROM, 5, 16, 0, 3);
    }

    // The contract

    #[test]
    #[available_gas(l2_gas: 142772)]
    fn test_field_of_movement_from_a_wall() {
        // 7 is a wall of the ring, next to the open 8 (east) and 15 (south-east): `hexx` never
        // pays the cost of the start, so the field expands from it
        let map = HexMap { width: 7, height: 7, grid: EMPTY_7X7, seed: 0 };
        let field = field_of_movement(map, 7, 1, array![].span());
        assert!(field == Bits::pow(7) + Bits::pow(8) + Bits::pow(15));
        // With a budget of 0 the field is the start alone, a wall or not
        assert!(field_of_movement(map, 7, 0, array![].span()) == Bits::pow(7));
        assert!(field_of_movement(map, 24, 0, array![].span()) == Bits::pow(24));
        // The map of the caller is unchanged
        assert!(map.grid == EMPTY_7X7);
    }

    #[test]
    #[available_gas(l2_gas: 164586)]
    fn test_field_of_movement_costs_map_to_entry_costs() {
        // Class 0 is `cost(h) = 1`, which `hexx` charges as `1 + 1`: the tile 25 (class 0) costs
        // 2, so a budget of 1 reaches the other neighbours of 24 and not it, a budget of 2 does
        let map = HexMap { width: 7, height: 7, grid: EMPTY_7X7, seed: 0 };
        let costs = array![Bits::pow(25)].span();
        let near = field_of_movement(map, 24, 1, costs);
        assert!(!Bits::get(near.into(), 25));
        assert!(Bits::get(near.into(), 23));
        let far = field_of_movement(map, 24, 2, costs);
        assert!(Bits::get(far.into(), 25));
    }

    #[test]
    #[available_gas(l2_gas: 8201)]
    #[should_panic(expected: 'Asserter: position not inside')]
    fn test_field_of_movement_revert_outside() {
        let map = HexMap { width: 7, height: 7, grid: EMPTY_7X7, seed: 0 };
        assert!(errors::ASSERTER_POSITION_NOT_INSIDE == 'Asserter: position not inside');
        field_of_movement(map, 49, 3, array![].span());
    }

    #[test]
    #[available_gas(l2_gas: 14326)]
    #[should_panic(expected: 'Dial: too many costs')]
    fn test_field_of_movement_revert_too_many_costs() {
        let map = HexMap { width: 7, height: 7, grid: EMPTY_7X7, seed: 0 };
        field_of_movement(map, 24, 3, array![0, 0, 0, 0].span());
    }

    // Benches (L = the engine's `bench_dial_field_*` + 2,100 for the call by value, U = ceil(1.25
    // L), AGENTS.md): L = 321,385 and U = 401,732 for the cave, L = 234,317 and U = 292,897 for
    // the empty board

    #[test]
    #[available_gas(l2_gas: 340597)]
    fn bench_field_of_movement_cave_17x14_budget_8() {
        let map = HexMap { width: 17, height: 14, grid: CAVE_17X14, seed: 0 };
        let costs = array![CAVE_17X14_COST_2, CAVE_17X14_COST_3].span();
        field_of_movement(map, CAVE_17X14_FAR_FROM, 8, costs);
    }

    #[test]
    #[available_gas(l2_gas: 249176)]
    fn bench_field_of_movement_empty_17x14_budget_8() {
        let map = HexMap { width: 17, height: 14, grid: EMPTY_17X14, seed: 0 };
        field_of_movement(map, 110, 8, array![].span());
    }
}
