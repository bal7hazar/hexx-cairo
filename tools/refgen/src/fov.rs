//! `fov`: `range_fov` (`src/algorithms/fov.rs:29`) and `directional_fov` (`:61`) of `hexx` 0.25.0
//! on a board, with the game's tie rule on the lines (M3-T2, LIB-06b). Two outputs, both checked
//! by `-- check`:
//!
//! - `crates/<package>/tests/golden_fov.cairo` (the spec's `package`): golden vectors, the bitmap
//!   of the field of view from each start of each board, at each range of the spec, and of the
//!   directional field of view for the six `EdgeDirection`s at the directional ranges.
//! - `docs/deviations/fov_ties.md`: every input of those vectors where `hexx`'s own `range_fov` or
//!   `directional_fov` differs from the reference, with the line and the tie that explain it.
//!
//! The reference (`reference`) is the contract of the Cairo port: for every hex `t` of the whole
//! ring (`Hex::ring`, on the board or not), the line from the start to `t` by the rule
//! (`line::rule`, both ends included), cut before its first hex that is off the board or a wall;
//! the union of those prefixes. `hexx` runs with the closure `blocking(h) = h off the board or a
//! wall`, so that the two differ only where their lines do. The generator refuses to write
//! anything when a line of `hexx` differs from the rule's at a sample that is not a tie, or when
//! the two fields of view differ and no tied line explains it (plan §6.6).

use std::collections::BTreeSet;
use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use hexx::algorithms::{directional_fov, range_fov};
use hexx::{EdgeDirection, Hex};

use crate::cairo::{cases_array, Emitter, Rng};
use crate::line::{felt, from_hex, rule, to_hex, Tile};
use crate::spec::Spec;

/// A board in the board frame (plan §3.5), `1` walkable.
struct Board {
    name: String,
    title: String,
    width: i64,
    height: i64,
    open: Vec<bool>,
    starts: Vec<usize>,
}

impl Board {
    fn size(&self) -> usize {
        (self.width * self.height) as usize
    }

    /// The tile of a `Hex`, `None` off the board.
    fn tile(&self, hex: Tile) -> Option<usize> {
        let (x, y) = from_hex(hex);
        if x < 0 || y < 0 || x >= self.width || y >= self.height {
            None
        } else {
            Some((y * self.width + x) as usize)
        }
    }

    fn hex(&self, tile: usize) -> Tile {
        to_hex((tile as i64 % self.width, tile as i64 / self.width))
    }

    fn coords(&self, tile: usize) -> (i64, i64) {
        (tile as i64 % self.width, tile as i64 / self.width)
    }

    fn blocking(&self, hex: Tile) -> bool {
        self.tile(hex).map_or(true, |t| !self.open[t])
    }

    /// The bitmap of a set of tiles as `(high, low)` limbs.
    fn bitmap(&self, tiles: &BTreeSet<usize>) -> (u128, u128) {
        let mut value = (0u128, 0u128);
        for &tile in tiles {
            if tile < 128 {
                value.1 |= 1 << tile;
            } else {
                value.0 |= 1 << (tile - 128);
            }
        }
        value
    }

    /// The `hexx` field of view of `from`, `range_fov` or `directional_fov` towards `direction`.
    fn hexx(&self, from: usize, range: u32, direction: Option<EdgeDirection>) -> BTreeSet<usize> {
        let (x, y) = self.hex(from);
        let start = Hex::new(x as i32, y as i32);
        let blocking = |h: Hex| self.blocking((i64::from(h.x), i64::from(h.y)));
        let set = match direction {
            None => range_fov(start, range, blocking),
            Some(direction) => directional_fov(start, range, direction, blocking),
        };
        set.into_iter()
            .map(|h| self.tile((i64::from(h.x), i64::from(h.y))).expect("a visible hex is on the board"))
            .collect()
    }

    /// The ring targets of `from` (`hexx`'s `Hex::ring`), those of the cone of `direction` only.
    fn targets(&self, from: usize, range: u32, direction: Option<EdgeDirection>) -> Vec<Hex> {
        let (x, y) = self.hex(from);
        let start = Hex::new(x as i32, y as i32);
        start
            .ring(range)
            .filter(|&t| match direction {
                None => true,
                Some(direction) => {
                    let [a, b] = direction.vertex_directions();
                    let way = start.diagonal_way_to(t);
                    way == a || way == b
                }
            })
            .collect()
    }

