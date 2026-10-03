//! `shapes`: the coordinates of the six shapes of `hexx` (`src/shapes.rs`), each a struct whose
//! `coords` returns a `Span<Hex>` and a free function of the same module: `parallelogram`,
//! `triangle`, `hexagon`, `rombus`, `pointy_rectangle`, `flat_rectangle`.
//!
//! Every span is in the order of `hexx`, empty shapes included. `shapes::hexagon` is the
//! coordinate form of the board's bitmap `HexagonTrait::hexagon` (plan §2.4, §6.7): the same
//! geometric meaning, different types.

// Internal imports

use crate::hex::{Hex, HexTrait};

// region parallelogram

/// A parallelogram: every `(x, y)` with `min.x ≤ x ≤ max.x` and `min.y ≤ y ≤ max.y`.
///
/// Mirrors `hexx::shapes::Parallelogram` (`src/shapes.rs:11`), with its public fields.
///
/// #### Panics
///
/// None: a struct holds any pair of `Hex`.
///
/// #### Deviations
///
/// Derives `Serde` and `PartialEq` as a matter of course (plan §2.3); `Debug` is that of its
/// fields; `hexx` derives `Debug`, `Clone` and `Copy`.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct Parallelogram {
    pub min: Hex,
    pub max: Hex,
}

/// The value of `hexx`'s `Default`: `min` and `max` at `-10` and `10` on both axes.
///
/// Mirrors `impl Default for Parallelogram` (`src/shapes.rs:18`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// None.
pub impl ParallelogramDefault of Default<Parallelogram> {
    fn default() -> Parallelogram {
        Parallelogram { min: HexTrait::splat(-10), max: HexTrait::splat(10) }
    }
}

/// The items of `impl Parallelogram` (`src/shapes.rs:27`).
pub trait ParallelogramTrait {
    /// A parallelogram of the box `min..=max`.
    ///
    /// Mirrors `Parallelogram::new` (`src/shapes.rs:31`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn new(min: Hex, max: Hex) -> Parallelogram;

    /// The coordinates of the parallelogram, `x` ascending then `y` ascending; empty when
    /// `max.x < min.x` or `max.y < min.y`.
    ///
    /// Mirrors `Parallelogram::coords` (`src/shapes.rs:37`).
    ///
    /// #### Panics
    ///
    /// None for any bounds a span can hold: a span of more than a few thousand hexes runs out of
    /// gas first.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`.
    fn coords(self: Parallelogram) -> Span<Hex>;
}

pub impl ParallelogramImpl of ParallelogramTrait {
    #[inline]
    fn new(min: Hex, max: Hex) -> Parallelogram {
        Parallelogram { min, max }
    }

    #[inline]
    fn coords(self: Parallelogram) -> Span<Hex> {
        parallelogram(self.min, self.max)
    }
}

/// The coordinates of the parallelogram `min..=max`, `x` ascending then `y` ascending; empty when
/// `max.x < min.x` or `max.y < min.y`.
///
/// A free function, by decision of the brief of M2-T6: it mirrors the free function of
/// `hexx::shapes` at the same path (`hexx::shapes::parallelogram`), and the mirror keeps `hexx`'s
/// names and paths (principle 8). It would move to a `ShapesTrait` if the orchestrator ruled that
/// D-143 wants it on a trait; the parity map would then need an entry.
///
/// Mirrors `hexx::shapes::parallelogram` (`src/shapes.rs:45`).
///
/// #### Panics
///
/// None for any bounds a span can hold: a span of more than a few thousand hexes runs out of gas
/// first.
///
/// #### Deviations
///
/// A `Span<Hex>` instead of an `ExactSizeIterator`. The loops stop at the bound without stepping
/// past it, so a bound of `i32::MAX` is served, as in `hexx`.
pub fn parallelogram(min: Hex, max: Hex) -> Span<Hex> {
    let mut out = array![];
    if max.x < min.x || max.y < min.y {
        return out.span();
    }
    let mut x = min.x;
    loop {
        let mut y = min.y;
        loop {
            out.append(Hex { x, y });
            if y == max.y {
                break;
            }
            y += 1;
        }
        if x == max.x {
            break;
        }
        x += 1;
    }
    out.span()
}

// endregion

// region triangle

/// A triangle: every `(x, y)` with `x ≥ 0`, `y ≥ 0` and `x + y ≤ size`.
///
/// Mirrors `hexx::shapes::Triangle` (`src/shapes.rs:62`), with its public field.
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// Derives `Serde` and `PartialEq` as a matter of course (plan §2.3); `hexx` derives `Debug`,
/// `Clone` and `Copy`.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct Triangle {
    pub size: u32,
}

