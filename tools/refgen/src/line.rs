//! `line`: the integer line of plan §6.6 (N-5), `Hex::line_to` of the mirror and `LineTrait` of the
//! board. Three outputs, all checked by `-- check`:
//!
//! - `crates/<package>/tests/golden_line.cairo` (the spec's `package`): golden vectors. The
//!   mirror's `line_to` against the rule (`rule`, below) on every ordered pair of the 15 × 16
//!   window and of a 7 × 7 board in the mirror frame, against `hexx` 0.25.0 itself on a seeded sample of non-tie pairs of `[-40, 40]²`, and
//!   against the rule on the adversarial large-coordinate pairs; the board's `line`, `approach`
//!   and `line_of_sight` against the board model on every ordered pair of the boards of the spec.
//!   Each vector is a digest (`Digest`) of the whole line, so that every element is compared
//!   without writing every element.
//! - the generated region of `crates/hexx/src/board/line.cairo`: the table `LINES` of the table
//!   path (`table`, below).
//! - `docs/deviations/line_ties.md`: every pair of those sets where `hexx` 0.25.0 and the rule
//!   differ, under its heading (tie, endpoint rounding, interpolation rounding).
//!
//! The generator refuses to write anything when the rule's own accumulator form (`walk`, the
//! algorithm of the Cairo port) differs from the rule's definition on any pair it generates, when
//! the rule is not symmetric on one of them, or when `hexx` and the rule differ on a non-tie pair
//! of the window or of the seeded sample (plan §6.6, "Deviation from `hexx`").

use std::fmt::Write as _;
use std::fs;
use std::path::{Path, PathBuf};

use hexx::Hex;

use crate::cairo::{cases_array, probe, Emitter, Rng};
use crate::spec::Spec;

/// A coordinate `(x, y)` of the mirror frame, or a tile `(x, y)` of a board.
pub type Tile = (i64, i64);

/// One element of the rule's line: the tile, and whether its point lies on the edge between two
/// tiles (an exact tie, resolved by the rule).
#[derive(Clone, Copy)]
pub struct Sample {
    pub hex: Tile,
    pub tie: bool,
}

/// The hexagonal distance, `max(|dx|, |dy|, |dx + dy|)`.
pub fn distance(a: Tile, b: Tile) -> i64 {
    let (dx, dy) = (b.0 - a.0, b.1 - a.1);
    dx.abs().max(dy.abs()).max((dx + dy).abs())
}

/// The rule of plan §6.6 by its definition: element `i` of the line from `a` to `b` is the tile
/// nearest (Euclidean distance in cube coordinates) to the exact point `a + (i / N)·(b − a)`; at an
/// exact tie between two tiles, the one with the smaller `y`, and on the same row the larger `x`.
/// Exact integer arithmetic: every coordinate is a numerator over `N`.
pub fn rule(a: Tile, b: Tile) -> Vec<Sample> {
    let n = i128::from(distance(a, b));
    if n == 0 {
        return vec![Sample { hex: a, tie: false }];
    }
    let (ax, ay) = (i128::from(a.0), i128::from(a.1));
    let (dx, dy) = (i128::from(b.0 - a.0), i128::from(b.1 - a.1));
    (0..=n)
        .map(|i| {
            let (px, py) = (ax * n + i * dx, ay * n + i * dy);
            let (fx, fy) = (px.div_euclid(n), py.div_euclid(n));
            let mut best: Option<(i128, i128, i128)> = None;
            let mut tie = false;
            for cx in fx - 1..=fx + 2 {
                for cy in fy - 1..=fy + 2 {
                    let (ex, ey) = (px - cx * n, py - cy * n);
                    let ez = -ex - ey;
                    let d = ex * ex + ey * ey + ez * ez;
                    match best {
                        Some((bd, _, _)) if d > bd => {}
                        Some((bd, bx, by)) if d == bd => {
                            tie = true;
                            if cy < by || (cy == by && cx > bx) {
                                best = Some((d, cx, cy));
                            }
                        }
                        _ => {
                            best = Some((d, cx, cy));
                            tie = false;
                        }
                    }
                }
            }
            let (_, x, y) = best.expect("16 candidates");
            Sample { hex: (x as i64, y as i64), tie }
        })
        .collect()
}