    /// The contract of the port: the union of the prefixes of the rule's lines.
    fn reference(&self, from: usize, range: u32, direction: Option<EdgeDirection>) -> BTreeSet<usize> {
        let start = self.hex(from);
        let mut seen = BTreeSet::new();
        for target in self.targets(from, range, direction) {
            for sample in rule(start, (i64::from(target.x), i64::from(target.y))) {
                if self.blocking(sample.hex) {
                    break;
                }
                seen.insert(self.tile(sample.hex).unwrap());
            }
        }
        seen
    }

    /// The first ring target of `from` whose `hexx` line differs from the rule's and holds, in
    /// either form, a tile of `differ` (the tiles where the two fields of view differ), as the
    /// target and its first differing sample `(index, rule, hexx)`. Every differing sample of every
    /// line must be a tie of the rule.
    fn tie(
        &self,
        from: usize,
        range: u32,
        direction: Option<EdgeDirection>,
        differ: &BTreeSet<usize>,
    ) -> Result<Option<(Tile, usize, Tile, Tile)>, String> {
        let (x, y) = self.hex(from);
        let start = Hex::new(x as i32, y as i32);
        let mut first = None;
        for target in self.targets(from, range, direction) {
            let ours = rule((x, y), (i64::from(target.x), i64::from(target.y)));
            let theirs: Vec<Tile> = start
                .line_to(target)
                .map(|h| (i64::from(h.x), i64::from(h.y)))
                .collect();
            if theirs.len() != ours.len() {
                return Err(format!("{}: hexx's line to {target:?} has {} hexes", self.name, theirs.len()));
            }
            let holds = ours
                .iter()
                .map(|sample| sample.hex)
                .chain(theirs.iter().copied())
                .any(|hex| self.tile(hex).is_some_and(|t| differ.contains(&t)));
            for (i, (sample, hexx)) in ours.iter().zip(&theirs).enumerate() {
                if sample.hex == *hexx {
                    continue;
                }
                if !sample.tie {
                    return Err(format!(
                        "{}: from {from} to {target:?}, sample {i}: hexx {hexx:?} and the rule {:?} differ \
                         with no tie",
                        self.name, sample.hex
                    ));
                }
                if holds && first.is_none() {
                    first = Some(((i64::from(target.x), i64::from(target.y)), i, sample.hex, *hexx));
                }
            }
        }
        Ok(first)
    }
}

/// One input where `hexx` and the reference differ.
struct Difference {
    board: String,
    from: (i64, i64),
    range: u32,
    direction: Option<usize>,
    ours: Vec<(i64, i64)>,
    theirs: Vec<(i64, i64)>,
    tie: (Tile, usize, Tile, Tile),
}

/// The tile `(x, y)` of a board.
fn at(width: i64, x: i64, y: i64) -> usize {
    (y * width + x) as usize
}

fn boards(rng: &mut Rng) -> Vec<Board> {
    let mut all = Vec::new();
    for (width, height) in [(15i64, 16i64), (7, 7)] {
        let starts: Vec<usize> = if width == 15 {
            // The centres, the tiles next to the ring on each side, two ring tiles
            [(7, 7), (7, 8), (1, 7), (13, 8), (7, 1), (6, 14), (0, 9), (14, 15)]
                .iter()
                .map(|&(x, y)| at(width, x, y))
                .collect()
        } else {
            [(3, 3), (3, 4), (1, 3), (5, 2), (3, 1), (2, 5), (0, 3), (6, 6)]
                .iter()
                .map(|&(x, y)| at(width, x, y))
                .collect()
        };
        let kinds: &[(usize, &str)] = if width == 15 {
            &[(0, "empty"), (1, "cave_a"), (2, "cave_b")]
        } else {
            &[(0, "empty"), (1, "cave")]
        };
        for &(kind, name) in kinds {
            let size = (width * height) as usize;
            let mut open: Vec<bool> = (0..size).map(|_| kind == 0 || rng.next_i32(0, 2) != 0).collect();
            for &start in &starts {
                open[start] = true;
            }
            let title = format!("{} {width} × {height}", name.replace('_', " "));
            all.push(Board {
                name: format!("{name}_{width}x{height}"),
                title,
                width,
                height,
                open,
                starts: starts.clone(),
            });
        }
    }
    all
}