/// The value of `hexx`'s `Default`: `size` 10.
///
/// Mirrors `impl Default for Triangle` (`src/shapes.rs:67`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// None.
pub impl TriangleDefault of Default<Triangle> {
    fn default() -> Triangle {
        Triangle { size: 10 }
    }
}

/// The items of `impl Triangle` (`src/shapes.rs:73`).
pub trait TriangleTrait {
    /// A triangle of side `size`.
    ///
    /// Mirrors `Triangle::new` (`src/shapes.rs:77`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn new(size: u32) -> Triangle;

    /// The coordinates of the triangle, `wedge_count(size)` of them, `x` ascending then `y`
    /// ascending.
    ///
    /// Mirrors `Triangle::coords` (`src/shapes.rs:84`).
    ///
    /// #### Panics
    ///
    /// When `size` is above `i32::MAX`.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`. `hexx` casts `size` with `as i32`, which
    /// wraps above `i32::MAX`; this port panics (a span of that size runs out of gas first).
    fn coords(self: Triangle) -> Span<Hex>;
}

pub impl TriangleImpl of TriangleTrait {
    #[inline]
    fn new(size: u32) -> Triangle {
        Triangle { size }
    }

    #[inline]
    fn coords(self: Triangle) -> Span<Hex> {
        triangle(self.size)
    }
}

/// The coordinates of the triangle of side `size`, `wedge_count(size)` of them, `x` ascending
/// then `y` ascending.
///
/// A free function, by decision of the brief of M2-T6: it mirrors the free function of
/// `hexx::shapes` at the same path (`hexx::shapes::triangle`), and the mirror keeps `hexx`'s
/// names and paths (principle 8). It would move to a `ShapesTrait` if the orchestrator ruled that
/// D-143 wants it on a trait; the parity map would then need an entry.
///
/// Mirrors `hexx::shapes::triangle` (`src/shapes.rs:95`).
///
/// #### Panics
///
/// When `size` is above `i32::MAX`.
///
/// #### Deviations
///
/// A `Span<Hex>` instead of an `ExactSizeIterator`. `hexx` casts `size` with `as i32`, which
/// wraps above `i32::MAX`; this port panics (a span of that size runs out of gas first).
pub fn triangle(size: u32) -> Span<Hex> {
    let size: i32 = size.try_into().unwrap();
    let mut out = array![];
    let mut x = 0;
    loop {
        let last = size - x;
        let mut y = 0;
        loop {
            out.append(Hex { x, y });
            if y == last {
                break;
            }
            y += 1;
        }
        if x == size {
            break;
        }
        x += 1;
    }
    out.span()
}

// endregion

// region hexagon

/// A hexagon: every coordinate within `radius` of `center`.
///
/// Mirrors `hexx::shapes::Hexagon` (`src/shapes.rs:111`), with its public fields. It is the
/// coordinate form of the bitmap hexagon of the board, `board::hexagon::HexagonTrait`: another
/// module, another trait of the same name, and neither is re-exported at the root. A file that
/// uses both imports one of them under another name.
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// Derives `Serde` and `PartialEq` as a matter of course (plan §2.3); `hexx` derives `Debug`,
/// `Clone` and `Copy`.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct Hexagon {
    pub center: Hex,
    pub radius: u32,
}

/// The value of `hexx`'s `Default`: `center` at the origin, `radius` 10.
///
/// Mirrors `impl Default for Hexagon` (`src/shapes.rs:118`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// None.
pub impl HexagonDefault of Default<Hexagon> {
    fn default() -> Hexagon {
        Hexagon { center: HexTrait::ZERO, radius: 10 }
    }
}

/// The items of `impl Hexagon` (`src/shapes.rs:127`). Not the `HexagonTrait` of the board
/// (`board::hexagon::HexagonTrait`, the bitmap hexagon): neither is re-exported at the root.
pub trait HexagonTrait {
    /// A hexagon of `radius` around `center`.
    ///
    /// Mirrors `Hexagon::new` (`src/shapes.rs:131`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn new(center: Hex, radius: u32) -> Hexagon;

    /// The coordinates of the hexagon, `range_count(radius)` of them, in the order of
    /// `Hex::range`.
    ///
    /// Mirrors `Hexagon::coords` (`src/shapes.rs:137`).
    ///
    /// #### Panics
    ///
    /// As `Hex::range`.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`.
    fn coords(self: Hexagon) -> Span<Hex>;
}

pub impl HexagonImpl of HexagonTrait {
    #[inline]
    fn new(center: Hex, radius: u32) -> Hexagon {
        Hexagon { center, radius }
    }

    #[inline]
    fn coords(self: Hexagon) -> Span<Hex> {
        hexagon(self.center, self.radius)
    }
}