/// The rule in the form of the Cairo port (`HexTrait::line_to`, `LineInternal::walk`): `x` is
/// rounded half up and `y` half down, each by an integer accumulator, no division.
pub fn walk(a: Tile, b: Tile) -> Vec<Tile> {
    let n = distance(a, b) as u64;
    let mut line = vec![a];
    let (dx, dy) = (b.0 - a.0, b.1 - a.1);
    // x: a tie goes to the larger x, so the magnitude rounds half up when x grows, down otherwise
    let (sx, mx, mut ex) = if dx > 0 { (1, dx as u64, n) } else { (-1, (-dx) as u64, n.saturating_sub(1)) };
    // y: a tie goes to the smaller y, so the magnitude rounds half down when y grows, up otherwise
    let (sy, my, mut ey) = if dy > 0 { (1, dy as u64, n.saturating_sub(1)) } else { (-1, (-dy) as u64, n) };
    let (tx, ty) = (2 * n - 2 * mx, 2 * n - 2 * my);
    let (mut x, mut y) = a;
    for _ in 0..n {
        if ex >= tx {
            ex -= tx;
            x += sx;
        } else {
            ex += 2 * mx;
        }
        if ey >= ty {
            ey -= ty;
            y += sy;
        } else {
            ey += 2 * my;
        }
        line.push((x, y));
    }
    line
}

/// `hexx` 0.25.0's `line_to`, `None` when it panics.
fn hexx_line(a: Tile, b: Tile) -> Option<Vec<Tile>> {
    probe(|| {
        Hex::new(a.0 as i32, a.1 as i32)
            .line_to(Hex::new(b.0 as i32, b.1 as i32))
            .map(|h| (i64::from(h.x), i64::from(h.y)))
            .collect()
    })
}

/// The rule's line, checked: its accumulator form agrees, and it is symmetric.
fn checked(a: Tile, b: Tile) -> Result<Vec<Sample>, String> {
    let line = rule(a, b);
    let tiles: Vec<Tile> = line.iter().map(|s| s.hex).collect();
    if walk(a, b) != tiles {
        return Err(format!("the accumulator form differs from the rule on {a:?} -> {b:?}"));
    }
    let mut back: Vec<Tile> = rule(b, a).iter().map(|s| s.hex).collect();
    back.reverse();
    if back != tiles {
        return Err(format!("the rule is not symmetric on {a:?} -> {b:?}"));
    }
    Ok(line)
}

// The board frame (plan §3.5)

/// The `Hex` of the tile `(x, y)`: `(−x − ⌈y/2⌉, y)`.
pub fn to_hex(tile: Tile) -> Tile {
    (-tile.0 - (tile.1 + 1).div_euclid(2), tile.1)
}

/// The tile of a `Hex`, the inverse of `to_hex`.
pub fn from_hex(hex: Tile) -> Tile {
    (-hex.0 - (hex.1 + 1).div_euclid(2), hex.1)
}

/// The results of the board for one pair: `line` (the between tiles as indices, `None` when one
/// of them leaves the board) and `approach` (the index of the direction from `to` to the tile
/// before it on the line).
pub struct BoardLine {
    pub between: Option<Vec<i64>>,
    pub approach: Option<u8>,
}

/// The board's `line` and `approach` by their definition (plan §6.6): the rule's line between the
/// `Hex` of both positions, its elements back on the board.
pub fn board_line(width: i64, height: i64, from: i64, to: i64) -> Result<BoardLine, String> {
    let tile = |i: i64| (i % width, i / width);
    let (a, b) = (to_hex(tile(from)), to_hex(tile(to)));
    let line = checked(a, b)?;
    let n = line.len() - 1;
    let mut between = Some(Vec::new());
    for sample in &line[1..n.max(1)] {
        let (x, y) = from_hex(sample.hex);
        if x < 0 || x >= width || y < 0 || y >= height {
            between = None;
            break;
        }
        if let Some(tiles) = between.as_mut() {
            tiles.push(y * width + x);
        }
    }
    if n == 0 {
        between = Some(Vec::new());
    }
    let approach = match (&between, n) {
        (Some(_), n) if n >= 1 => {
            let previous = line[n - 1].hex;
            let step = (previous.0 - b.0, previous.1 - b.1);
            let index = [(1, 0), (0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1)]
                .iter()
                .position(|&d| d == step)
                .ok_or(format!("{from} -> {to}: the tile before the target is not a neighbour"))?;
            Some(index as u8)
        }
        _ => None,
    };
    Ok(BoardLine { between, approach })
}

// The table of the table path

/// The prime of `felt252`, `2^251 + 17·2^192 + 1`, as `(high, low)` limbs.
const PRIME: (u128, u128) = ((1 << 123) + (17 << 64), 1);

/// `value · 2^-1` in the field, for `value < PRIME`.
fn halve(value: (u128, u128)) -> (u128, u128) {
    let (mut high, mut low) = value;
    if low & 1 == 1 {
        let (sum, carry) = low.overflowing_add(PRIME.1);
        low = sum;
        high = high + PRIME.0 + u128::from(carry);
    }
    ((high >> 1), (low >> 1) | ((high & 1) << 127))
}

