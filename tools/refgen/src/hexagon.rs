//! `hexagon`: the tables of plan §6.7 (N-6), range and ring as geometry. Three generated regions,
//! all checked by `-- check`:
//!
//! - `crates/hexx/src/board/tables.cairo`: the 16-row band `ROW_FROM_16` of the clip (§6.4).
//! - `crates/hexx/src/board/hexagon.cairo`, `tables`: `HEXAGONS` and `HEXAGON_RINGS`, the canonical
//!   shapes of the table path, re-centred on `(7, 8)` (even row) or `(7, 7)` (odd row) of the
//!   15 × 16 board, radius `1..=7`.
//! - `crates/hexx/src/board/hexagon.cairo`, `sights` (in its test module): `SIGHTS`, the
//!   hexagon of radius 6 of every position of 15 × 16, clipped to the board: the per-position
//!   variant of §6.7 ("Why not the flood"), measured in the benchmarks only, not shipped.
//!
//! Every shape is computed twice, by `hexx` 0.25.0 itself (`Hex::range`, `Hex::ring` on the `Hex`
//! of the tile, plan §3.5) and by the per-tile definition (`hex_distance(c, t) ≤ r`, `= r`); the
//! generator refuses to write anything when the two differ or when a canonical shape does not
//! lie whole in the 15 × 16 board.

use std::collections::BTreeSet;
use std::fmt::Write as _;
use std::fs;
use std::path::{Path, PathBuf};

use hexx::Hex;

use crate::line::{distance, felt, from_hex, pack, to_hex, Tile};
use crate::spec::Spec;

/// The board of the tables and the canonical centres, by row parity (plan §6.7, "Tables").
const WIDTH: i64 = 15;
const HEIGHT: i64 = 16;
const CENTRES: [Tile; 2] = [(7, 8), (7, 7)];
/// The radii of the table path.
const RADII: std::ops::RangeInclusive<i64> = 1..=7;
/// The radius of the per-position variant (the sight).
const SIGHT: i64 = 6;

/// A bitmap of the 15 × 16 board as `(high, low)` limbs.
type Bits = (u128, u128);

fn bits(tiles: &BTreeSet<Tile>) -> Bits {
    let mut value: Bits = (0, 0);
    for &(x, y) in tiles {
        let index = y * WIDTH + x;
        if index < 128 {
            value.1 |= 1 << index;
        } else {
            value.0 |= 1 << (index - 128);
        }
    }
    value
}

/// The tiles of 15 × 16 whose distance to `centre` satisfies `keep`: the per-tile definition.
fn by_definition(centre: Tile, keep: impl Fn(i64) -> bool) -> BTreeSet<Tile> {
    let mut tiles = BTreeSet::new();
    for y in 0..HEIGHT {
        for x in 0..WIDTH {
            if keep(distance(to_hex(centre), to_hex((x, y)))) {
                tiles.insert((x, y));
            }
        }
    }
    tiles
}

/// The tiles of `hexx`'s hexes, back on the board; an error when one leaves 15 × 16.
fn by_hexx(hexes: impl Iterator<Item = Hex>, what: &str) -> Result<BTreeSet<Tile>, String> {
    let mut tiles = BTreeSet::new();
    for hex in hexes {
        let (x, y) = from_hex((i64::from(hex.x), i64::from(hex.y)));
        if !(0..WIDTH).contains(&x) || !(0..HEIGHT).contains(&y) {
            return Err(format!("{what}: the tile ({x}, {y}) leaves the canonical 15 × 16 board"));
        }
        tiles.insert((x, y));
    }
    Ok(tiles)
}

fn hex_of(tile: Tile) -> Hex {
    let (x, y) = to_hex(tile);
    Hex::new(x as i32, y as i32)
}

/// `HEXAGONS` and `HEXAGON_RINGS`, key `7·parity + radius − 1`.
fn shapes() -> Result<(Vec<Bits>, Vec<Bits>), String> {
    let (mut hexagons, mut rings) = (Vec::new(), Vec::new());
    for &centre in &CENTRES {
        for radius in RADII {
            let what = format!("centre {centre:?}, radius {radius}");
            let hexagon = by_definition(centre, |d| d <= radius);
            let ring = by_definition(centre, |d| d == radius);
            if by_hexx(hex_of(centre).range(radius as u32), &what)? != hexagon {
                return Err(format!("{what}: hexx's range differs from the per-tile definition"));
            }
            if by_hexx(hex_of(centre).ring(radius as u32), &what)? != ring {
                return Err(format!("{what}: hexx's ring differs from the per-tile definition"));
            }
            hexagons.push(bits(&hexagon));
            rings.push(bits(&ring));
        }
    }
    Ok((hexagons, rings))
}

/// `SIGHTS`: the hexagon of radius 6 of every position, clipped to 15 × 16.
fn sights() -> Result<Vec<Bits>, String> {
    let mut sights = Vec::new();
    for position in 0..WIDTH * HEIGHT {
        let centre = (position % WIDTH, position / WIDTH);
        let tiles = by_definition(centre, |d| d <= SIGHT);
        let from_hexx: BTreeSet<Tile> = hex_of(centre)
            .range(SIGHT as u32)
            .map(|hex| from_hex((i64::from(hex.x), i64::from(hex.y))))
            .filter(|&(x, y)| (0..WIDTH).contains(&x) && (0..HEIGHT).contains(&y))
            .collect();
        if from_hexx != tiles {
            return Err(format!("position {position}: hexx's range differs from the per-tile definition"));
        }
        sights.push(bits(&tiles));
    }
    Ok(sights)
}

