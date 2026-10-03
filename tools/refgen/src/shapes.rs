//! `shapes`: the six shapes of `hexx` (`src/shapes.rs`): `parallelogram` :45, `triangle` :95,
//! `hexagon` :144, `rombus` :186, `pointy_rectangle` :243, `flat_rectangle` :303, and the
//! `Default` of each struct (:18, :67, :118, :165, :216, :277).
//!
//! Each shape is generated at sizes `0..=radius_max` (spec) around eight centres or origins, the
//! rectangles with bounds that make `y >> 1` and `x >> 1` floor a negative odd value, the rombus
//! with `rows` or `columns` of 0, and the crossing bounds that give the empty span. A test holds
//! the parameters of its cases (`cases`) and the whole spans `hexx` returns for them, flattened
//! (`expected`, `x` then `y` per hex, case after case) with the length of each (`n`): every hex
//! of every span is compared. Odd chunks of a shape call the struct's `coords`, even chunks the
//! free function, so both are held to the same vectors.

use std::path::{Path, PathBuf};

use hexx::shapes::{
    flat_rectangle, hexagon, parallelogram, pointy_rectangle, rombus, triangle, FlatRectangle,
    Hexagon, Parallelogram, PointyRectangle, Rombus, Triangle,
};
use hexx::Hex;

use crate::cairo::Emitter;
use crate::spec::Spec;

/// The eight centres (or origins, or minima): odd and negative rows and columns, so that the
/// shift of a rectangle and the order of a span meet both signs.
const ANCHORS: [(i32, i32); 8] =
    [(0, 0), (1, 0), (0, 1), (-1, -1), (3, -7), (-5, 4), (-3, 0), (0, -3)];

/// One case: the parameters as the Cairo tuple holds them, and the span `hexx` returns, read
/// to the end by iteration (never by `len`, which `hexx` computes from the bounds even when they
/// cross).
struct Case {
    params: Vec<i64>,
    hexes: Vec<Hex>,
}

fn collect(iter: impl Iterator<Item = Hex>) -> Vec<Hex> {
    let mut hexes = Vec::new();
    for hex in iter {
        hexes.push(hex);
    }
    hexes
}

fn hexagons(radius_max: u32) -> Vec<Case> {
    let mut cases = Vec::new();
    for (x, y) in ANCHORS {
        for radius in 0..=radius_max {
            let hexes = collect(hexagon(Hex::new(x, y), radius));
            cases.push(Case { params: vec![x.into(), y.into(), radius.into()], hexes });
        }
    }
    cases
}

fn parallelograms(radius_max: u32) -> Vec<Case> {
    let mut cases = Vec::new();
    let max = radius_max as i32;
    let mut add = |(x, y): (i32, i32), (dx, dy): (i32, i32)| {
        let (min, top) = (Hex::new(x, y), Hex::new(x + dx, y + dy));
        let hexes = collect(parallelogram(min, top));
        cases.push(Case {
            params: vec![x.into(), y.into(), (x + dx).into(), (y + dy).into()],
            hexes,
        });
    };
    for anchor in ANCHORS {
        for n in 0..=max {
            add(anchor, (n, n));
        }
        for n in 0..=max {
            add(anchor, (n, max - n));
        }
    }
    // The bounds cross: the empty span.
    add((3, 0), (-2, 5));
    add((0, 3), (5, -2));
    cases
}

fn triangles(size_max: u32) -> Vec<Case> {
    (0..=size_max)
        .map(|size| Case { params: vec![size.into()], hexes: collect(triangle(size)) })
        .collect()
}

fn rombuses(radius_max: u32) -> Vec<Case> {
    let mut cases = Vec::new();
    for (x, y) in ANCHORS {
        for n in 0..=radius_max {
            for (rows, columns) in [(n, n), (n, radius_max - n)] {
                let hexes = collect(rombus(Hex::new(x, y), rows, columns));
                cases.push(Case {
                    params: vec![x.into(), y.into(), rows.into(), columns.into()],
                    hexes,
                });
            }
        }
    }
    cases
}