/// The board of the table, its width, and the canonical starts: `(7, 8)` for an even row, `(7, 7)`
/// for an odd one (plan §6.6, "Tables").
const TABLE_WIDTH: i64 = 15;
const TABLE_HEIGHT: i64 = 16;
const TABLE_STARTS: [Tile; 2] = [(7, 8), (7, 7)];
/// The radius the table serves.
const TABLE_RADIUS: i64 = 6;

/// One entry of `LINES`: the between-mask of the canonical start `c` times `2^-c` (a field element:
/// times `2^from` it is the mask of `from`), the range of `from mod 30` for which every tile of the
/// line lies in the columns `0..15` (`lo..=hi`), and the range for which the target does
/// (`lo_to..=hi_to`); none for an offset beyond the radius.
#[derive(Clone)]
struct Entry {
    relative: (u128, u128),
    lo: i64,
    hi: i64,
    lo_to: i64,
    hi_to: i64,
}

/// The entries, by key `to − from + offset + span · parity`, and `(offset, span)`.
fn table() -> Result<(Vec<Option<Entry>>, i64, i64), String> {
    let mut rows: Vec<(usize, i64, Entry)> = Vec::new();
    for (parity, &(cx, cy)) in TABLE_STARTS.iter().enumerate() {
        let start = cy * TABLE_WIDTH + cx;
        for to in 0..TABLE_WIDTH * TABLE_HEIGHT {
            let target = (to % TABLE_WIDTH, to / TABLE_WIDTH);
            if distance(to_hex((cx, cy)), to_hex(target)) > TABLE_RADIUS {
                continue;
            }
            let line = board_line(TABLE_WIDTH, TABLE_HEIGHT, start, to)?;
            let between = line.between.ok_or(format!("{start} -> {to} leaves the canonical board"))?;
            let mut mask: (u128, u128) = (0, 0);
            let (mut low_column, mut high_column) = (0, target.0 - cx);
            low_column = low_column.min(high_column);
            high_column = high_column.max(0);
            for &tile in &between {
                if tile < 128 {
                    mask.1 |= 1 << tile;
                } else {
                    mask.0 |= 1 << (tile - 128);
                }
                let column = tile % TABLE_WIDTH - cx;
                low_column = low_column.min(column);
                high_column = high_column.max(column);
            }
            let mut relative = mask;
            for _ in 0..start {
                relative = halve(relative);
            }
            let shift = parity as i64 * TABLE_WIDTH;
            let column = target.0 - cx;
            rows.push((
                parity,
                to - start,
                Entry {
                    relative,
                    lo: -low_column + shift,
                    hi: TABLE_WIDTH - 1 - high_column + shift,
                    lo_to: (-column).max(0) + shift,
                    hi_to: (TABLE_WIDTH - 1 - column).min(TABLE_WIDTH - 1) + shift,
                },
            ));
        }
    }
    let offset = -rows.iter().map(|(_, delta, _)| *delta).min().unwrap_or(0);
    let span = rows.iter().map(|(_, delta, _)| *delta).max().unwrap_or(0) + offset + 1;
    let mut entries: Vec<Option<Entry>> = vec![None; 2 * span as usize];
    for (parity, delta, entry) in rows {
        let slot = (delta + offset + span * parity as i64) as usize;
        if entries[slot].is_some() {
            return Err(format!("two offsets share the key {slot}"));
        }
        entries[slot] = Some(entry);
    }
    Ok((entries, offset, span))
}

/// Packs `items` as `scarb fmt` packs an array literal: as many per line as fit in 100 columns,
/// each line ending with a comma.
pub fn pack(indent: &str, items: &[String]) -> String {
    let mut out = String::new();
    let mut line = String::new();
    for item in items {
        if line.is_empty() {
            line = format!("{indent}{item},");
        } else if line.len() + 1 + item.len() + 1 <= 100 {
            line.push_str(&format!(" {item},"));
        } else {
            out.push_str(&line);
            out.push('\n');
            line = format!("{indent}{item},");
        }
    }
    if !line.is_empty() {
        out.push_str(&line);
        out.push('\n');
    }
    out
}

pub fn felt(value: (u128, u128)) -> String {
    if value.0 == 0 {
        format!("{:#x}", value.1)
    } else {
        format!("{:#x}{:032x}", value.0, value.1)
    }
}

const BEGIN: &str = "// region generated by `cargo run --manifest-path tools/refgen/Cargo.toml -- gen line`: do not edit";
const END: &str = "// endregion";

