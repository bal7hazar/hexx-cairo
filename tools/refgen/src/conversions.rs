//! `conversions`: `to_offset_coordinates` and `from_offset_coordinates` (`src/conversions.rs:65`,
//! `:142`) for the four (mode, orientation) pairs (plan §4.3).
//!
//! Inputs: `points` seeded hexes of `[domain_min, domain_max]²` through `to_offset_coordinates`
//! (each result converted back, which `hexx` promises to give the hex again), `points` seeded
//! offset coordinates of the same domain through `from_offset_coordinates` (independent of the
//! first table), then the `i32` values near the bounds on both functions: the cases where `hexx`
//! returns are golden values, the cases where it panics get a `#[should_panic]` test (at most
//! `panic_cap` per function and pair).
//!
//! L-M2 (brief LIB-06 M2-T3): `to_doubled_coordinates` and `from_doubled_coordinates` (`:50`,
//! `:128`) for both `DoubledHexMode`s on the same seeded hexes (with the round trip) and seeded
//! pairs (most of them not valid doubled coordinates: the truncating division of `hexx`), then
//! near the bounds; `to_hexmod_coordinates` and `from_hexmod_coordinates` (`:92`, `:110`) at every
//! radius `1..=hexmod_max`: every `coord` of `0..range_count` (with the round trip) and the seeded
//! hexes (outside the hexagon they wrap), then near the bounds.

use hexx::conversions::DoubledHexMode;
use hexx::{Hex, HexOrientation, OffsetHexMode};

use crate::cairo::{bound_points, cases_array, probe, seeded_points, spread, Emitter};
use crate::impls::{fun_tables, hex_row, hx, pair, Fun};
use crate::spec::Spec;

const MODES: [(&str, OffsetHexMode); 2] = [("even", OffsetHexMode::Even), ("odd", OffsetHexMode::Odd)];
const ORIENTATIONS: [(&str, HexOrientation); 2] =
    [("pointy", HexOrientation::Pointy), ("flat", HexOrientation::Flat)];

fn cairo_mode(name: &str) -> &'static str {
    if name == "even" {
        "OffsetHexMode::Even"
    } else {
        "OffsetHexMode::Odd"
    }
}

fn cairo_orientation(name: &str) -> &'static str {
    if name == "pointy" {
        "HexOrientation::Pointy"
    } else {
        "HexOrientation::Flat"
    }
}

