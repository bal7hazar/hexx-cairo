//! `algorithms`: `field_of_movement` (`src/algorithms/field_of_movement.rs:63`) and `a_star`
//! (`src/algorithms/pathfinding.rs:110`) of `hexx` 0.25.0, run with the closures of the board.
//!
//! The boards are in the board frame (plan §3.5, `line::to_hex` / `from_hex`) with a closed ring
//! (every edge tile a wall): empty, and two seeded caves, at 7 × 7 and 15 × 16. A class count `c`
//! uses the first `c` of three seeded class bitmaps; the highest class of a tile wins.
//!
//! - `field_of_movement`: `cost(h) = None` off the board or on a wall, `Some(k + 1)` in the class
//!   `k`, `Some(0)` elsewhere, so that `hexx`'s entry cost `1 + cost(h)` is the board's `k + 2`,
//!   or 1.
//! - `a_star`: `cost(_, b) = None` off the board, on a wall or on an edge tile other than the
//!   target, else the board's entry cost, `hexx` adding it as given.
//!
//! Every result of `hexx` is first checked against the board's own Dijkstra (`oracle`) and a
//! divergence stops the generator. A test then holds, per board, the digest of the nine fields
//! (budgets `0..=budget_max`) from each start, and, per pair, the total cost of `hexx`'s path
//! (0 for `None`, cost + 1 otherwise): the path itself is not compared, `hexx`'s heap order and the
//! board's lowest-index rule differ at ties.

use std::collections::HashSet;
use std::path::{Path, PathBuf};

use hexx::algorithms::{a_star, field_of_movement};
use hexx::Hex;

use crate::cairo::{cases_array, Emitter, Rng};
use crate::line::{felt, from_hex, to_hex};
use crate::spec::Spec;

const CLASSES: usize = 3;

struct Board {
    name: String,
    width: i64,
    height: i64,
    open: Vec<bool>,
    classes: Vec<Vec<bool>>,
}

impl Board {
    fn size(&self) -> usize {
        (self.width * self.height) as usize
    }

    fn is_edge(&self, tile: usize) -> bool {
        let (x, y) = (tile as i64 % self.width, tile as i64 / self.width);
        x == 0 || y == 0 || x == self.width - 1 || y == self.height - 1
    }

    /// The tile of a `Hex`, `None` off the board.
    fn tile(&self, hex: Hex) -> Option<usize> {
        let (x, y) = from_hex((hex.x.into(), hex.y.into()));
        if x < 0 || y < 0 || x >= self.width || y >= self.height {
            None
        } else {
            Some((y * self.width + x) as usize)
        }
    }

    fn hex(&self, tile: usize) -> Hex {
        let (x, y) = to_hex((tile as i64 % self.width, tile as i64 / self.width));
        Hex::new(x as i32, y as i32)
    }

    /// The highest of the first `count` classes holding the tile.
    fn class(&self, tile: usize, count: usize) -> Option<usize> {
        (0..count).rev().find(|&k| self.classes[k][tile])
    }

    /// The board's entry cost: 1, or `k + 2` for the class `k`.
    fn entry_cost(&self, tile: usize, count: usize) -> u32 {
        self.class(tile, count).map_or(1, |k| k as u32 + 2)
    }

    /// The bitmap of a set of tiles as four little-endian words.
    fn words(&self, tiles: impl Iterator<Item = usize>) -> [u64; 4] {
        let mut words = [0u64; 4];
        for tile in tiles {
            words[tile / 64] |= 1 << (tile % 64);
        }
        words
    }