/// The generated region of `crates/hexx/src/board/line.cairo`.
fn table_region() -> Result<String, String> {
    let (entries, offset, span) = table()?;
    let mut out = String::new();
    writeln!(out, "{BEGIN}").unwrap();
    writeln!(out).unwrap();
    writeln!(out, "/// The smallest `to − from` of the table, its key offset.").unwrap();
    writeln!(out, "const OFFSET: felt252 = {offset};").unwrap();
    writeln!(out, "/// The keys of one parity: `to − from + OFFSET` is below it.").unwrap();
    writeln!(out, "const SPAN: felt252 = {span};").unwrap();
    writeln!(out, "/// The entries of the table path, by key `to − from + OFFSET + SPAN · (row of from is odd)`,").unwrap();
    writeln!(out, "/// on the width 15: `(mask · 2^-c, lo, hi, lo_to, hi_to)`, where `mask` is the between-mask of the").unwrap();
    writeln!(out, "/// line from the canonical start `c` (`(7, 8)`, index 127, for an even row; `(7, 7)`, index 112,").unwrap();
    writeln!(out, "/// for an odd one) to `c + to − from`, `lo..=hi` the values of `from mod 30` for which every").unwrap();
    writeln!(out, "/// tile of the line lies in the columns `0..15`, and `lo_to..=hi_to` those for which the target").unwrap();
    writeln!(out, "/// does (`from mod 30` is the column plus 15 on an odd row). A key beyond the radius 6 has the").unwrap();
    writeln!(out, "/// empty ranges `(0, 30, 0, 30, 0)`.").unwrap();
    let items: Vec<String> = entries
        .iter()
        .map(|entry| match entry {
            Some(e) => format!("({}, {}, {}, {}, {})", felt(e.relative), e.lo, e.hi, e.lo_to, e.hi_to),
            None => "(0x0, 30, 0, 30, 0)".to_string(),
        })
        .collect();
    writeln!(out, "const LINES: [(felt252, u8, u8, u8, u8); {}] = [", items.len()).unwrap();
    out.push_str(&pack("    ", &items));
    writeln!(out, "];").unwrap();
    writeln!(out).unwrap();
    out.push_str(END);
    Ok(out)
}

/// `line.cairo` with its generated region replaced.
fn with_region(current: &str, region: &str) -> Result<String, String> {
    let start = current.find(BEGIN).ok_or("line.cairo: no generated region (BEGIN marker)")?;
    let end = current[start..].find(END).ok_or("line.cairo: no end of the generated region")? + start;
    Ok(format!("{}{}{}", &current[..start], region, &current[end + END.len()..]))
}

// Digests

/// `a + b` in the field, for `a, b < PRIME`.
fn add_mod(a: (u128, u128), b: (u128, u128)) -> (u128, u128) {
    let (low, carry) = a.1.overflowing_add(b.1);
    let high = a.0 + b.0 + u128::from(carry);
    if (high, low) >= PRIME {
        let (low, borrow) = low.overflowing_sub(PRIME.1);
        (high - PRIME.0 - u128::from(borrow), low)
    } else {
        (high, low)
    }
}

/// The multiplier of the digests.
const BASE: u64 = 0x100000001b3;

/// The polynomial digest the golden tests recompute in Cairo (`DigestTrait` of the generated
/// file): `digest · BASE + value` in the field of `felt252`, value after value.
#[derive(Default, Clone, Copy)]
struct Digest((u128, u128));

impl Digest {
    fn fold(&mut self, value: (u128, u128)) {
        // `digest · BASE` by doubling and adding, then `+ value`
        let mut product = (0, 0);
        for bit in (0..64).rev() {
            product = add_mod(product, product);
            if (BASE >> bit) & 1 == 1 {
                product = add_mod(product, self.0);
            }
        }
        self.0 = add_mod(product, value);
    }

    fn small(&mut self, value: u128) {
        self.fold((0, value));
    }

    fn hex(&mut self, (x, y): Tile) {
        let x = (x + (1 << 31)) as u128;
        let y = (y + (1 << 31)) as u128;
        self.small(x * (1 << 32) + y);
    }

    fn line(&mut self, line: &[Tile]) {
        self.small(line.len() as u128);
        for &hex in line {
            self.hex(hex);
        }
    }

    fn mask(&mut self, tiles: &Option<Vec<i64>>) {
        match tiles {
            None => self.small(0),
            Some(tiles) => {
                let mut mask = (0u128, 0u128);
                for &tile in tiles {
                    if tile < 128 {
                        mask.1 |= 1 << tile;
                    } else {
                        mask.0 |= 1 << (tile - 128);
                    }
                }
                self.small(1);
                self.fold(mask);
            }
        }
    }

    fn option(&mut self, value: Option<u8>) {
        match value {
            None => self.small(0),
            Some(v) => self.small(1 + u128::from(v)),
        }
    }