/// The bounds `[left, right, top, bottom]` of a rectangle case: width and height `n` and
/// `radius_max − n` from an anchor `(left, top)`, and the crossing bounds.
fn rectangle_bounds(radius_max: u32) -> Vec<[i32; 4]> {
    let max = radius_max as i32;
    let mut all = Vec::new();
    for (left, top) in ANCHORS {
        for n in 0..=max {
            all.push([left, left + n, top, top + max - n]);
        }
    }
    // `right < left`, `bottom < top`, and both: the empty span.
    all.push([3, 1, 0, 2]);
    all.push([0, 2, 3, 1]);
    all.push([3, 1, 3, 1]);
    all
}

fn rectangles(radius_max: u32, flat: bool) -> Vec<Case> {
    rectangle_bounds(radius_max)
        .into_iter()
        .map(|b| {
            let hexes = if flat { collect(flat_rectangle(b)) } else { collect(pointy_rectangle(b)) };
            Case { params: b.iter().map(|&v| i64::from(v)).collect(), hexes }
        })
        .collect()
}

/// The `Default` of each struct: the fields and the whole `coords`.
struct Defaults {
    parallelogram: Parallelogram,
    triangle: Triangle,
    hexagon: Hexagon,
    rombus: Rombus,
    pointy: PointyRectangle,
    flat: FlatRectangle,
}

/// The lines of the flattened `expected` array of `cases`, `values per line` packed to 100
/// columns as `scarb fmt` packs a list.
fn packed(values: &[i64], indent: usize) -> String {
    let mut out = String::new();
    let mut line = String::new();
    for v in values {
        let item = format!("{v},");
        if line.is_empty() {
            line = format!("{}{item}", " ".repeat(indent));
        } else if line.len() + 1 + item.len() <= 100 {
            line.push_str(&format!(" {item}"));
        } else {
            out.push_str(&line);
            out.push('\n');
            line = format!("{}{item}", " ".repeat(indent));
        }
    }
    if !line.is_empty() {
        out.push_str(&line);
        out.push('\n');
    }
    out
}

/// One shape's tests. `types` is the Cairo type of the parameters of a case, `vars` their names;
/// `call` builds the span from them (`free`) or through the struct's `coords` (`method`).
struct Shape {
    name: &'static str,
    types: &'static str,
    vars: &'static str,
    free: &'static str,
    method: &'static str,
}

/// The cases packed `per_line` to a line (as `cases_array` of the other generators does).
fn cases_literal(types: &str, cases: &[&Case]) -> String {
    let rows: Vec<String> = cases
        .iter()
        .map(|c| {
            let mut row: Vec<String> = c.params.iter().map(i64::to_string).collect();
            row.push(c.hexes.len().to_string());
            format!("({})", row.join(", "))
        })
        .collect();
    let one = format!("    let cases: Array<({types}, u32)> = array![{}];\n", rows.join(", "));
    if one.len() <= 101 {
        return one;
    }
    let mut out = format!("    let cases: Array<({types}, u32)> = array![\n");
    let mut line = String::new();
    for item in rows {
        if line.is_empty() {
            line = format!("        {item},");
        } else if line.len() + 1 + item.len() + 1 <= 100 {
            line.push_str(&format!(" {item},"));
        } else {
            out.push_str(&line);
            out.push('\n');
            line = format!("        {item},");
        }
    }
    if !line.is_empty() {
        out.push_str(&line);
        out.push('\n');
    }
    out.push_str("    ];\n");
    out
}