/// The coordinates of the hexagon of `radius` around `center`: `Hex::range`, `range_count(radius)`
/// of them, `x` ascending then `y` ascending. The coordinate form of the board's bitmap
/// `board::hexagon::HexagonTrait::hexagon`.
///
/// A free function, by decision of the brief of M2-T6: it mirrors the free function of
/// `hexx::shapes` at the same path (`hexx::shapes::hexagon`), and the mirror keeps `hexx`'s names
/// and paths (principle 8). It would move to a `ShapesTrait` if the orchestrator ruled that D-143
/// wants it on a trait; the parity map would then need an entry.
///
/// Mirrors `hexx::shapes::hexagon` (`src/shapes.rs:144`).
///
/// #### Panics
///
/// As `Hex::range`: when `range_count(radius)` leaves `u32` (`radius` above 37,836), or a
/// coordinate leaves `i32`.
///
/// #### Deviations
///
/// A `Span<Hex>` instead of an `ExactSizeIterator`.
pub fn hexagon(center: Hex, radius: u32) -> Span<Hex> {
    center.range(radius)
}

// endregion

// region rombus

/// A rombus: `rows` rows of `columns` hexes from `origin`, the rows along `y`, the columns along
/// `x`.
///
/// Mirrors `hexx::shapes::Rombus` (`src/shapes.rs:156`), with its public fields.
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// Derives `Serde` and `PartialEq` as a matter of course (plan §2.3); `hexx` derives `Debug`,
/// `Clone` and `Copy`.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct Rombus {
    pub origin: Hex,
    pub rows: u32,
    pub columns: u32,
}

/// The value of `hexx`'s `Default`: `origin` at the origin, 10 rows of 10 columns.
///
/// Mirrors `impl Default for Rombus` (`src/shapes.rs:165`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// None.
pub impl RombusDefault of Default<Rombus> {
    fn default() -> Rombus {
        Rombus { origin: HexTrait::ZERO, rows: 10, columns: 10 }
    }
}

/// The items of `impl Rombus` (`src/shapes.rs:175`).
pub trait RombusTrait {
    /// The coordinates of the rombus, `rows × columns` of them, row by row (`y` ascending, then
    /// `x` ascending); empty when `rows` or `columns` is 0.
    ///
    /// Mirrors `Rombus::coords` (`src/shapes.rs:178`).
    ///
    /// #### Panics
    ///
    /// When `rows` or `columns` is above `i32::MAX`, or a coordinate leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`. `hexx` casts `rows` and `columns` with
    /// `as i32`, which wraps above `i32::MAX`; this port panics (as `triangle` does). A
    /// coordinate leaving `i32` panics as in `hexx`'s debug build.
    fn coords(self: Rombus) -> Span<Hex>;
}

pub impl RombusImpl of RombusTrait {
    #[inline]
    fn coords(self: Rombus) -> Span<Hex> {
        rombus(self.origin, self.rows, self.columns)
    }
}

/// The coordinates of the rombus of `rows` rows and `columns` columns from `point`, row by row
/// (`y` ascending, then `x` ascending); empty when `rows` or `columns` is 0.
///
/// A free function, by decision of the brief of M2-T6: it mirrors the free function of
/// `hexx::shapes` at the same path (`hexx::shapes::rombus`), and the mirror keeps `hexx`'s names
/// and paths (principle 8). It would move to a `ShapesTrait` if the orchestrator ruled that D-143
/// wants it on a trait; the parity map would then need an entry.
///
/// Mirrors `hexx::shapes::rombus` (`src/shapes.rs:186`).
///
/// #### Panics
///
/// When `rows` or `columns` is above `i32::MAX` while both are non-zero, or a coordinate leaves
/// `i32`.
///
/// #### Deviations
///
/// A `Span<Hex>` instead of an `ExactSizeIterator`. `hexx` casts `rows` and `columns` with
/// `as i32`, which wraps above `i32::MAX`; this port panics (as `triangle` does). A coordinate
/// leaving `i32` panics as in `hexx`'s debug build.
pub fn rombus(point: Hex, rows: u32, columns: u32) -> Span<Hex> {
    let mut out = array![];
    if rows == 0 || columns == 0 {
        return out.span();
    }
    let rows: i32 = rows.try_into().unwrap();
    let columns: i32 = columns.try_into().unwrap();
    let mut y = 0;
    while y != rows {
        let mut x = 0;
        while x != columns {
            out.append(point.const_add(Hex { x, y }));
            x += 1;
        }
        y += 1;
    }
    out.span()
}

// endregion

// region rectangles