    fn text(&self) -> String {
        felt(self.0)
    }
}

// The deviations

/// The heading of a pair, by priority: a pair is listed under the greatest kind of its samples.
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
enum Kind {
    Tie,
    Interpolation,
    Endpoint,
}

impl Kind {
    fn heading(self) -> &'static str {
        match self {
            Kind::Tie => "Tie",
            Kind::Endpoint => "Endpoint rounding",
            Kind::Interpolation => "Interpolation rounding",
        }
    }
}

/// A pair where `hexx` and the rule differ.
struct Difference {
    set: &'static str,
    a: Tile,
    b: Tile,
    n: usize,
    kind: Kind,
    /// `(sample, port, hexx)` of every differing sample.
    samples: Vec<(usize, Tile, Tile)>,
}

/// The difference between `hexx` and the rule on one pair, `None` when they agree.
fn compare(set: &'static str, a: Tile, b: Tile, rule: &[Sample]) -> Result<Option<Difference>, String> {
    let theirs = hexx_line(a, b).ok_or(format!("hexx panics on {a:?} -> {b:?}"))?;
    if theirs.len() != rule.len() {
        return Err(format!("hexx returns {} tiles on {a:?} -> {b:?}", theirs.len()));
    }
    let n = rule.len() - 1;
    let mut samples = Vec::new();
    let mut kind = Kind::Tie;
    for (i, (ours, theirs)) in rule.iter().zip(&theirs).enumerate() {
        if ours.hex != *theirs {
            samples.push((i, ours.hex, *theirs));
            let this = if ours.tie {
                Kind::Tie
            } else if i == 0 || i == n {
                Kind::Endpoint
            } else {
                Kind::Interpolation
            };
            kind = kind.max(this);
        }
    }
    if samples.is_empty() {
        return Ok(None);
    }
    Ok(Some(Difference { set, a, b, n, kind, samples }))
}

fn has_tie(line: &[Sample]) -> bool {
    line.iter().any(|s| s.tie)
}

/// The tiles of a `width × height` board in the mirror frame, in index order.
fn board_hexes(width: i64, height: i64) -> Vec<Tile> {
    (0..width * height).map(|i| to_hex((i % width, i / width))).collect()
}

/// The adversarial pairs (plan §4.3): endpoints near `2^k` for `k = 20..=30`, short lines with and
/// without ties, a line of a few hundred tiles, and the regression cases R-N5-5 and R-N5-6.
fn adversarial(long: i64) -> Vec<(Tile, Tile)> {
    let mut pairs = vec![
        ((8_000_000, 0), (8_000_001, 6)),
        ((16_777_217, 0), (16_777_218, 0)),
    ];
    for k in 20..=30 {
        let p: i64 = 1 << k;
        pairs.push(((p, 0), (p + 1, 6)));
        pairs.push(((p - 1, -p + 3), (p + 2, -p + 6)));
        pairs.push(((-p, p - 2), (-p + 7, p - 13)));
        pairs.push(((p - 5, 7), (p + long, 7 - long / 3)));
    }
    pairs
}

/// The deviation document.
fn deviations(differences: &[Difference], counts: &[(&str, usize, usize)]) -> String {
    let mut out = String::new();
    out.push_str("# `line_to`: where this port and `hexx` 0.25.0 differ\n\n");
    out.push_str(
        "Generated by `cargo run --manifest-path tools/refgen/Cargo.toml -- gen line` \
         (`tools/refgen/src/line.rs`); do not edit by hand.\n\n",
    );
    out.push_str(
        "`HexTrait::line_to` is the exact integer line of plan §6.6: element `i` is the tile nearest the \
         point `a + (i / N)·(b − a)`, and at an exact tie between two tiles the one with the smaller \
         `y`, and on the same row the larger `x`. `hexx` 0.25.0 (`src/hex/mod.rs:903-911`) converts \
         both endpoints to `f32` (`:906`), interpolates in `f32` (`:908`) and rounds (`:474-483`). The \
         two lines differ at a tie (`hexx`'s `f32` rule is neither symmetric nor translation-invariant), \
         where `f32` rounds an endpoint (beyond `2^24`), and where the `f32` interpolation moves a sample \
         across the edge of its tile. Each pair below is listed under the first of these that applies: \
         endpoint rounding, then interpolation rounding (a sample that is not a tie), then tie. A sample \
         is `(index, this port, hexx)`.\n\n",
    );
    out.push_str("## The sets compared\n\n");
    out.push_str("| Set | Pairs | Pairs that differ |\n|---|---|---|\n");
    for (set, pairs, differ) in counts {
        writeln!(out, "| {set} | {pairs} | {differ} |").unwrap();
    }
    out.push('\n');
    out.push_str(
        "No pair without a tie differs on the window or on the seeded sample: the generator stops \
         otherwise (plan §6.6, the parity claim).\n",
    );
    for kind in [Kind::Tie, Kind::Endpoint, Kind::Interpolation] {
        writeln!(out, "\n## {}\n", kind.heading()).unwrap();
        let listed: Vec<&Difference> = differences.iter().filter(|d| d.kind == kind).collect();
        if listed.is_empty() {
            out.push_str("None.\n");
            continue;
        }
        out.push_str("| Set | From | To | N | Samples that differ |\n|---|---|---|---|---|\n");
        for d in listed {
            let samples: Vec<String> = if d.samples.len() <= 4 {
                d.samples
                    .iter()
                    .map(|(i, o, t)| format!("`{i}: ({}, {}) / ({}, {})`", o.0, o.1, t.0, t.1))
                    .collect()
            } else {
                let (i, o, t) = d.samples[0];
                vec![format!(
                    "{} samples, the first `{i}: ({}, {}) / ({}, {})`",
                    d.samples.len(),
                    o.0,
                    o.1,
                    t.0,
                    t.1
                )]
            };
            writeln!(
                out,
                "| {} | `({}, {})` | `({}, {})` | {} | {} |",
                d.set,
                d.a.0,
                d.a.1,
                d.b.0,
                d.b.1,
                d.n,
                samples.join(", ")
            )
            .unwrap();
        }
    }
    out
}