    /// The board's Dijkstra from `from` (the start is never charged, whatever it is; an edge tile
    /// is reached and never crossed, unless it is the start): the cheapest entry cost of every
    /// tile, `None` if unreachable.
    fn oracle(&self, from: usize, count: usize) -> Vec<Option<u32>> {
        let mut dist: Vec<Option<u32>> = vec![None; self.size()];
        let mut settled = vec![false; self.size()];
        dist[from] = Some(0);
        loop {
            let next = (0..self.size())
                .filter(|&t| !settled[t] && dist[t].is_some())
                .min_by_key(|&t| (dist[t], t));
            let Some(tile) = next else { break };
            settled[tile] = true;
            if tile != from && self.is_edge(tile) {
                continue;
            }
            let here = dist[tile].unwrap();
            for neighbor in self.hex(tile).all_neighbors() {
                let Some(n) = self.tile(neighbor) else {
                    continue;
                };
                if !self.open[n] || settled[n] {
                    continue;
                }
                let candidate = here + self.entry_cost(n, count);
                if dist[n].map_or(true, |d| candidate < d) {
                    dist[n] = Some(candidate);
                }
            }
        }
        dist
    }

    /// `hexx`'s `field_of_movement`, the start opened in the board's sense (`hexx` never pays it).
    fn field(&self, from: usize, budget: u32, count: usize) -> HashSet<usize> {
        let set = field_of_movement(self.hex(from), budget, |h| {
            let tile = self.tile(h)?;
            if !self.open[tile] {
                return None;
            }
            Some(self.class(tile, count).map_or(0, |k| k as u32 + 1))
        });
        set.into_iter()
            .map(|h| self.tile(h).expect("a field tile is on the board"))
            .collect()
    }

    /// The total entry cost of `hexx`'s `a_star`, `None` if it finds no path.
    fn path_cost(&self, from: usize, to: usize, count: usize) -> Option<u32> {
        let end = self.hex(to);
        let path = a_star(self.hex(from), end, |_, b| {
            let tile = self.tile(b)?;
            if !self.open[tile] || (self.is_edge(tile) && b != end) {
                return None;
            }
            Some(self.entry_cost(tile, count))
        })?;
        let mut tiles: Vec<usize> = path.iter().map(|&h| self.tile(h).unwrap()).collect();
        assert_eq!(tiles.first(), Some(&from));
        assert_eq!(tiles.last(), Some(&to));
        tiles.remove(0);
        Some(tiles.iter().map(|&t| self.entry_cost(t, count)).sum())
    }
}

/// FNV-1a over `u64` words folded with their high half, as `DigestTrait` of the generated file.
struct Digest(u64);

impl Digest {
    fn new() -> Self {
        Digest(0xcbf29ce484222325)
    }

    fn fold(&mut self, value: u64) {
        let d = (self.0 ^ value).wrapping_mul(0x100000001b3);
        self.0 = d ^ (d >> 32);
    }

    fn bitmap(&mut self, words: [u64; 4]) {
        for word in words {
            self.fold(word);
        }
    }
}

/// The felt of a bitmap of words.
fn bitmap_felt(words: [u64; 4]) -> String {
    let low = u128::from(words[0]) | (u128::from(words[1]) << 64);
    let high = u128::from(words[2]) | (u128::from(words[3]) << 64);
    felt((high, low))
}

fn boards(rng: &mut Rng) -> Vec<Board> {
    let mut all = Vec::new();
    for (width, height) in [(7i64, 7i64), (15, 16)] {
        for (kind, name) in [(0, "empty"), (1, "cave_a"), (2, "cave_b")] {
            let size = (width * height) as usize;
            let mut board = Board {
                name: format!("{name}_{width}x{height}"),
                width,
                height,
                open: vec![false; size],
                classes: Vec::new(),
            };
            for tile in 0..size {
                let interior = !board.is_edge(tile);
                board.open[tile] = interior && (kind == 0 || rng.next_i32(0, 2) != 0);
            }
            for _ in 0..CLASSES {
                let class = (0..size)
                    .map(|t| board.open[t] && rng.next_i32(0, 3) == 0)
                    .collect();
                board.classes.push(class);
            }
            all.push(board);
        }
    }
    all
}