/// Half of `v` rounded down, `v >> 1` of `hexx`: `floor(v / 2)`, also the shove of the `Odd`
/// offset coordinates. Cairo's `i32` division truncates, so a negative odd `v` is one lower than
/// the quotient (`-3 >> 1 = -2`, `-3 / 2 = -1`).
#[generate_trait]
impl FloorHalfImpl of FloorHalfTrait {
    #[inline]
    fn floor_half(v: i32) -> i32 {
        let half = v / 2;
        if v % 2 < 0 {
            half - 1
        } else {
            half
        }
    }
}

/// A rectangle of pointy hexes: the offset coordinates (`OffsetHexMode::Odd`,
/// `HexOrientation::Pointy`) `left ≤ column ≤ right` and `top ≤ row ≤ bottom`.
///
/// Mirrors `hexx::shapes::PointyRectangle` (`src/shapes.rs:205`), with its public fields.
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// Derives `Serde` and `PartialEq` as a matter of course (plan §2.3); `hexx` derives `Debug`,
/// `Clone` and `Copy`.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct PointyRectangle {
    pub left: i32,
    pub right: i32,
    pub top: i32,
    pub bottom: i32,
}

/// The value of `hexx`'s `Default`: `-10`, `10`, `-10`, `10`.
///
/// Mirrors `impl Default for PointyRectangle` (`src/shapes.rs:216`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// None.
pub impl PointyRectangleDefault of Default<PointyRectangle> {
    fn default() -> PointyRectangle {
        PointyRectangle { left: -10, right: 10, top: -10, bottom: 10 }
    }
}

/// The items of `impl PointyRectangle` (`src/shapes.rs:227`).
pub trait PointyRectangleTrait {
    /// The coordinates of the rectangle, row by row (`y` ascending, then `x` ascending); empty
    /// when `right < left` or `bottom < top`.
    ///
    /// Mirrors `PointyRectangle::coords` (`src/shapes.rs:231`).
    ///
    /// #### Panics
    ///
    /// When a coordinate leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`. `hexx` wraps in a release build and
    /// panics in a debug build (plan §3.1); this port panics where the debug build does.
    fn coords(self: PointyRectangle) -> Span<Hex>;
}

pub impl PointyRectangleImpl of PointyRectangleTrait {
    #[inline]
    fn coords(self: PointyRectangle) -> Span<Hex> {
        pointy_rectangle([self.left, self.right, self.top, self.bottom])
    }
}

/// The coordinates of the pointy rectangle `[left, right, top, bottom]`, row by row (`y`
/// ascending, then `x` ascending): row `y` holds `x` from `left − (y >> 1)` to `right − (y >>
/// 1)`, with `y >> 1` the floor of `y / 2`. Empty when `right < left` or `bottom < top`. Cairo's
/// `i32` division truncates where `y >> 1`
/// floors; the loop floors a negative odd `y` (`-3 >> 1 = -2`), so the results are those of
/// `hexx`.
///
/// A free function, by decision of the brief of M2-T6: it mirrors the free function of
/// `hexx::shapes` at the same path (`hexx::shapes::pointy_rectangle`), and the mirror keeps
/// `hexx`'s names and paths (principle 8). It would move to a `ShapesTrait` if the orchestrator
/// ruled that D-143 wants it on a trait; the parity map would then need an entry.
///
/// Mirrors `hexx::shapes::pointy_rectangle` (`src/shapes.rs:243`).
///
/// #### Panics
///
/// When a coordinate leaves `i32`.
///
/// #### Deviations
///
/// A `Span<Hex>` instead of an `ExactSizeIterator`. `hexx` wraps in a release build and panics in
/// a debug build (plan §3.1); this port panics where the debug build does. The array is
/// one parameter `bounds`, destructured in the body: Cairo has no array pattern in a parameter
/// (`hexx` takes `[left, right, top, bottom]: [i32; 4]`).
pub fn pointy_rectangle(bounds: [i32; 4]) -> Span<Hex> {
    let [left, right, top, bottom] = bounds;
    let mut out = array![];
    if right < left || bottom < top {
        return out.span();
    }
    let mut y = top;
    loop {
        let shift = FloorHalfTrait::floor_half(y);
        let last = right - shift;
        let mut x = left - shift;
        loop {
            out.append(Hex { x, y });
            if x == last {
                break;
            }
            x += 1;
        }
        if y == bottom {
            break;
        }
        y += 1;
    }
    out.span()
}

/// A rectangle of flat hexes: the offset coordinates (`OffsetHexMode::Odd`,
/// `HexOrientation::Flat`) `left ≤ column ≤ right` and `top ≤ row ≤ bottom`.
///
/// Mirrors `hexx::shapes::FlatRectangle` (`src/shapes.rs:266`), with its public fields.
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// Derives `Serde` and `PartialEq` as a matter of course (plan §2.3); `hexx` derives `Debug`,
/// `Clone` and `Copy`.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct FlatRectangle {
    pub left: i32,
    pub right: i32,
    pub top: i32,
    pub bottom: i32,
}