// The Cairo of the golden file

const USES: &str = "use hexx::board::line::LineTrait;
use hexx::board::map::HexMap;
use hexx::hex::{Hex, HexTrait};
";

const HELPERS: &str = "
/// The digest of `tools/refgen/src/line.rs` (`Digest`): `digest · 0x100000001b3 + value` in the
/// field, value after value.
#[generate_trait]
impl DigestImpl of DigestTrait {
    fn fold(digest: felt252, value: felt252) -> felt252 {
        digest * 0x100000001b3 + value
    }

    fn hex(digest: felt252, hex: Hex) -> felt252 {
        let x: felt252 = hex.x.into() + 0x80000000;
        let y: felt252 = hex.y.into() + 0x80000000;
        Self::fold(digest, x * 0x100000000 + y)
    }

    fn line(digest: felt252, line: Span<Hex>) -> felt252 {
        let mut digest = Self::fold(digest, line.len().into());
        for hex in line {
            digest = Self::hex(digest, *hex);
        }
        digest
    }

    fn mask(digest: felt252, mask: Option<felt252>) -> felt252 {
        match mask {
            None => Self::fold(digest, 0),
            Some(mask) => Self::fold(Self::fold(digest, 1), mask),
        }
    }

    fn option(digest: felt252, value: Option<u8>) -> felt252 {
        match value {
            None => Self::fold(digest, 0),
            Some(value) => Self::fold(digest, 1 + value.into()),
        }
    }

    /// The `Hex` of the tile `(x, y)`: `(−x − ⌈y/2⌉, y)` (plan §3.5).
    fn tile(width: u32, index: u32) -> Hex {
        let (x, y) = (index % width, index / width);
        let column: i32 = x.try_into().unwrap();
        let half: i32 = ((y + 1) / 2).try_into().unwrap();
        HexTrait::new(-column - half, y.try_into().unwrap())
    }
}
";

/// The rows `(ax, ay, digest)` of the lines from each `from` to every tile of `hexes`.
fn mirror_rows(hexes: &[Tile], froms: &[Tile]) -> Result<Vec<String>, String> {
    froms
        .iter()
        .map(|&a| {
            let mut digest = Digest::default();
            for &b in hexes {
                let line: Vec<Tile> = checked(a, b)?.iter().map(|s| s.hex).collect();
                digest.line(&line);
            }
            Ok(format!("{}, {}, {}", a.0, a.1, digest.text()))
        })
        .collect()
}

fn mirror_body(rows: &[String], width: i64, height: i64) -> String {
    format!(
        "{}    let size: u32 = {};
    for (x, y, expected) in cases {{
        let a = HexTrait::new(x, y);
        let mut digest: felt252 = 0;
        let mut index: u32 = 0;
        while index != size {{
            digest = DigestTrait::line(digest, a.line_to(DigestTrait::tile({width}, index)));
            index += 1;
        }}
        assert(digest == expected, 'line_to');
    }}
",
        cases_array("i32, i32, felt252", rows),
        width * height,
    )
}