pub fn emit(spec: &Spec) -> Result<String, String> {
    let (min, max) = (spec.int("domain_min")? as i32, spec.int("domain_max")? as i32);
    let count = spec.int("points")? as usize;
    let panic_cap = spec.int("panic_cap")? as usize;
    let hexes = seeded_points(&spec.text("seed_hex")?, count, min, max);
    let offsets = seeded_points(&spec.text("seed_offset")?, count, min, max);
    let bounds = bound_points();

    let mut e = Emitter::new(
        spec,
        "`Hex::to_offset_coordinates` (src/conversions.rs:65),\n// `Hex::from_offset_coordinates` :142, `OffsetHexMode` :29, `HexOrientation`\n// (src/orientation.rs:124); `to_doubled_coordinates` :50, `from_doubled_coordinates` :128,\n// `DoubledHexMode` :12, `to_hexmod_coordinates` :92, `from_hexmod_coordinates` :110",
        "use hexx::conversions::{DoubledHexMode, HexConversionsTrait, OffsetHexMode};\nuse hexx::hex::{Hex, HexTrait};\nuse hexx::orientation::HexOrientation;\n",
    );

    for (mode_name, mode) in MODES {
        for (orientation_name, orientation) in ORIENTATIONS {
            let pair = format!("{mode_name}_{orientation_name}");
            let (cm, co) = (cairo_mode(mode_name), cairo_orientation(orientation_name));

            // to_offset_coordinates on the seeded hexes, with the round trip.
            let to_rows: Vec<String> = hexes
                .iter()
                .map(|&(x, y)| {
                    let h = Hex::new(x, y);
                    let [col, row] = h.to_offset_coordinates(mode, orientation);
                    assert_eq!(Hex::from_offset_coordinates([col, row], mode, orientation), h);
                    format!("{x}, {y}, {col}, {row}")
                })
                .collect();
            // from_offset_coordinates on independent seeded offsets.
            let from_rows: Vec<String> = offsets
                .iter()
                .map(|&(col, row)| {
                    let h = Hex::from_offset_coordinates([col, row], mode, orientation);
                    format!("{col}, {row}, {}, {}", h.x, h.y)
                })
                .collect();
            let setup = format!(
                "    let mode = {cm};\n    let orientation = {co};\n"
            );
            let body = format!(
                "{setup}{}    let mut i = 0;
    while i < cases.len() {{
        let (x, y, col, row) = *cases.at(i);
        let h = HexTrait::new(x, y);
        assert(h.to_offset_coordinates(mode, orientation) == [col, row], 'to_offset');
        let back = HexConversionsTrait::from_offset_coordinates([col, row], mode, orientation);
        assert(back == h, 'round trip');
        i += 1;
    }}
{}    let mut i = 0;
    while i < from_cases.len() {{
        let (col, row, x, y) = *from_cases.at(i);
        let h = HexConversionsTrait::from_offset_coordinates([col, row], mode, orientation);
        assert(h == HexTrait::new(x, y), 'from_offset');
        i += 1;
    }}
",
                cases_array("i32, i32, i32, i32", &to_rows),
                cases_array("i32, i32, i32, i32", &from_rows).replace("let cases", "let from_cases"),
            );
            e.test(&format!("golden_offset_{pair}"), false, &body)?;

            // Near the bounds.
            let mut to_ok = Vec::new();
            let mut to_failing = Vec::new();
            let mut from_ok = Vec::new();
            let mut from_failing = Vec::new();
            for &(x, y) in &bounds {
                match probe(|| Hex::new(x, y).to_offset_coordinates(mode, orientation)) {
                    Some([col, row]) => to_ok.push(format!("{x}, {y}, {col}, {row}")),
                    None => to_failing.push((x, y)),
                }
                match probe(|| Hex::from_offset_coordinates([x, y], mode, orientation)) {
                    Some(h) => from_ok.push(format!("{x}, {y}, {}, {}", h.x, h.y)),
                    None => from_failing.push((x, y)),
                }
            }
            let body = format!(
                "{setup}{}    let mut i = 0;
    while i < cases.len() {{
        let (x, y, col, row) = *cases.at(i);
        let h = HexTrait::new(x, y);
        assert(h.to_offset_coordinates(mode, orientation) == [col, row], 'to_offset');
        i += 1;
    }}
",
                cases_array("i32, i32, i32, i32", &to_ok)
            );
            e.test(&format!("golden_offset_bounds_to_{pair}"), false, &body)?;
            let body = format!(
                "{setup}{}    let mut i = 0;
    while i < cases.len() {{
        let (col, row, x, y) = *cases.at(i);
        let h = HexConversionsTrait::from_offset_coordinates([col, row], mode, orientation);
        assert(h == HexTrait::new(x, y), 'from_offset');
        i += 1;
    }}
",
                cases_array("i32, i32, i32, i32", &from_ok)
            );
            e.test(&format!("golden_offset_bounds_from_{pair}"), false, &body)?;

            for (n, (x, y)) in spread(&to_failing, panic_cap).into_iter().enumerate() {
                let body = format!(
                    "{setup}    let _ = HexTrait::new({x}, {y}).to_offset_coordinates(mode, orientation);\n"
                );
                e.test(&format!("golden_offset_to_{pair}_panics_{n}"), true, &body)?;
            }
            for (n, (x, y)) in spread(&from_failing, panic_cap).into_iter().enumerate() {
                let body = format!(
                    "{setup}    let offset = [{x}, {y}];\n    let _ = HexConversionsTrait::from_offset_coordinates(offset, mode, orientation);\n"
                );
                e.test(&format!("golden_offset_from_{pair}_panics_{n}"), true, &body)?;
            }
            if to_failing.is_empty() || from_failing.is_empty() {
                return Err(format!("no bound value makes hexx panic for {pair}"));
            }
        }
    }
    emit_l_m2(&mut e, spec, &hexes, &offsets, &bounds, panic_cap)?;
    e.finish()
}