/// The value of `hexx`'s `Default`: `-10`, `10`, `-10`, `10`.
///
/// Mirrors `impl Default for FlatRectangle` (`src/shapes.rs:277`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// None.
pub impl FlatRectangleDefault of Default<FlatRectangle> {
    fn default() -> FlatRectangle {
        FlatRectangle { left: -10, right: 10, top: -10, bottom: 10 }
    }
}

/// The items of `impl FlatRectangle` (`src/shapes.rs:288`).
pub trait FlatRectangleTrait {
    /// The coordinates of the rectangle, column by column (`x` ascending, then `y` ascending);
    /// empty when `right < left` or `bottom < top`.
    ///
    /// Mirrors `FlatRectangle::coords` (`src/shapes.rs:291`).
    ///
    /// #### Panics
    ///
    /// When a coordinate leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`. `hexx` wraps in a release build and
    /// panics in a debug build (plan §3.1); this port panics where the debug build does.
    fn coords(self: FlatRectangle) -> Span<Hex>;
}

pub impl FlatRectangleImpl of FlatRectangleTrait {
    #[inline]
    fn coords(self: FlatRectangle) -> Span<Hex> {
        flat_rectangle([self.left, self.right, self.top, self.bottom])
    }
}

/// The coordinates of the flat rectangle `[left, right, top, bottom]`, column by column (`x`
/// ascending, then `y` ascending): column `x` holds `y` from `top − (x >> 1)` to
/// `bottom − (x >> 1)`, with `x >> 1` the floor of `x / 2`. Empty when `right < left` or
/// `bottom < top`. Cairo's `i32` division truncates where `x >> 1`
/// floors; the loop floors a negative odd `x` (`-3 >> 1 = -2`), so the results are those of
/// `hexx`.
///
/// A free function, by decision of the brief of M2-T6: it mirrors the free function of
/// `hexx::shapes` at the same path (`hexx::shapes::flat_rectangle`), and the mirror keeps
/// `hexx`'s names and paths (principle 8). It would move to a `ShapesTrait` if the orchestrator
/// ruled that D-143 wants it on a trait; the parity map would then need an entry.
///
/// Mirrors `hexx::shapes::flat_rectangle` (`src/shapes.rs:303`).
///
/// #### Panics
///
/// When a coordinate leaves `i32`.
///
/// #### Deviations
///
/// A `Span<Hex>` instead of an `ExactSizeIterator`. `hexx` wraps in a release build and panics in
/// a debug build (plan §3.1); this port panics where the debug build does. The array is
/// one parameter `bounds`, destructured in the body: Cairo has no array pattern in a parameter
/// (`hexx` takes `[left, right, top, bottom]: [i32; 4]`).
pub fn flat_rectangle(bounds: [i32; 4]) -> Span<Hex> {
    let [left, right, top, bottom] = bounds;
    let mut out = array![];
    if right < left || bottom < top {
        return out.span();
    }
    let mut x = left;
    loop {
        let shift = FloorHalfTrait::floor_half(x);
        let last = bottom - shift;
        let mut y = top - shift;
        loop {
            out.append(Hex { x, y });
            if y == last {
                break;
            }
            y += 1;
        }
        if x == right {
            break;
        }
        x += 1;
    }
    out.span()
}

// endregion

#[cfg(test)]
mod tests {
    // Local imports

    use crate::conversions::{HexConversionsTrait, OffsetHexMode};
    use crate::hex::{Hex, HexTrait};
    use crate::orientation::HexOrientation;
    use super::{
        FlatRectangle, FlatRectangleTrait, Hexagon, HexagonTrait, Parallelogram, ParallelogramTrait,
        PointyRectangle, PointyRectangleTrait, Rombus, RombusTrait, Triangle, TriangleTrait,
        flat_rectangle, hexagon, parallelogram, pointy_rectangle, rombus, triangle,
    };

    /// The order checks of the oracles, plain and obviously correct.
    #[generate_trait]
    impl Order of OrderTrait {
        /// `true` when `b` comes after `a` by `x` then `y`.
        fn x_then_y(a: Hex, b: Hex) -> bool {
            b.x > a.x || (b.x == a.x && b.y > a.y)
        }

        /// `true` when `b` comes after `a` by `y` then `x`.
        fn y_then_x(a: Hex, b: Hex) -> bool {
            b.y > a.y || (b.y == a.y && b.x > a.x)
        }
    }

    /// Eight anchors, odd and negative rows and columns included.
    fn anchors() -> Span<(i32, i32)> {
        array![(0, 0), (1, 0), (0, 1), (-1, -1), (3, -7), (-5, 4), (-3, 0), (0, -3)].span()
    }