/// The starts of a board: seeded open tiles, then a wall of the ring next to the interior.
fn starts(board: &Board, rng: &mut Rng, count: usize) -> Vec<usize> {
    let open: Vec<usize> = (0..board.size()).filter(|&t| board.open[t]).collect();
    let mut all: Vec<usize> = (0..count - 2)
        .map(|_| open[rng.next_i32(0, open.len() as i32 - 1) as usize])
        .collect();
    all.push(board.width as usize);
    all.push((board.width * (board.height - 2) + board.width - 1) as usize);
    all
}

fn field_rows(board: &Board, rng: &mut Rng, spec: &Spec) -> Result<Vec<String>, String> {
    let budget_max = spec.int("budget_max")? as u32;
    let mut rows = Vec::new();
    for from in starts(board, rng, spec.int("starts")? as usize) {
        for count in 0..=CLASSES {
            let oracle = board.oracle(from, count);
            let mut digest = Digest::new();
            for budget in 0..=budget_max {
                let field = board.field(from, budget, count);
                let expected: HashSet<usize> = (0..board.size())
                    .filter(|&t| oracle[t].is_some_and(|d| d <= budget))
                    .collect();
                if field != expected {
                    return Err(format!(
                        "{}: field_of_movement from {from} budget {budget} classes {count}: hexx \
                         and the board differ",
                        board.name
                    ));
                }
                digest.bitmap(board.words(field.into_iter()));
            }
            rows.push(format!("{count}, {from}, {:#x}", digest.0));
        }
    }
    Ok(rows)
}

fn star_rows(board: &Board, rng: &mut Rng, spec: &Spec) -> Result<Vec<String>, String> {
    let mut rows = Vec::new();
    let size = board.size() as i32;
    for count in 0..=CLASSES {
        for _ in 0..spec.int("pairs")? {
            let (from, to) = (
                rng.next_i32(0, size - 1) as usize,
                rng.next_i32(0, size - 1) as usize,
            );
            let got = board.path_cost(from, to, count);
            let expected = if board.open[from] && board.open[to] {
                board.oracle(from, count)[to]
            } else {
                None
            };
            if got != expected {
                return Err(format!(
                    "{}: a_star {from} -> {to} classes {count}: hexx {got:?}, the board {expected:?}",
                    board.name
                ));
            }
            rows.push(format!(
                "{count}, {from}, {to}, {}",
                got.map_or(0, |c| c + 1)
            ));
        }
    }
    Ok(rows)
}

fn header(board: &Board) -> String {
    let words = board.words((0..board.size()).filter(|&t| board.open[t]));
    let classes: Vec<String> = board
        .classes
        .iter()
        .map(|c| bitmap_felt(board.words((0..board.size()).filter(|&t| c[t]))))
        .collect();
    let grid = bitmap_felt(words);
    let (width, height) = (board.width, board.height);
    // As `scarb fmt` lays them out: on one line when they fit in 100 columns
    let map_line = format!(
        "    let map = HexMap {{ width: {width}, height: {height}, grid: {grid}, seed: 0 }};\n"
    );
    let map = if map_line.len() <= 101 {
        map_line
    } else {
        format!(
            "    let map = HexMap {{\n        width: {width},\n        height: {height},\n        grid: {grid},\n        seed: 0,\n    }};\n"
        )
    };
    let line = format!(
        "    let classes: Array<felt252> = array![{}];\n",
        classes.join(", ")
    );
    let classes = if line.len() <= 101 {
        line
    } else {
        let items: String = classes.iter().map(|c| format!("        {c},\n")).collect();
        format!("    let classes: Array<felt252> = array![\n{items}    ];\n")
    };
    format!("{map}{classes}")
}

const USES: &str = "use core::num::traits::WrappingMul;
use hexx::algorithms::a_star;
use hexx::algorithms::field_of_movement::field_of_movement;
use hexx::board::bits::Bits;
use hexx::board::map::{HexMap, HexMapTrait};