/// The rows `(from, digest)` of the board's results from each `from` to every `to`.
fn board_rows(width: i64, height: i64, grid: &[bool], froms: &[i64]) -> Result<Vec<String>, String> {
    froms
        .iter()
        .map(|&from| {
            let mut digest = Digest::default();
            for to in 0..width * height {
                let line = board_line(width, height, from, to)?;
                digest.mask(&line.between);
                digest.option(line.approach);
                let sight = match &line.between {
                    Some(tiles) => tiles.iter().all(|&t| grid[t as usize]),
                    None => false,
                };
                digest.small(u128::from(sight));
            }
            Ok(format!("{from}, {}", digest.text()))
        })
        .collect()
}

fn board_body(rows: &[String], width: i64, height: i64, grid: &str) -> String {
    format!(
        "{}    let grid: felt252 = {grid};
    let map = HexMap {{ width: {width}, height: {height}, grid, seed: 0 }};
    for (from, expected) in cases {{
        let mut digest: felt252 = 0;
        let mut to: u8 = 0;
        while to != {} {{
            digest = DigestTrait::mask(digest, map.line(from, to));
            let approach = match map.approach(from, to) {{
                Some(direction) => Some(direction.into()),
                None => None,
            }};
            digest = DigestTrait::option(digest, approach);
            digest = DigestTrait::fold(digest, if map.line_of_sight(from, to) {{
                1
            }} else {{
                0
            }});
            to += 1;
        }}
        assert(digest == expected, 'board');
    }}
",
        cases_array("u8, felt252", rows),
        width * height,
    )
}

/// A seeded grid of the board: about two tiles in three walkable.
fn grid(seed: &str, size: i64) -> (Vec<bool>, String) {
    let mut rng = Rng::new(seed);
    let tiles: Vec<bool> = (0..size).map(|_| rng.next_i32(0, 2) != 0).collect();
    let (mut low, mut high) = (0u128, 0u128);
    for (i, &open) in tiles.iter().enumerate() {
        if open {
            if i < 128 {
                low |= 1 << i;
            } else {
                high |= 1 << (i - 128);
            }
        }
    }
    (tiles, felt((high, low)))
}