    // Oracles (D-167): each `coords` as a set against its per-hex definition. A span whose every
    // element satisfies the definition, whose elements are strictly increasing in the order of
    // `hexx` (so all distinct) and whose length is the closed form of the definition's size is
    // exactly the set of the definition. The sizes stay small (radius 4, boxes of 5 × 5, 4 × 4
    // rectangles): the golden vectors hold radii and boxes up to 6 against `hexx`.

    #[test]
    #[available_gas(l2_gas: 42844893)]
    fn test_shapes_hexagon_oracle() {
        for anchor in anchors() {
            let (cx, cy) = *anchor;
            let center = HexTrait::new(cx, cy);
            for radius in 0..5_u32 {
                let span = hexagon(center, radius);
                assert!(span.len() == HexTrait::range_count(radius));
                assert!(span == center.range(radius));
                assert!(Hexagon { center, radius }.coords() == span);
                let r: i32 = radius.try_into().unwrap();
                let mut i = 0;
                while i < span.len() {
                    let h = *span.at(i);
                    assert!(h.distance_to(center) <= r);
                    if i > 0 {
                        assert!(OrderTrait::x_then_y(*span.at(i - 1), h));
                    }
                    i += 1;
                }
            }
        }
    }

    #[test]
    #[available_gas(l2_gas: 33546261)]
    fn test_shapes_parallelogram_oracle() {
        for anchor in anchors() {
            let (mx, my) = *anchor;
            for dx in 0..5_i32 {
                for dy in 0..5_i32 {
                    let min = HexTrait::new(mx, my);
                    let max = HexTrait::new(mx + dx, my + dy);
                    let span = parallelogram(min, max);
                    assert!(span.len() == ((dx + 1) * (dy + 1)).try_into().unwrap());
                    assert!(ParallelogramTrait::new(min, max).coords() == span);
                    let mut i = 0;
                    while i < span.len() {
                        let h = *span.at(i);
                        assert!(min.x <= h.x && h.x <= max.x && min.y <= h.y && h.y <= max.y);
                        if i > 0 {
                            assert!(OrderTrait::x_then_y(*span.at(i - 1), h));
                        }
                        i += 1;
                    }
                }
            }
        }
    }

    #[test]
    #[available_gas(l2_gas: 4936229)]
    fn test_shapes_triangle_oracle() {
        for size in 0..11_u32 {
            let span = triangle(size);
            assert!(span.len() == HexTrait::wedge_count(size));
            assert!(TriangleTrait::new(size).coords() == span);
            let s: i32 = size.try_into().unwrap();
            let mut i = 0;
            while i < span.len() {
                let h = *span.at(i);
                assert!(h.x >= 0 && h.y >= 0 && h.x + h.y <= s);
                if i > 0 {
                    assert!(OrderTrait::x_then_y(*span.at(i - 1), h));
                }
                i += 1;
            }
        }
    }

    #[test]
    #[available_gas(l2_gas: 47747637)]
    fn test_shapes_rombus_oracle() {
        for anchor in anchors() {
            let (ox, oy) = *anchor;
            let origin = HexTrait::new(ox, oy);
            for rows in 0..6_u32 {
                for columns in 0..6_u32 {
                    let span = rombus(origin, rows, columns);
                    assert!(span.len() == rows * columns);
                    assert!(Rombus { origin, rows, columns }.coords() == span);
                    let r: i32 = rows.try_into().unwrap();
                    let c: i32 = columns.try_into().unwrap();
                    let mut i = 0;
                    while i < span.len() {
                        let h = *span.at(i);
                        assert!(0 <= h.x - ox && h.x - ox < c && 0 <= h.y - oy && h.y - oy < r);
                        if i > 0 {
                            assert!(OrderTrait::y_then_x(*span.at(i - 1), h));
                        }
                        i += 1;
                    }
                }
            }
        }
    }

    #[test]
    #[available_gas(l2_gas: 25613217)]
    fn test_shapes_pointy_rectangle_oracle() {
        for anchor in anchors() {
            let (left, top) = *anchor;
            for width in 0..4_i32 {
                for height in 0..4_i32 {
                    let (right, bottom) = (left + width, top + height);
                    let span = pointy_rectangle([left, right, top, bottom]);
                    assert!(span.len() == ((width + 1) * (height + 1)).try_into().unwrap());
                    let rect = PointyRectangle { left, right, top, bottom };
                    assert!(rect.coords() == span);
                    let mut i = 0;
                    while i < span.len() {
                        let h = *span.at(i);
                        let [column, row] = h
                            .to_offset_coordinates(OffsetHexMode::Odd, HexOrientation::Pointy);
                        assert!(left <= column && column <= right && top <= row && row <= bottom);
                        if i > 0 {
                            assert!(OrderTrait::y_then_x(*span.at(i - 1), h));
                        }
                        i += 1;
                    }
                }
            }
        }
    }