fn doubled_row(p: ((i32, i32), usize)) -> String {
    format!("{}, {}", hex_row(p.0), p.1)
}

const DOUBLED_MODES: [DoubledHexMode; 2] = [DoubledHexMode::DoubledWidth, DoubledHexMode::DoubledHeight];

/// The doubled conversions; the row's `m` is the mode, `0` for `DoubledWidth`, `1` for
/// `DoubledHeight`.
const DOUBLED: [Fun<((i32, i32), usize)>; 2] = [
    Fun {
        name: "to_doubled",
        types: "i32, i32, u8",
        vars: "x, y, m",
        setup: "        let mode = if m == 0 {
            DoubledHexMode::DoubledWidth
        } else {
            DoubledHexMode::DoubledHeight
        };
        let h = HexTrait::new(x, y);
",
        call: "h.to_doubled_coordinates(mode)",
        out_types: "i32, i32",
        out_vars: "col, row",
        expected: "[col, row]",
        eval: |p| {
            probe(|| hx(p.0).to_doubled_coordinates(DOUBLED_MODES[p.1])).map(|[c, r]| {
                // The round trip `hexx` promises on its image
                assert_eq!(Hex::from_doubled_coordinates([c, r], DOUBLED_MODES[p.1]), hx(p.0));
                vec![c.to_string(), r.to_string()]
            })
        },
        row: doubled_row,
    },
    Fun {
        name: "from_doubled",
        types: "i32, i32, u8",
        vars: "col, row, m",
        setup: "        let mode = if m == 0 {
            DoubledHexMode::DoubledWidth
        } else {
            DoubledHexMode::DoubledHeight
        };
        let h = HexConversionsTrait::from_doubled_coordinates([col, row], mode);
",
        call: "h",
        out_types: "i32, i32",
        out_vars: "ex, ey",
        expected: "HexTrait::new(ex, ey)",
        eval: |p| probe(|| Hex::from_doubled_coordinates([(p.0).0, (p.0).1], DOUBLED_MODES[p.1])).map(pair),
        row: doubled_row,
    },
];

fn hexmod_row(p: ((i32, i32), u32)) -> String {
    format!("{}, {}", hex_row(p.0), p.1)
}

const TO_HEXMOD: [Fun<((i32, i32), u32)>; 1] = [Fun {
    name: "to_hexmod",
    types: "i32, i32, u32",
    vars: "x, y, r",
    setup: "        let h = HexTrait::new(x, y);\n",
    call: "h.to_hexmod_coordinates(r)",
    out_types: "u32",
    out_vars: "e",
    expected: "e",
    eval: |p| probe(|| hx(p.0).to_hexmod_coordinates(p.1)).map(|v| vec![v.to_string()]),
    row: hexmod_row,
}];

const FROM_HEXMOD: [Fun<(u32, u32)>; 1] = [Fun {
    name: "from_hexmod",
    types: "u32, u32",
    vars: "c, r",
    setup: "        let h = HexConversionsTrait::from_hexmod_coordinates(c, r);\n",
    call: "h",
    out_types: "i32, i32",
    out_vars: "ex, ey",
    expected: "HexTrait::new(ex, ey)",
    eval: |p| probe(|| Hex::from_hexmod_coordinates(p.0, p.1)).map(pair),
    row: |p| format!("{}, {}", p.0, p.1),
}];