fn emit_shape(
    e: &mut Emitter,
    shape: &Shape,
    cases: &[Case],
    per_test: usize,
) -> Result<(), String> {
    // Greedy chunks: a test holds whole cases, up to `per_test` hexes (at least one case).
    let mut chunks: Vec<Vec<&Case>> = Vec::new();
    let mut size = 0;
    for case in cases {
        if chunks.last().is_none() || size + case.hexes.len() > per_test {
            chunks.push(Vec::new());
            size = 0;
        }
        chunks.last_mut().unwrap().push(case);
        size += case.hexes.len();
    }
    for (index, chunk) in chunks.iter().enumerate() {
        let name = format!("golden_shapes_{}_{index}", shape.name);
        let flat: Vec<i64> = chunk
            .iter()
            .flat_map(|c| c.hexes.iter().flat_map(|h| [i64::from(h.x), i64::from(h.y)]))
            .collect();
        let call = if index % 2 == 0 { shape.free } else { shape.method };
        let mut body = cases_literal(shape.types, chunk);
        if flat.is_empty() {
            body.push_str("    let expected: Array<i32> = array![];\n");
        } else {
            body.push_str("    let expected: Array<i32> = array![\n");
            body.push_str(&packed(&flat, 8));
            body.push_str("    ];\n");
        }
        body.push_str("    let mut k = 0;\n    let mut i = 0;\n");
        body.push_str("    while i < cases.len() {\n");
        body.push_str(&format!("        let ({}, n) = *cases.at(i);\n", shape.vars));
        body.push_str(&format!("        let span = {call};\n"));
        body.push_str("        assert(span.len() == n, 'length');\n");
        body.push_str("        let mut j = 0;\n        while j < n {\n");
        body.push_str("            let h = *span.at(j);\n");
        body.push_str("            assert(h.x == *expected.at(k), 'x');\n");
        body.push_str("            assert(h.y == *expected.at(k + 1), 'y');\n");
        body.push_str("            k += 2;\n            j += 1;\n        }\n");
        body.push_str("        i += 1;\n    }\n");
        body.push_str("    assert(k == expected.len(), 'total');\n");
        e.test(&name, false, &body)?;
    }
    Ok(())
}

/// The `Default` test: each struct's fields against `hexx`'s, and its `coords` hex by hex.
fn emit_defaults(e: &mut Emitter, d: &Defaults) -> Result<(), String> {
    let mut body = String::new();
    let mut check = |ty: &str, var: &str, literal: String, coords: Vec<Hex>| {
        body.push_str(&format!("    let {var}: {ty} = Default::default();\n"));
        let one = format!("    assert({var} == {literal}, '{var}');\n");
        if one.len() <= 101 {
            body.push_str(&one);
        } else {
            body.push_str(&format!("    assert(\n        {var} == {literal},\n        '{var}',\n    );\n"));
        }
        let flat: Vec<i64> =
            coords.iter().flat_map(|h| [i64::from(h.x), i64::from(h.y)]).collect();
        body.push_str(&format!("    let {var}_expected: Array<i32> = array![\n"));
        body.push_str(&packed(&flat, 8));
        body.push_str("    ];\n");
        body.push_str(&format!("    let {var}_span = {var}.coords();\n"));
        body.push_str(&format!("    assert({var}_span.len() * 2 == {var}_expected.len(), '{var}_length');\n"));
        body.push_str("    let mut j = 0;\n");
        body.push_str(&format!("    while j < {var}_span.len() {{\n"));
        body.push_str(&format!("        let h = *{var}_span.at(j);\n"));
        body.push_str(&format!("        assert(h.x == *{var}_expected.at(2 * j), '{var}_x');\n"));
        body.push_str(&format!("        assert(h.y == *{var}_expected.at(2 * j + 1), '{var}_y');\n"));
        body.push_str("        j += 1;\n    }\n");
    };
    let (pmin, pmax) = (d.parallelogram.min, d.parallelogram.max);
    check(
        "Parallelogram",
        "parallelogram",
        format!(
            "Parallelogram {{ min: HexTrait::new({}, {}), max: HexTrait::new({}, {}) }}",
            pmin.x, pmin.y, pmax.x, pmax.y
        ),
        collect(d.parallelogram.coords()),
    );
    check(
        "Triangle",
        "triangle",
        format!("Triangle {{ size: {} }}", d.triangle.size),
        collect(d.triangle.coords()),
    );
    check(
        "Hexagon",
        "hexagon",
        format!(
            "Hexagon {{ center: HexTrait::new({}, {}), radius: {} }}",
            d.hexagon.center.x, d.hexagon.center.y, d.hexagon.radius
        ),
        collect(d.hexagon.coords()),
    );
    check(
        "Rombus",
        "rombus",
        format!(
            "Rombus {{ origin: HexTrait::new({}, {}), rows: {}, columns: {} }}",
            d.rombus.origin.x, d.rombus.origin.y, d.rombus.rows, d.rombus.columns
        ),
        collect(d.rombus.coords()),
    );
    check(
        "PointyRectangle",
        "pointy",
        format!(
            "PointyRectangle {{ left: {}, right: {}, top: {}, bottom: {} }}",
            d.pointy.left, d.pointy.right, d.pointy.top, d.pointy.bottom
        ),
        collect(d.pointy.coords()),
    );
    check(
        "FlatRectangle",
        "flat",
        format!(
            "FlatRectangle {{ left: {}, right: {}, top: {}, bottom: {} }}",
            d.flat.left, d.flat.right, d.flat.top, d.flat.bottom
        ),
        collect(d.flat.coords()),
    );
    e.test("golden_shapes_default", false, &body)
}