    #[test]
    #[available_gas(l2_gas: 25613217)]
    fn test_shapes_flat_rectangle_oracle() {
        for anchor in anchors() {
            let (left, top) = *anchor;
            for width in 0..4_i32 {
                for height in 0..4_i32 {
                    let (right, bottom) = (left + width, top + height);
                    let span = flat_rectangle([left, right, top, bottom]);
                    assert!(span.len() == ((width + 1) * (height + 1)).try_into().unwrap());
                    let rect = FlatRectangle { left, right, top, bottom };
                    assert!(rect.coords() == span);
                    let mut i = 0;
                    while i < span.len() {
                        let h = *span.at(i);
                        let [column, row] = h
                            .to_offset_coordinates(OffsetHexMode::Odd, HexOrientation::Flat);
                        assert!(left <= column && column <= right && top <= row && row <= bottom);
                        if i > 0 {
                            assert!(OrderTrait::x_then_y(*span.at(i - 1), h));
                        }
                        i += 1;
                    }
                }
            }
        }
    }

    /// Regression (plan §4.3): `hexx`'s `y >> 1` floors on a negative odd `y` (`-3 >> 1 = -2`)
    /// where Cairo's `i32` division truncates (`-3 / 2 = -1`). Rows `y = -3` and `y = -2` of a
    /// pointy rectangle shift by `-2` and `-1`.
    #[test]
    #[available_gas(l2_gas: 41360)]
    fn test_shapes_pointy_rectangle_negative_top() {
        let span = pointy_rectangle([0, 1, -3, -2]);
        let expected = array![
            HexTrait::new(2, -3), HexTrait::new(3, -3), HexTrait::new(1, -2), HexTrait::new(2, -2),
        ]
            .span();
        assert!(span == expected);
    }

    /// Regression: the columns `x = -3` and `x = -2` of a flat rectangle shift by `-2` and `-1`.
    #[test]
    #[available_gas(l2_gas: 41360)]
    fn test_shapes_flat_rectangle_negative_left() {
        let span = flat_rectangle([-3, -2, 0, 1]);
        let expected = array![
            HexTrait::new(-3, 2), HexTrait::new(-3, 3), HexTrait::new(-2, 1), HexTrait::new(-2, 2),
        ]
            .span();
        assert!(span == expected);
    }

    /// A shape whose bounds cross is the empty span; so is a rombus of no row or no column.
    #[test]
    #[available_gas(l2_gas: 30870)]
    fn test_shapes_empty() {
        let origin = HexTrait::ZERO;
        assert!(parallelogram(HexTrait::new(3, 0), HexTrait::new(1, 5)).is_empty());
        assert!(parallelogram(HexTrait::new(0, 3), HexTrait::new(5, 1)).is_empty());
        assert!(rombus(origin, 0, 5).is_empty());
        assert!(rombus(origin, 5, 0).is_empty());
        assert!(pointy_rectangle([3, 1, 0, 2]).is_empty());
        assert!(pointy_rectangle([0, 2, 3, 1]).is_empty());
        assert!(flat_rectangle([3, 1, 0, 2]).is_empty());
        assert!(flat_rectangle([0, 2, 3, 1]).is_empty());
        // Size 0 is the origin alone, radius 0 the centre alone.
        assert!(triangle(0) == array![origin].span());
        assert!(hexagon(HexTrait::new(2, 3), 0) == array![HexTrait::new(2, 3)].span());
    }

    /// A bound of `i32::MAX` is served: the loops stop at the bound without stepping past it.
    #[test]
    #[available_gas(l2_gas: 24266)]
    fn test_shapes_bound_at_max() {
        let top = 2147483647;
        let span = parallelogram(HexTrait::new(0, top), HexTrait::new(1, top));
        assert!(span == array![HexTrait::new(0, top), HexTrait::new(1, top)].span());
    }

    /// `i32` overflow of a coordinate panics, as `hexx` does in a debug build.
    #[test]
    #[available_gas(l2_gas: 15393)]
    #[should_panic]
    fn test_shapes_rombus_revert_overflow() {
        rombus(HexTrait::new(2147483647, 0), 1, 2);
    }

    /// `size` above `i32::MAX` panics (`hexx` wraps with `as i32`).
    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_shapes_triangle_revert_size() {
        triangle(0x80000000);
    }