/// The ranges of `range_fov`: `0..=range_max`, then `range_far`.
fn ranges(spec: &Spec) -> Result<Vec<u32>, String> {
    let mut all: Vec<u32> = (0..=spec.int("range_max")? as u32).collect();
    all.push(spec.int("range_far")? as u32);
    Ok(all)
}

/// The ranges of `directional_fov`.
fn directional_ranges(spec: &Spec) -> Result<Vec<u32>, String> {
    Ok(vec![spec.int("directional_a")? as u32, spec.int("directional_b")? as u32])
}

/// Compares `hexx` and the reference on one input: `Ok(None)` when they agree.
fn compare(
    board: &Board,
    from: usize,
    range: u32,
    direction: Option<usize>,
) -> Result<(BTreeSet<usize>, Option<Difference>), String> {
    let facing = direction.map(|d| EdgeDirection::ALL_DIRECTIONS[d]);
    let ours = board.reference(from, range, facing);
    let theirs = board.hexx(from, range, facing);
    let differ: BTreeSet<usize> = ours.symmetric_difference(&theirs).copied().collect();
    let tie = board.tie(from, range, facing, &differ)?;
    if ours == theirs {
        return Ok((ours, None));
    }
    let tie = tie.ok_or(format!(
        "{}: from {from} range {range} direction {direction:?}: hexx and the reference differ \
         and no tied line holds a tile that differs",
        board.name
    ))?;
    let only = |a: &BTreeSet<usize>, b: &BTreeSet<usize>| -> Vec<(i64, i64)> {
        a.difference(b).map(|&t| board.coords(t)).collect()
    };
    let difference = Difference {
        board: board.title.clone(),
        from: board.coords(from),
        range,
        direction,
        ours: only(&ours, &theirs),
        theirs: only(&theirs, &ours),
        tie,
    };
    Ok((ours, Some(difference)))
}

fn tiles(list: &[(i64, i64)]) -> String {
    if list.is_empty() {
        return "—".into();
    }
    list.iter().map(|(x, y)| format!("`({x}, {y})`")).collect::<Vec<_>>().join(", ")
}

/// The deviation document.
fn deviations(differences: &[Difference], counts: &[(String, usize, usize)]) -> String {
    let mut out = String::new();
    out.push_str("# `range_fov`, `directional_fov`: where this port and `hexx` 0.25.0 differ\n\n");
    out.push_str(
        "Generated by `cargo run --manifest-path tools/refgen/Cargo.toml -- gen fov` \
         (`tools/refgen/src/fov.rs`); do not edit by hand.\n\n",
    );
    out.push_str(
        "`hexx::algorithms::range_fov` and `directional_fov` take, on the line from the start to each \
         hex of the ring, the prefix before the first blocking hex (`src/algorithms/fov.rs:29-34`, \
         `:61-75`). This port blocks on the walls of the map and on every hex off the board, and its \
         lines carry the game's tie rule (plan §6.6, `docs/deviations/line_ties.md`), where `hexx`'s \
         `line_to` rounds `f32` (`src/hex/mod.rs:903-911`). `hexx` is run here with the closure \
         `blocking(h) = h off the board or a wall` on every input of the golden vectors \
         (`crates/golden_lm2/tests/golden_fov.cairo`); the inputs below are those where its result \
         differs. Each is explained by a tie: the column *Tie* gives the first ring hex whose line \
         differs, in the frame of the mirror, and its first differing sample `index: (this port) / \
         (hexx)`. The generator stops on a difference that no tie explains. Tiles are `(x, y)` of \
         the board; the direction is the index of the `EdgeDirection`, `—` for `range_fov`.\n\n",
    );
    out.push_str("## The inputs compared\n\n");
    out.push_str("| Board | Inputs | Inputs that differ |\n|---|---|---|\n");
    for (board, inputs, differ) in counts {
        writeln!(out, "| {board} | {inputs} | {differ} |").unwrap();
    }
    out.push_str("\n## The inputs that differ\n\n");
    if differences.is_empty() {
        out.push_str("None.\n");
        return out;
    }
    out.push_str(
        "| Board | From | Range | Direction | Only in this port | Only in `hexx` | Tie |\n\
         |---|---|---|---|---|---|---|\n",
    );
    for d in differences {
        let ((tx, ty), i, (ox, oy), (hx, hy)) = d.tie;
        writeln!(
            out,
            "| {} | `({}, {})` | {} | {} | {} | {} | to `({tx}, {ty})`, `{i}: ({ox}, {oy}) / ({hx}, {hy})` |",
            d.board,
            d.from.0,
            d.from.1,
            d.range,
            d.direction.map_or("—".to_string(), |x| x.to_string()),
            tiles(&d.ours),
            tiles(&d.theirs),
        )
        .unwrap();
    }
    out
}

