//! `conversions`: `to_offset_coordinates` and `from_offset_coordinates` (`src/conversions.rs:65`,
//! `:142`) for the four (mode, orientation) pairs (plan §4.3).
//!
//! Inputs: `points` seeded hexes of `[domain_min, domain_max]²` through `to_offset_coordinates`
//! (each result converted back, which `hexx` promises to give the hex again), `points` seeded
//! offset coordinates of the same domain through `from_offset_coordinates` (independent of the
//! first table), then the `i32` values near the bounds on both functions: the cases where `hexx`
//! returns are golden values, the cases where it panics get a `#[should_panic]` test (at most
//! `panic_cap` per function and pair).

use hexx::{Hex, HexOrientation, OffsetHexMode};

use crate::cairo::{bound_points, cases_array, probe, seeded_points, spread, Emitter};
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
        "`Hex::to_offset_coordinates` (src/conversions.rs:65),\n// `Hex::from_offset_coordinates` :142, `OffsetHexMode` :29, `HexOrientation`\n// (src/orientation.rs:124)",
        "use hexx::conversions::{HexConversionsTrait, OffsetHexMode};\nuse hexx::hex::{Hex, HexTrait};\nuse hexx::orientation::HexOrientation;\n",
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
    e.finish()
}