    /// The `Default` of each struct, and its `coords` against the closed form of its size.
    #[test]
    #[available_gas(l2_gas: 4552706)]
    fn test_shapes_default() {
        let parallelogram: Parallelogram = Default::default();
        assert!(
            parallelogram == Parallelogram { min: HexTrait::splat(-10), max: HexTrait::splat(10) },
        );
        assert!(parallelogram.coords().len() == 441);
        let triangle: Triangle = Default::default();
        assert!(triangle == Triangle { size: 10 });
        assert!(triangle.coords().len() == 66);
        let hexagon: Hexagon = Default::default();
        assert!(hexagon == Hexagon { center: HexTrait::ZERO, radius: 10 });
        assert!(hexagon.coords().len() == 331);
        let rombus: Rombus = Default::default();
        assert!(rombus == Rombus { origin: HexTrait::ZERO, rows: 10, columns: 10 });
        assert!(rombus.coords().len() == 100);
        let pointy: PointyRectangle = Default::default();
        assert!(pointy == PointyRectangle { left: -10, right: 10, top: -10, bottom: 10 });
        assert!(pointy.coords().len() == 441);
        let flat: FlatRectangle = Default::default();
        assert!(flat == FlatRectangle { left: -10, right: 10, top: -10, bottom: 10 });
        assert!(flat.coords().len() == 441);
    }

    // Benchmarks of M2-T6 (LIB-06), one call each on the worst case of the brief. Targets (`L`,
    // `U = ceil(1.25 L)`) derived from the L-M1 measurements (a span built by a loop 7,358 per
    // element, `line_to` at `N = 22`: 169,230 for 23 elements), written before the first
    // measurement; `new` and `Default` need no bench:
    //
    // | function | case | `L` | `U` |
    // |---|---|---|---|
    // | `hexagon`, `Hexagon::coords` | radius 6 (127 hexes) | 934,466 | 1,168,083 |
    // | `parallelogram`, `rombus`, `pointy_rectangle`, `flat_rectangle` and their `coords` | 7 × 7
    // (49 hexes) | 360,542 | 450,678 |
    // | `triangle`, `Triangle::coords` | size 6 (28 hexes) | 206,024 | 257,530 |
    //
    // Each test is the call alone: the cost of the entry of a test (7,610, the measured minimum
    // of the `#[should_panic]` tests) is in the figure.

    #[test]
    #[available_gas(l2_gas: 615353)]
    fn bench_shapes_hexagon() {
        assert!(hexagon(HexTrait::new(3, -7), 6).len() == 127);
    }

    #[test]
    #[available_gas(l2_gas: 615353)]
    fn bench_shapes_hexagon_coords() {
        assert!(Hexagon { center: HexTrait::new(3, -7), radius: 6 }.coords().len() == 127);
    }

    #[test]
    #[available_gas(l2_gas: 119627)]
    fn bench_shapes_parallelogram() {
        assert!(parallelogram(HexTrait::new(3, -7), HexTrait::new(9, -1)).len() == 49);
    }

    #[test]
    #[available_gas(l2_gas: 119627)]
    fn bench_shapes_parallelogram_coords() {
        let shape = ParallelogramTrait::new(HexTrait::new(3, -7), HexTrait::new(9, -1));
        assert!(shape.coords().len() == 49);
    }

    #[test]
    #[available_gas(l2_gas: 84420)]
    fn bench_shapes_triangle() {
        assert!(triangle(6).len() == 28);
    }

    #[test]
    #[available_gas(l2_gas: 84420)]
    fn bench_shapes_triangle_coords() {
        assert!(TriangleTrait::new(6).coords().len() == 28);
    }

    #[test]
    #[available_gas(l2_gas: 206693)]
    fn bench_shapes_rombus() {
        assert!(rombus(HexTrait::new(3, -7), 7, 7).len() == 49);
    }

    #[test]
    #[available_gas(l2_gas: 206693)]
    fn bench_shapes_rombus_coords() {
        assert!(Rombus { origin: HexTrait::new(3, -7), rows: 7, columns: 7 }.coords().len() == 49);
    }

    #[test]
    #[available_gas(l2_gas: 166079)]
    fn bench_shapes_pointy_rectangle() {
        assert!(pointy_rectangle([-3, 3, -3, 3]).len() == 49);
    }

    #[test]
    #[available_gas(l2_gas: 166079)]
    fn bench_shapes_pointy_rectangle_coords() {
        let rect = PointyRectangle { left: -3, right: 3, top: -3, bottom: 3 };
        assert!(rect.coords().len() == 49);
    }

    #[test]
    #[available_gas(l2_gas: 166079)]
    fn bench_shapes_flat_rectangle() {
        assert!(flat_rectangle([-3, 3, -3, 3]).len() == 49);
    }

    #[test]
    #[available_gas(l2_gas: 166079)]
    fn bench_shapes_flat_rectangle_coords() {
        let rect = FlatRectangle { left: -3, right: 3, top: -3, bottom: 3 };
        assert!(rect.coords().len() == 49);
    }
}