pub fn emit(spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    let chunks = spec.int("window_chunks")? as usize;
    let sample_pairs = spec.int("sample_pairs")? as usize;
    let sample_chunks = spec.int("sample_chunks")? as usize;
    let long = spec.int("long")?;
    let (min, max) = (spec.int("domain_min")? as i32, spec.int("domain_max")? as i32);

    let mut differences: Vec<Difference> = Vec::new();
    let mut counts: Vec<(&str, usize, usize)> = Vec::new();

    // The window 15 × 16 in the mirror frame: every ordered pair
    let window = board_hexes(15, 16);
    let mut pairs = 0;
    let before = differences.len();
    for &a in &window {
        for &b in &window {
            let line = checked(a, b)?;
            pairs += 1;
            if let Some(d) = compare("window 15 × 16", a, b, &line)? {
                if d.kind != Kind::Tie || !has_tie(&line) {
                    return Err(format!("hexx differs from the rule on a non-tie sample of the window: {a:?} -> {b:?}"));
                }
                differences.push(d);
            }
        }
    }
    counts.push(("window 15 × 16, every ordered pair", pairs, differences.len() - before));

    // A 7 × 7 board in the mirror frame: every ordered pair
    let small = board_hexes(7, 7);
    let before = differences.len();
    for &a in &small {
        for &b in &small {
            let line = checked(a, b)?;
            if let Some(d) = compare("board 7 × 7", a, b, &line)? {
                differences.push(d);
            }
        }
    }
    counts.push(("board 7 × 7, every ordered pair", small.len() * small.len(), differences.len() - before));

    // The seeded sample of [min, max]²: the first `sample_pairs` pairs without a tie
    let mut rng = Rng::new(&spec.text("seed")?);
    let mut sample: Vec<(Tile, Tile, Vec<Sample>)> = Vec::new();
    let mut drawn = 0;
    while sample.len() < sample_pairs {
        let a = (i64::from(rng.next_i32(min, max)), i64::from(rng.next_i32(min, max)));
        let b = (i64::from(rng.next_i32(min, max)), i64::from(rng.next_i32(min, max)));
        drawn += 1;
        let line = checked(a, b)?;
        if has_tie(&line) {
            continue;
        }
        if compare("seeded sample", a, b, &line)?.is_some() {
            return Err(format!("hexx differs from the rule on the non-tie seeded pair {a:?} -> {b:?}"));
        }
        sample.push((a, b, line));
    }
    counts.push(("seeded sample of `[-40, 40]²`, pairs without a tie", sample.len(), 0));
    let _ = drawn;

    // The adversarial pairs
    let adversarial: Vec<(Tile, Tile, Vec<Sample>)> = adversarial(long)
        .into_iter()
        .map(|(a, b)| checked(a, b).map(|line| (a, b, line)))
        .collect::<Result<_, _>>()?;
    let before = differences.len();
    for (a, b, line) in &adversarial {
        if let Some(d) = compare("adversarial", *a, *b, line)? {
            differences.push(d);
        }
    }
    counts.push(("adversarial, endpoints near `2^k`, `k = 20..=30`", adversarial.len(), differences.len() - before));

    // The golden file
    let mut e = Emitter::new(
        spec,
        "`Hex::line_to` (src/hex/mod.rs:903) where it is not a tie,\n// and the rule of plan §6.6 (tools/refgen/src/line.rs, `rule`) everywhere",
        USES,
    );
    e.out.push_str(HELPERS);
    let per_chunk = window.len().div_ceil(chunks);
    for (k, froms) in window.chunks(per_chunk).enumerate() {
        let rows = mirror_rows(&window, froms)?;
        e.test(&format!("golden_line_window_{k}"), false, &mirror_body(&rows, 15, 16))?;
    }
    let rows = mirror_rows(&small, &small)?;
    e.test("golden_line_mirror_7x7", false, &mirror_body(&rows, 7, 7))?;
    let per_chunk = sample.len().div_ceil(sample_chunks);
    for (k, pairs) in sample.chunks(per_chunk).enumerate() {
        let rows: Vec<String> = pairs
            .iter()
            .map(|(a, b, _)| {
                // Identity with hexx: the digest is that of hexx's own line
                let theirs = hexx_line(*a, *b).expect("checked above");
                let mut digest = Digest::default();
                digest.line(&theirs);
                format!("{}, {}, {}, {}, {}", a.0, a.1, b.0, b.1, digest.text())
            })
            .collect();
        e.test(&format!("golden_line_sample_{k}"), false, &pairs_body(&rows))?;
    }
    let rows: Vec<String> = adversarial
        .iter()
        .map(|(a, b, line)| {
            let tiles: Vec<Tile> = line.iter().map(|s| s.hex).collect();
            let mut digest = Digest::default();
            digest.line(&tiles);
            format!("{}, {}, {}, {}, {}", a.0, a.1, b.0, b.1, digest.text())
        })
        .collect();
    e.test("golden_line_adversarial", false, &pairs_body(&rows))?;

    // The board: from every `stride`-th position (every one by default) to every position, for
    // each board `<width>x<height>[:<stride>]/<tests>` of the spec
    let boards = spec.text("boards")?;
    for board in boards.split(',') {
        let (dims, parts) = board.trim().split_once('/').unwrap_or((board.trim(), "1"));
        let (dims, stride) = dims.split_once(':').unwrap_or((dims, "1"));
        let (w, h) = dims.split_once('x').ok_or(format!("bad board {board:?}"))?;
        let (w, h): (i64, i64) = (w.parse().map_err(|_| "bad width")?, h.parse().map_err(|_| "bad height")?);
        let parts: usize = parts.parse().map_err(|_| "bad parts")?;
        let stride: usize = stride.parse().map_err(|_| "bad stride")?;
        let (tiles, grid) = grid(&format!("line::grid::{w}x{h}"), w * h);
        let froms: Vec<i64> = (0..w * h).step_by(stride).collect();
        let per_part = froms.len().div_ceil(parts);
        for (k, froms) in froms.chunks(per_part).enumerate() {
            let rows = board_rows(w, h, &tiles, froms)?;
            let name = if parts == 1 { format!("golden_line_board_{w}x{h}") } else { format!("golden_line_board_{w}x{h}_{k}") };
            e.test(&name, false, &board_body(&rows, w, h, &grid))?;
        }
    }
    let golden = e.finish()?;

    // The table, in its region of line.cairo
    let source = root.join("crates/hexx/src/board/line.cairo");
    let current = fs::read_to_string(&source)
        .map_err(|err| format!("{}: {err}", source.display()))?
        .replace("\r\n", "\n");
    let source_text = with_region(&current, &table_region()?)?;

    let doc = deviations(&differences, &counts);
    Ok(vec![
        (crate::target(root, spec), golden),
        (source, source_text),
        (root.join("docs/deviations/line_ties.md"), doc),
    ])
}

fn pairs_body(rows: &[String]) -> String {
    format!(
        "{}    for (x1, y1, x2, y2, expected) in cases {{
        let line = HexTrait::new(x1, y1).line_to(HexTrait::new(x2, y2));
        assert(DigestTrait::line(0, line) == expected, 'line_to');
    }}
",
        cases_array("i32, i32, i32, i32, felt252", rows)
    )
}