/// The digest of `tools/refgen/src/algorithms.rs` (`Digest`): FNV-1a over `u64` words folded with
/// their high half, the four words of a bitmap in turn.
#[generate_trait]
impl DigestImpl of DigestTrait {
    fn fold(digest: u64, value: u64) -> u64 {
        let d = (digest ^ value).wrapping_mul(0x100000001b3);
        d ^ (d / 0x100000000)
    }

    fn bitmap(digest: u64, value: felt252) -> u64 {
        let value: u256 = value.into();
        let word: u128 = 0x10000000000000000;
        let digest = Self::fold(digest, (value.low % word).try_into().unwrap());
        let digest = Self::fold(digest, (value.low / word).try_into().unwrap());
        let digest = Self::fold(digest, (value.high % word).try_into().unwrap());
        Self::fold(digest, (value.high / word).try_into().unwrap())
    }
}

/// The checks of a path of `a_star`.
#[generate_trait]
impl PathImpl of PathTrait {
    /// The entry cost of a tile: 1, or `k + 2` for the highest class `k` holding it.
    fn entry_cost(costs: Span<felt252>, tile: u8) -> u32 {
        let mut cost: u32 = 1;
        let mut k: u32 = 0;
        while k != costs.len() {
            if Bits::get((*costs[k]).into(), tile) {
                cost = k + 2;
            }
            k += 1;
        }
        cost
    }

    /// The total entry cost of a path, which must run from `from` to `to` through walkable
    /// neighbours.
    fn cost(map: HexMap, costs: Span<felt252>, from: u8, to: u8, path: Span<u8>) -> u32 {
        assert(*path[0] == from, 'path start');
        assert(*path[path.len() - 1] == to, 'path end');
        let mut total: u32 = 0;
        let mut index: u32 = 1;
        while index != path.len() {
            assert(map.is_walkable(*path[index]), 'path wall');
            assert(map.hex_distance(*path[index - 1], *path[index]) == 1, 'path step');
            total += Self::entry_cost(costs, *path[index]);
            index += 1;
        }
        total
    }
}
";

pub fn emit(spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    let mut rng = Rng::new(&spec.text("seed")?);
    let mut e = Emitter::new(
        spec,
        "`field_of_movement` (src/algorithms/field_of_movement.rs:63) and `a_star`\n// (src/algorithms/pathfinding.rs:110)",
        USES,
    );
    for board in boards(&mut rng) {
        let rows = field_rows(&board, &mut rng, spec)?;
        let mut body = header(&board);
        body.push_str(&cases_array("u32, u8, u64", &rows));
        body.push_str(
            "    for (count, from, expected) in cases {
        let costs = classes.span().slice(0, count);
        let mut digest: u64 = 0xcbf29ce484222325;
        let mut budget: u8 = 0;
        while budget != 9 {
            digest = DigestTrait::bitmap(digest, field_of_movement(map, from, budget, costs));
            budget += 1;
        }
        assert(digest == expected, 'field');
    }
",
        );
        e.test(
            &format!("golden_algorithms_field_{}", board.name),
            false,
            &body,
        )?;
        let rows = star_rows(&board, &mut rng, spec)?;
        let mut body = header(&board);
        body.push_str(&cases_array("u32, u8, u8, u32", &rows));
        body.push_str(
            "    for (count, from, to, expected) in cases {
        let costs = classes.span().slice(0, count);
        let got = match a_star(map, from, to, costs) {
            Option::None => 0,
            Option::Some(path) => 1 + PathTrait::cost(map, costs, from, to, path),
        };
        assert(got == expected, 'a_star');
    }
",
        );
        e.test(
            &format!("golden_algorithms_a_star_{}", board.name),
            false,
            &body,
        )?;
    }
    Ok(vec![(crate::target(root, spec), e.finish()?)])
}