/// `ROW_FROM_16[k]`: the rows `[k, 16)` of the 16-row board at column 0, `k` in `0..=16`.
fn row_from_16() -> Vec<Bits> {
    (0..=HEIGHT)
        .map(|k| bits(&(k..HEIGHT).map(|row| (0, row)).collect()))
        .collect()
}

/// The two lines that open the region `name`, the second indented by `indent`.
fn begin(name: &str, indent: &str) -> String {
    format!("// region generated by `cargo run --manifest-path tools/refgen/Cargo.toml -- gen hexagon`:\n{indent}// {name}, do not edit")
}

const END: &str = "// endregion";

/// A region: its markers and `body` (lines without indentation), every line but the first indented
/// by `indent` (the first follows the indentation already in the file).
fn region(name: &str, indent: &str, body: &str) -> String {
    let mut out = begin(name, indent);
    out.push('\n');
    for line in body.lines() {
        if !line.is_empty() {
            out.push_str(indent);
            out.push_str(line);
        }
        out.push('\n');
    }
    out.push_str(indent);
    out.push_str(END);
    out
}

/// `current` with its region `name` replaced.
fn with_region(current: &str, file: &str, name: &str, indent: &str, region: &str) -> Result<String, String> {
    let marker = begin(name, indent);
    let start = current.find(&marker).ok_or(format!("{file}: no generated region {name} (BEGIN marker)"))?;
    let end = current[start..].find(END).ok_or(format!("{file}: no end of the generated region {name}"))? + start;
    Ok(format!("{}{}{}", &current[..start], region, &current[end + END.len()..]))
}

fn array(declaration: &str, values: &[Bits]) -> String {
    let items: Vec<String> = values.iter().map(|&v| felt(v)).collect();
    let mut out = format!("{declaration}: [felt252; {}] = [\n", items.len());
    out.push_str(&pack("    ", &items));
    out.push_str("];\n");
    out
}

fn tables_body() -> String {
    let mut out = String::from("\n");
    out.push_str("/// `ROW_FROM_16[k]`: the rows `[k, 16)` of the 16-row window at column 0,\n");
    out.push_str("/// `Σ_{j=k}^{15} 2^(15j)`, `k` in `0..=16`; entry 16 is 0. The clip of `board::hexagon`: the\n");
    out.push_str("/// rows `[lo, hi)` are `ROW_FROM_16[lo] − ROW_FROM_16[hi]`.\n");
    out.push_str(&array("pub const ROW_FROM_16", &row_from_16()));
    out.push('\n');
    out
}

fn shapes_body() -> Result<String, String> {
    let (hexagons, rings) = shapes()?;
    let mut out = String::from("\n");
    out.push_str("/// The canonical hexagons of the table path, key `7 · (row is odd) + radius − 1`, radius\n");
    out.push_str("/// `1..=7`: the tiles of the 15 × 16 board within `radius` of `(7, 8)` (index 127, even row)\n");
    out.push_str("/// or `(7, 7)` (index 112, odd row). Each lies whole in the board.\n");
    out.push_str(&array("const HEXAGONS", &hexagons));
    out.push_str("/// The canonical rings of the table path, the same keys: the tiles at exactly `radius`.\n");
    out.push_str(&array("const HEXAGON_RINGS", &rings));
    out.push('\n');
    Ok(out)
}

fn sights_body() -> Result<String, String> {
    let mut out = String::from("\n");
    out.push_str("/// The per-position variant of plan §6.7 (\"Why not the flood\"), not shipped: the\n");
    out.push_str("/// hexagon of radius 6 of every position of 15 × 16, clipped to the board.\n");
    // Packed at its final indentation (the region adds one level), so that the widths are those
    // `scarb fmt` sees
    let items: Vec<String> = sights()?.iter().map(|&v| felt(v)).collect();
    writeln!(out, "const SIGHTS: [felt252; {}] = [", items.len()).unwrap();
    for line in pack("        ", &items).lines() {
        writeln!(out, "{}", &line[4..]).unwrap();
    }
    out.push_str("];\n\n");
    Ok(out)
}

fn read(path: &Path, shown: &str) -> Result<String, String> {
    Ok(fs::read_to_string(path).map_err(|e| format!("{shown}: {e}"))?.replace("\r\n", "\n"))
}

pub fn emit(_spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    let tables = root.join("crates/hexx/src/board/tables.cairo");
    let current = read(&tables, "tables.cairo")?;
    let tables_text = with_region(&current, "tables.cairo", "bands", "", &region("bands", "", &tables_body()))?;

    let source = root.join("crates/hexx/src/board/hexagon.cairo");
    let current = read(&source, "hexagon.cairo")?;
    let text = with_region(&current, "hexagon.cairo", "tables", "", &region("tables", "", &shapes_body()?))?;
    // The test module's table, indented by one level
    let text = with_region(&text, "hexagon.cairo", "sights", "    ", &region("sights", "    ", &sights_body()?))?;

    Ok(vec![(tables, tables_text), (source, text)])
}