fn emit_l_m2(
    e: &mut Emitter,
    spec: &Spec,
    hexes: &[(i32, i32)],
    offsets: &[(i32, i32)],
    bounds: &[(i32, i32)],
    panic_cap: usize,
) -> Result<(), String> {
    // `Default` of `DoubledHexMode` is `DoubledWidth` (`:14`).
    if DoubledHexMode::default() != DoubledHexMode::DoubledWidth {
        return Err("DoubledHexMode::default".into());
    }
    let body = "    let mode: DoubledHexMode = Default::default();\n    assert(mode == DoubledHexMode::DoubledWidth, 'default');\n";
    e.test("golden_doubled_default", false, body)?;
    let modes = |points: &[(i32, i32)]| -> Vec<((i32, i32), usize)> {
        points.iter().flat_map(|&p| (0..2).map(move |m| (p, m))).collect()
    };
    fun_tables(e, "conversions", "seeded", &modes(hexes), &DOUBLED[..1], None)?;
    fun_tables(e, "conversions", "seeded", &modes(offsets), &DOUBLED[1..], None)?;
    fun_tables(e, "conversions", "bounds", &modes(bounds), &DOUBLED, Some(panic_cap))?;

    // hexmod: every index of every radius, with the round trip.
    let max = spec.int("hexmod_max")? as u32;
    let mut rows = Vec::new();
    for range in 1..=max {
        for coord in 0..Hex::range_count(range) {
            let h = Hex::from_hexmod_coordinates(coord, range);
            if h.to_hexmod_coordinates(range) != coord || h.ulength() > range {
                return Err(format!("hexmod: no round trip at {coord}, radius {range}"));
            }
            rows.push((coord, range));
        }
    }
    fun_tables(e, "conversions", "every", &rows, &FROM_HEXMOD, None)?;
    let body = "    let mut r: u32 = 1;
    while r <= 6 {
        let mut c: u32 = 0;
        while c < HexTrait::range_count(r) {
            let h = HexConversionsTrait::from_hexmod_coordinates(c, r);
            assert(h.to_hexmod_coordinates(r) == c, 'round trip');
            c += 1;
        }
        r += 1;
    }
";
    if max != 6 {
        return Err("specs/conversions.toml: the round trip test is written for hexmod_max = 6".into());
    }
    e.test("golden_hexmod_round_trip", false, body)?;
    let seeded: Vec<((i32, i32), u32)> =
        hexes.iter().flat_map(|&p| (1..=max).map(move |r| (p, r))).collect();
    fun_tables(e, "conversions", "seeded", &seeded, &TO_HEXMOD, None)?;
    // Near the bounds: `y + shift·x` leaves `i32` (both panic); `coord + range` leaves `i32`.
    let bound_hexmod: Vec<((i32, i32), u32)> =
        bounds.iter().flat_map(|&p| [1, max].into_iter().map(move |r| (p, r))).collect();
    fun_tables(e, "conversions", "bounds", &bound_hexmod, &TO_HEXMOD, Some(panic_cap))?;
    let i32_max = i32::MAX as u32;
    let bound_coords: Vec<(u32, u32)> = [0, 1, i32_max - 13, i32_max - 12, i32_max - 2, i32_max]
        .into_iter()
        .flat_map(|c| [1, max].into_iter().map(move |r| (c, r)))
        .collect();
    fun_tables(e, "conversions", "bounds", &bound_coords, &FROM_HEXMOD, Some(panic_cap))?;
    // `range = 0` (`shift = 2`), and `shift(range) = 3 * range + 2` at and above `i32::MAX`:
    // `715827881` is the largest range whose shift fits, `715827882` has `shift = 2^31` (`as i32`
    // wraps to `i32::MIN`, then `shift - 1` overflows), `1431655764` has `shift = 2^32 - 2`, and
    // `1431655765` overflows `3 * range + 2` itself. Every panicking pair gets its own test.
    let shifts: Vec<(u32, u32)> = [0, 12]
        .into_iter()
        .flat_map(|c| [0, 715_827_881, 715_827_882, 1_431_655_764, 1_431_655_765].into_iter().map(move |r| (c, r)))
        .collect();
    fun_tables(e, "conversions", "shift", &shifts, &FROM_HEXMOD, Some(shifts.len()))?;
    Ok(())
}