pub fn emit(spec: &Spec, root: &Path) -> Result<Vec<(PathBuf, String)>, String> {
    let radius_max = spec.int("radius_max")? as u32;
    let triangle_max = spec.int("triangle_max")? as u32;
    let per_test = spec.int("hexes_per_test")? as usize;
    let mut e = Emitter::new(
        spec,
        "the shapes of `src/shapes.rs`, `parallelogram` :45, `triangle` :95,\n// `hexagon` :144, `rombus` :186, `pointy_rectangle` :243, `flat_rectangle` :303 and the `Default`\n// of each struct",
        "use hexx::hex::{Hex, HexTrait};\nuse hexx::shapes::{\n    FlatRectangle, FlatRectangleTrait, Hexagon, HexagonTrait, Parallelogram, ParallelogramTrait,\n    PointyRectangle, PointyRectangleTrait, Rombus, RombusTrait, Triangle, TriangleTrait,\n    flat_rectangle, hexagon, parallelogram, pointy_rectangle, rombus, triangle,\n};\n",
    );
    let shapes = [
        (
            Shape {
                name: "hexagon",
                types: "i32, i32, u32",
                vars: "cx, cy, r",
                free: "hexagon(HexTrait::new(cx, cy), r)",
                method: "Hexagon { center: HexTrait::new(cx, cy), radius: r }.coords()",
            },
            hexagons(radius_max),
        ),
        (
            Shape {
                name: "parallelogram",
                types: "i32, i32, i32, i32",
                vars: "ax, ay, bx, by",
                free: "parallelogram(HexTrait::new(ax, ay), HexTrait::new(bx, by))",
                method: "ParallelogramTrait::new(HexTrait::new(ax, ay), HexTrait::new(bx, by)).coords()",
            },
            parallelograms(radius_max),
        ),
        (
            Shape {
                name: "triangle",
                types: "u32",
                vars: "size",
                free: "triangle(size)",
                method: "TriangleTrait::new(size).coords()",
            },
            triangles(triangle_max),
        ),
        (
            Shape {
                name: "rombus",
                types: "i32, i32, u32, u32",
                vars: "ox, oy, rows, columns",
                free: "rombus(HexTrait::new(ox, oy), rows, columns)",
                method: "Rombus { origin: HexTrait::new(ox, oy), rows, columns }.coords()",
            },
            rombuses(radius_max),
        ),
        (
            Shape {
                name: "pointy_rectangle",
                types: "i32, i32, i32, i32",
                vars: "left, right, top, bottom",
                free: "pointy_rectangle([left, right, top, bottom])",
                method: "PointyRectangle { left, right, top, bottom }.coords()",
            },
            rectangles(radius_max, false),
        ),
        (
            Shape {
                name: "flat_rectangle",
                types: "i32, i32, i32, i32",
                vars: "left, right, top, bottom",
                free: "flat_rectangle([left, right, top, bottom])",
                method: "FlatRectangle { left, right, top, bottom }.coords()",
            },
            rectangles(radius_max, true),
        ),
    ];
    for (shape, cases) in &shapes {
        emit_shape(&mut e, shape, cases, per_test)?;
    }
    emit_defaults(
        &mut e,
        &Defaults {
            parallelogram: Parallelogram::default(),
            triangle: Triangle::default(),
            hexagon: Hexagon::default(),
            rombus: Rombus::default(),
            pointy: PointyRectangle::default(),
            flat: FlatRectangle::default(),
        },
    )?;
    let golden = crate::target(root, spec);
    Ok(vec![(golden, e.finish()?)])
}