const USES: &str = "use hexx::algorithms::{directional_fov, range_fov};
use hexx::board::map::HexMap;
use hexx::direction::edge_direction::EdgeDirectionTrait;
";

fn header(board: &Board) -> String {
    let set: BTreeSet<usize> = (0..board.size()).filter(|&t| board.open[t]).collect();
    let grid = felt(board.bitmap(&set));
    let (width, height) = (board.width, board.height);
    // As `scarb fmt` lays them out: on one line when they fit in 100 columns
    let line = format!("    let map = HexMap {{ width: {width}, height: {height}, grid: {grid}, seed: 0 }};\n");
    if line.len() <= 101 {
        line
    } else {
        format!(
            "    let map = HexMap {{\n        width: {width},\n        height: {height},\n        grid: {grid},\n        seed: 0,\n    }};\n"
        )
    }
}

pub fn emit(spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    let mut rng = Rng::new(&spec.text("seed")?);
    let mut e = Emitter::new(
        spec,
        "`range_fov` (src/algorithms/fov.rs:29) and `directional_fov` (:61), with the\n// game's tie rule on the lines (tools/refgen/src/fov.rs)",
        USES,
    );
    let mut differences = Vec::new();
    let mut counts = Vec::new();
    for board in boards(&mut rng) {
        let mut inputs = 0;
        let before = differences.len();
        // range_fov
        let mut rows = Vec::new();
        for &from in &board.starts {
            for range in ranges(spec)? {
                let (set, difference) = compare(&board, from, range, None)?;
                inputs += 1;
                differences.extend(difference);
                rows.push(format!("{from}, {range}, {}", felt(board.bitmap(&set))));
            }
        }
        let mut body = header(&board);
        body.push_str(&cases_array("u8, u8, felt252", &rows));
        body.push_str(
            "    for (from, range, expected) in cases {
        assert(range_fov(map, from, range) == expected, 'range_fov');
    }
",
        );
        e.test(&format!("golden_fov_range_{}", board.name), false, &body)?;
        // directional_fov
        let mut rows = Vec::new();
        for &from in &board.starts {
            for range in directional_ranges(spec)? {
                for direction in 0..6 {
                    let (set, difference) = compare(&board, from, range, Some(direction))?;
                    inputs += 1;
                    differences.extend(difference);
                    rows.push(format!("{from}, {range}, {direction}, {}", felt(board.bitmap(&set))));
                }
            }
        }
        let mut body = header(&board);
        body.push_str("    let directions = EdgeDirectionTrait::ALL_DIRECTIONS.span();\n");
        body.push_str(&cases_array("u8, u8, u32, felt252", &rows));
        body.push_str(
            "    for (from, range, direction, expected) in cases {
        let direction = *directions[direction];
        assert(directional_fov(map, from, range, direction) == expected, 'directional_fov');
    }
",
        );
        e.test(&format!("golden_fov_directional_{}", board.name), false, &body)?;
        counts.push((board.title.clone(), inputs, differences.len() - before));
    }
    Ok(vec![
        (crate::target(root, spec), e.finish()?),
        (root.join("docs/deviations/fov_ties.md"), deviations(&differences, &counts)),
    ])
}
