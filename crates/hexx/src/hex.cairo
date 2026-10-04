//! `Hex`: an axial hexagonal coordinate on `i32`, the mirror of `hexx::Hex` (`src/hex/mod.rs`).
//!
//! Every operation whose result leaves `i32` **panics** with Cairo's native message, where `hexx`
//! panics in a debug build and wraps in a release build (plan §3.1). The cubic coordinate is
//! `z = -x - y`, computed as `hexx` computes it (`src/hex/mod.rs:274-276`), so it panics exactly
//! where a debug build of `hexx` does.
//!
//! The compass of `hexx` (y down) is kept verbatim by `EdgeDirection`; `Hex` itself has no
//! orientation. This file holds the items of milestone L-M1 (plan §8), `line_to` (M1-T6)
//! included, and the constants, constructors and small helpers of `src/hex/mod.rs` that every
//! other task of L-M2 calls (M2-T0). The rest lands with the other tasks of L-M2, in the modules
//! declared below (plan §2.2).

use core::fmt::{Debug, Error, Formatter};
use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
use crate::direction::impls::EdgeDirectionOpsTrait;
use crate::direction::vertex_direction::{VertexDirection, VertexDirectionTrait};
use crate::direction::way::{DirectionWay, DirectionWayFromTrait, DirectionWayTrait};

// The modules of milestone L-M2 (plan §2.2): each is filled by the task that owns it (M2-T3:
// `impls`, `swizzle`, `euclidean`, `convert`; M2-T4: `rings`; M2-T5: `iter`; M2-T7: `grid`).
pub mod convert;
pub mod euclidean;
pub mod grid;
pub mod impls;
pub mod iter;
pub mod rings;
pub mod swizzle;
pub use iter::HexSpanExt;

/// Errors module.
pub mod errors {
    pub const HEX_CUBIC_SUM: felt252 = 'Hex: cubic sum';
}

/// Instantiates a hexagon from axial coordinates.
///
/// Mirrors `hexx::hex` (`src/hex/mod.rs:89`), the free function `hex(x, y)`.
///
/// A free function, on purpose (D-143): `hexx` has `hex(x, y)` as a free function (`hexx::hex`,
/// re-exported at its root); the port keeps the free function and the name, and `HexTrait::new` is
/// the scoped form (plan §4.4, "imported from its module, as the house does for `vec3`").
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The path is `hexx::hex::hex` only: `hexx` 0.25.0 has it there too and re-exports it at its root
/// as `hexx::hex` (`src/lib.rs:306`), which this root cannot do, because Cairo refuses
/// `pub use hex::hex` beside `pub mod hex` (E2118).
#[inline]
pub fn hex(x: i32, y: i32) -> Hex {
    Hex { x, y }
}

/// An axial hexagonal coordinate.
///
/// Mirrors `hexx::Hex` (`src/hex/mod.rs:69`), with its public fields `x` (`:71`) and `y` (`:73`).
///
/// #### Panics
///
/// None: a struct holds any `i32` pair.
///
/// #### Deviations
///
/// Derives `Serde`, `Default`, `Hash` as a matter of course (plan §2.3). `Debug` is a manual impl
/// printing what `hexx`'s does (`src/hex/mod.rs:1189`), `Hex { x: 1, y: 2, z: -3 }`: it panics
/// where `z` does (a component of `i32::MIN`), as `hexx` does in a debug build; the single-line
/// form is the only one (Cairo has no `{:#?}` pretty form).
///
/// Every item of this port that returns a `Span<Hex>` (`range`, `xrange`, `line_to`,
/// `rectiline_to`, the rings and wedges, `HexBounds::all_coords` and `intersecting_with`, the
/// shapes) builds the whole span before it returns, where `hexx` returns a lazy iterator: an `i32`
/// overflow on any element panics at the call here, where `hexx`'s debug build panics only when
/// that element is consumed (`HexBounds::new(Hex(i32::MAX, 0), 1).all_coords().next()` is
/// `Some((i32::MAX − 1, 0))` in `hexx`; the call panics here).
///
/// Only `Hex`, `HexTrait` and `HexSpanExt` are re-exported at the crate root with `Hex`. The other
/// traits of its methods (`HexOpsTrait` of `hex::impls`, `HexRingsTrait`, `HexEuclideanTrait`,
/// `HexSwizzleTrait`, `HexConvertTrait`, `HexEdgesTrait` and `HexVerticesTrait` of `hex::grid`) and
/// its operator impls (`HexAdd`, `HexSub`, `HexMul`, `HexDiv`, `HexRem`, `HexNeg` and the
/// assignment forms, in `hex::impls`) are imported from their modules, where `hexx`'s methods and
/// operator impls come with `Hex`: in Cairo a method is called through a trait in scope, and an
/// impl is found where its trait or its type is declared, or where it is imported.
#[derive(Copy, Drop, Serde, PartialEq, Default, Hash)]
pub struct Hex {
    pub x: i32,
    pub y: i32,
}

/// The items of `impl Hex` of milestones L-M1 and L-M2 (`src/hex/mod.rs`).
pub trait HexTrait {
    /// `(0, 0)`.
    ///
    /// Mirrors `Hex::ZERO` (`src/hex/mod.rs:97`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const ZERO: Hex;

    /// The six edge neighbours, in `EdgeDirection` order: `X`, `Y`, `NEG_X_Y`, `NEG_X`, `NEG_Y`,
    /// `X_NEG_Y`, that is `(1, 0)`, `(0, 1)`, `(-1, 1)`, `(-1, 0)`, `(0, -1)`, `(1, -1)`.
    ///
    /// Mirrors `Hex::NEIGHBORS_COORDS` (`src/hex/mod.rs:159`), a `[Hex; 6]` read by
    /// `EdgeDirection::into_hex`.
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEIGHBORS_COORDS: [Hex; 6];

    /// (0, 0), the same value as `ZERO`.
    ///
    /// Mirrors `Hex::ORIGIN` (`src/hex/mod.rs:95`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const ORIGIN: Hex;

    /// (1, 1).
    ///
    /// Mirrors `Hex::ONE` (`src/hex/mod.rs:99`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const ONE: Hex;

    /// (-1, -1).
    ///
    /// Mirrors `Hex::NEG_ONE` (`src/hex/mod.rs:101`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_ONE: Hex;

    /// +X (Q), (1, 0).
    ///
    /// Mirrors `Hex::X` (`src/hex/mod.rs:104`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const X: Hex;

    /// -X (-Q), (-1, 0).
    ///
    /// Mirrors `Hex::NEG_X` (`src/hex/mod.rs:106`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_X: Hex;

    /// +Y (R), (0, 1).
    ///
    /// Mirrors `Hex::Y` (`src/hex/mod.rs:108`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const Y: Hex;

    /// -Y (-R), (0, -1).
    ///
    /// Mirrors `Hex::NEG_Y` (`src/hex/mod.rs:110`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const NEG_Y: Hex;

    /// The unit vectors that increase the X axis, in clockwise order: `(1, 0)`, `(1, -1)`.
    ///
    /// Mirrors `Hex::INCR_X` (`src/hex/mod.rs:113`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const INCR_X: [Hex; 2];

    /// The unit vectors that increase the Y axis, in clockwise order: `(0, 1)`, `(-1, 1)`.
    ///
    /// Mirrors `Hex::INCR_Y` (`src/hex/mod.rs:116`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const INCR_Y: [Hex; 2];

    /// The unit vectors that increase the Z axis, in clockwise order: `(-1, 0)`, `(0, -1)`.
    ///
    /// Mirrors `Hex::INCR_Z` (`src/hex/mod.rs:119`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const INCR_Z: [Hex; 2];

    /// The unit vectors that decrease the X axis, in clockwise order: `(-1, 0)`, `(-1, 1)`.
    ///
    /// Mirrors `Hex::DECR_X` (`src/hex/mod.rs:122`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const DECR_X: [Hex; 2];

    /// The unit vectors that decrease the Y axis, in clockwise order: `(0, -1)`, `(1, -1)`.
    ///
    /// Mirrors `Hex::DECR_Y` (`src/hex/mod.rs:123`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const DECR_Y: [Hex; 2];

    /// The unit vectors that decrease the Z axis, in clockwise order: `(1, 0)`, `(0, 1)`.
    ///
    /// Mirrors `Hex::DECR_Z` (`src/hex/mod.rs:124`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const DECR_Z: [Hex; 2];

    /// The six diagonal neighbours: `(2, -1)`, `(1, 1)`, `(-1, 2)`, `(-2, 1)`, `(-1, -1)`, `(1,
    /// -2)`.
    ///
    /// Mirrors `Hex::DIAGONAL_COORDS` (`src/hex/mod.rs:186`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    const DIAGONAL_COORDS: [Hex; 6];

    /// Instantiates a hexagon from axial coordinates.
    ///
    /// Mirrors `Hex::new` (`src/hex/mod.rs:208`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn new(x: i32, y: i32) -> Hex;

    /// The `x` coordinate.
    ///
    /// Mirrors `Hex::x` (`src/hex/mod.rs:256`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn x(self: Hex) -> i32;

    /// The `y` coordinate.
    ///
    /// Mirrors `Hex::y` (`src/hex/mod.rs:264`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn y(self: Hex) -> i32;

    /// The cubic `z` coordinate, `-x - y`.
    ///
    /// Mirrors `Hex::z` (`src/hex/mod.rs:274`).
    ///
    /// #### Panics
    ///
    /// When `-x`, or `-x - y`, leaves `i32` (for example `x = i32::MIN`, or `x = 0` and
    /// `y = i32::MIN`).
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn z(self: Hex) -> i32;

    /// Subtracts `rhs` from `self`, component by component.
    ///
    /// Mirrors `Hex::const_sub` (`src/hex/mod.rs:449`). Cairo has no `const fn`: this is the
    /// plain function behind the `-` operator of L-M2, and what `distance_to` calls.
    ///
    /// #### Panics
    ///
    /// When a component of the difference leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build; this port panics.
    fn const_sub(self: Hex, rhs: Hex) -> Hex;

    /// The length of the coordinate, its distance from the origin, as a signed integer:
    /// `max(|x|, |y|, |z|)`.
    ///
    /// Mirrors `Hex::length` (`src/hex/mod.rs:568`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32`, or when a component is `i32::MIN` (its absolute value has no
    /// `i32`).
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build; this port panics.
    fn length(self: Hex) -> i32;

    /// The length of the coordinate as an unsigned integer.
    ///
    /// Mirrors `Hex::ulength` (`src/hex/mod.rs:594`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (the computation of `z`);
    /// this port panics. `i32::MIN` as a component is fine: its unsigned absolute value is
    /// `2^31`, as in `hexx`.
    fn ulength(self: Hex) -> u32;

    /// The distance from `self` to `rhs` in hexagonal space, as a signed integer.
    ///
    /// Mirrors `Hex::distance_to` (`src/hex/mod.rs:615`).
    ///
    /// #### Panics
    ///
    /// When `const_sub` or `length` does.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build; this port panics.
    fn distance_to(self: Hex, rhs: Hex) -> i32;

    /// The distance from `self` to `rhs` in hexagonal space, as an unsigned integer.
    ///
    /// Mirrors `Hex::unsigned_distance_to` (`src/hex/mod.rs:625`).
    ///
    /// #### Panics
    ///
    /// When `const_sub` or `ulength` does.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build; this port panics.
    fn unsigned_distance_to(self: Hex, rhs: Hex) -> u32;

    /// Every coordinate of the line from `self` to `other`: `N + 1` coordinates,
    /// `N = self.unsigned_distance_to(other)`, both ends included. Element `i` is the tile
    /// nearest the point `self + (i / N)·(other − self)`; at an exact tie between two tiles (an
    /// even `N` only), the one with the smaller `y`, and on the same row the larger `x` (plan
    /// §6.6, the game's rule: the lower tile index of the board). Exact integer arithmetic, no
    /// division: `x` is rounded half up and `y` half down, each by an accumulator. The line is
    /// symmetric (`b.line_to(a)` is `a.line_to(b)` reversed) and translation-invariant.
    ///
    /// Mirrors `Hex::line_to` (`src/hex/mod.rs:903`).
    ///
    /// #### Panics
    ///
    /// Where `self.unsigned_distance_to(other)` panics, as `hexx` does in a debug build: when a
    /// component of `self − other`, or its `z`, leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`. The exact integer line of plan §6.6, where
    /// `hexx` converts both ends to `f32` (`:906`), interpolates in `f32` (`:908`) and rounds
    /// (`:474-483`). Three sources of difference: an exact tie, resolved here by the game's rule
    /// (`hexx`'s `f32` rule is neither symmetric nor translation-invariant); the `f32` rounding of
    /// an end beyond `2^24` (`(16_777_217, 0) → (16_777_218, 0)`: `hexx` starts at
    /// `(16_777_216, 0)`); and the `f32` rounding of the interpolation, which moves a sample
    /// across the edge of its tile even below `2^24` (`(8_000_000, 0) → (8_000_001, 6)`: sample 2
    /// is `(8_000_000, 2)`, `hexx` returns `(8_000_001, 2)`). No identity domain is claimed:
    /// identical to `hexx` on every non-tie pair of the window 15 × 16 in the mirror frame and on
    /// the seeded sample of `[-40, 40]²`; every pair of the compared sets where both differ is
    /// listed in `docs/deviations/line_ties.md` (generated by `tools/refgen`).
    fn line_to(self: Hex, other: Hex) -> Span<Hex>;

    /// Instantiates a hexagon with both coordinates set to `v`.
    ///
    /// Mirrors `Hex::splat` (`src/hex/mod.rs:225`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn splat(v: i32) -> Hex;

    /// Instantiates a hexagon from cubic coordinates.
    ///
    /// Mirrors `Hex::new_cubic` (`src/hex/mod.rs:247`).
    ///
    /// #### Panics
    ///
    /// With `'Hex: cubic sum'` when `x + y + z != 0`; also when the sum leaves `i32` on the way.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn new_cubic(x: i32, y: i32, z: i32) -> Hex;

    /// Instantiates a hexagon from the array `[x, y]`.
    ///
    /// Mirrors `Hex::from_array` (`src/hex/mod.rs:290`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn from_array(array: [i32; 2]) -> Hex;

    /// The coordinates as the array `[x, y]`.
    ///
    /// Mirrors `Hex::to_array` (`src/hex/mod.rs:307`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn to_array(self: Hex) -> [i32; 2];

    /// The coordinates as the cubic array `[x, y, z]`.
    ///
    /// Mirrors `Hex::to_cubic_array` (`src/hex/mod.rs:333`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn to_cubic_array(self: Hex) -> [i32; 3];

    /// The reflection of `self` around the origin: `(-x, -y)`. Cairo has no `const fn`; this is the
    /// plain function behind the `-` operator of L-M2.
    ///
    /// Mirrors `Hex::const_neg` (`src/hex/mod.rs:421`).
    ///
    /// #### Panics
    ///
    /// When a component is `i32::MIN`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn const_neg(self: Hex) -> Hex;

    /// Adds `rhs` to `self`, component by component. The plain function behind the `+` operator of
    /// L-M2.
    ///
    /// Mirrors `Hex::const_add` (`src/hex/mod.rs:435`).
    ///
    /// #### Panics
    ///
    /// When a component of the sum leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn const_add(self: Hex, rhs: Hex) -> Hex;

    /// The absolute value of each component.
    ///
    /// Mirrors `Hex::abs` (`src/hex/mod.rs:498`).
    ///
    /// #### Panics
    ///
    /// When a component is `i32::MIN` (its absolute value has no `i32`).
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn abs(self: Hex) -> Hex;

    /// The minimum of each component of `self` and `rhs`.
    ///
    /// Mirrors `Hex::min` (`src/hex/mod.rs:511`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn min(self: Hex, rhs: Hex) -> Hex;

    /// The maximum of each component of `self` and `rhs`.
    ///
    /// Mirrors `Hex::max` (`src/hex/mod.rs:525`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn max(self: Hex, rhs: Hex) -> Hex;

    /// The dot product of `self` and `rhs`: `x * rhs.x + y * rhs.y`.
    ///
    /// Mirrors `Hex::dot` (`src/hex/mod.rs:535`).
    ///
    /// #### Panics
    ///
    /// When a product or the sum leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn dot(self: Hex, rhs: Hex) -> i32;

    /// The sign of each component: `0` for zero, `1` for positive, `-1` for negative.
    ///
    /// Mirrors `Hex::signum` (`src/hex/mod.rs:546`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn signum(self: Hex) -> Hex;

    /// The number of coordinates in a range around a point: `3 * range * (range + 1) + 1`.
    ///
    /// Mirrors `Hex::range_count` (`src/hex/mod.rs:1160`).
    ///
    /// #### Panics
    ///
    /// When the computation leaves `u32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn range_count(range: u32) -> u32;

    /// The number of coordinates in a ring at the given `range`: `1` for `0`, `6 * range`
    /// otherwise.
    ///
    /// Mirrors `Hex::ring_count` (`src/hex/rings.rs:540`).
    ///
    /// #### Panics
    ///
    /// When `6 * range` leaves `u32`.
    ///
    /// #### Deviations
    ///
    /// Returns a `u32` where `hexx` returns a `usize`, and `usize` is `u32` in Cairo: `hexx`
    /// computes `6 * range as usize`, which a 64-bit host never overflows; this port panics from
    /// `range = 715,827,883`, where `6 * range` leaves `u32`.
    fn ring_count(range: u32) -> u32;

    /// The number of coordinates in a wedge of the given `range`: `range * (range + 3) / 2 + 1`.
    ///
    /// Mirrors `Hex::wedge_count` (`src/hex/rings.rs:285`).
    ///
    /// #### Panics
    ///
    /// When `range * (range + 3)` leaves `u32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn wedge_count(range: u32) -> u32;

    /// Multiplies each component of `self` by `rhs`.
    ///
    /// Mirrors `impl Mul<i32> for Hex` (`src/hex/impls.rs:174`); Cairo's `Mul<T>` is homogeneous,
    /// so the named function stands for the operator.
    ///
    /// #### Panics
    ///
    /// When a product leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn mul_scalar(self: Hex, rhs: i32) -> Hex;

    /// The coordinates of the neighbour in the given direction, relative to the origin.
    ///
    /// Mirrors `Hex::neighbor_coord` (`src/hex/mod.rs:633`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn neighbor_coord(direction: EdgeDirection) -> Hex;

    /// Adds the neighbour coordinates of `direction` to `self`.
    ///
    /// Mirrors `Hex::add_dir` (`src/hex/mod.rs:645`), `pub(crate)` there.
    ///
    /// #### Panics
    ///
    /// When a component of the sum leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// Public here, on `HexTrait`, where `hexx` keeps it `pub(crate)`: a widening, not the port of
    /// a public item. The golden tests of `tools/refgen` (package `golden_hex`) and the class-size
    /// fixture `crates/consumer` call it from outside the crate, so it stays public; it computes
    /// what `neighbor` computes, `self + neighbor_coord(direction)`, which is the public form to
    /// call. `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port
    /// panics exactly where the debug build does.
    fn add_dir(self: Hex, direction: EdgeDirection) -> Hex;

    /// The neighbour of `self` in the given direction.
    ///
    /// Mirrors `Hex::neighbor` (`src/hex/mod.rs:665`).
    ///
    /// #### Panics
    ///
    /// When a component of the sum leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn neighbor(self: Hex, direction: EdgeDirection) -> Hex;

    /// The six neighbours of `self`, in `EdgeDirection` order.
    ///
    /// Mirrors `Hex::all_neighbors` (`src/hex/mod.rs:760`).
    ///
    /// #### Panics
    ///
    /// When a component of a neighbour leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn all_neighbors(self: Hex) -> [Hex; 6];

    /// The diagonal neighbour coordinates of `direction`.
    ///
    /// Mirrors `Hex::diagonal_neighbor_coord` (`src/hex/mod.rs:641`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn diagonal_neighbor_coord(direction: VertexDirection) -> Hex;

    /// Adds the diagonal neighbour coordinates of `direction` to `self`.
    ///
    /// Mirrors `Hex::add_diag_dir` (`src/hex/mod.rs:649`), `pub(crate)` there.
    ///
    /// #### Panics
    ///
    /// When a component of the sum leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// Public here, on `HexTrait`, where `hexx` keeps it `pub(crate)`: a widening, not the port of
    /// a public item. The golden tests of `tools/refgen` (package `golden_hex_t2`) and the
    /// class-size fixture `crates/consumer` call it from outside the crate, so it stays public; it
    /// computes what `diagonal_neighbor` computes, `self + diagonal_neighbor_coord(direction)`,
    /// which is the public form to call. `hexx` wraps in a release build and panics in a debug
    /// build (plan §3.1); this port panics exactly where the debug build does.
    fn add_diag_dir(self: Hex, direction: VertexDirection) -> Hex;

    /// The diagonal neighbour of `self` in the given direction.
    ///
    /// Mirrors `Hex::diagonal_neighbor` (`src/hex/mod.rs:682`).
    ///
    /// #### Panics
    ///
    /// When a component of the sum leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn diagonal_neighbor(self: Hex, direction: VertexDirection) -> Hex;

    /// The direction of the neighbour `other`, `None` when `other` is not a neighbour of `self`.
    /// The first match in `EdgeDirectionTrait::ALL_DIRECTIONS` order.
    ///
    /// Mirrors `Hex::neighbor_direction` (`src/hex/mod.rs:700`).
    ///
    /// #### Panics
    ///
    /// When the sum of a neighbour tried before the match leaves `i32`, as `hexx` does in a debug
    /// build.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn neighbor_direction(self: Hex, other: Hex) -> Option<EdgeDirection>;

    /// The `VertexDirection` wedge of `rhs` relative to `self`: the first direction of
    /// `diagonal_way_to`. Inaccurate at a tie, prefer `diagonal_way_to`.
    ///
    /// Mirrors `Hex::main_diagonal_to` (`src/hex/mod.rs:709`).
    ///
    /// #### Panics
    ///
    /// Where `diagonal_way_to` does.
    ///
    /// #### Deviations
    ///
    /// None.
    fn main_diagonal_to(self: Hex, rhs: Hex) -> VertexDirection;

    /// The `VertexDirection` wedge of `rhs` relative to `self`, a tie when `rhs` is on the boundary
    /// between two wedges.
    ///
    /// Mirrors `Hex::diagonal_way_to` (`src/hex/mod.rs:715`).
    ///
    /// #### Panics
    ///
    /// When `rhs − self`, its `z` or an absolute value leaves `i32`, as `hexx` does in a debug
    /// build.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does. The subtraction is `const_sub`, not the operator.
    fn diagonal_way_to(self: Hex, rhs: Hex) -> DirectionWay<VertexDirection>;

    /// The `EdgeDirection` wedge of `rhs` relative to `self`: the first direction of `way_to`.
    /// Inaccurate at a tie, prefer `way_to`.
    ///
    /// Mirrors `Hex::main_direction_to` (`src/hex/mod.rs:734`).
    ///
    /// #### Panics
    ///
    /// Where `way_to` does.
    ///
    /// #### Deviations
    ///
    /// None.
    fn main_direction_to(self: Hex, rhs: Hex) -> EdgeDirection;

    /// The `EdgeDirection` wedge of `rhs` relative to `self`, a tie when `rhs` is on the boundary
    /// between two wedges.
    ///
    /// Mirrors `Hex::way_to` (`src/hex/mod.rs:740`).
    ///
    /// #### Panics
    ///
    /// When `rhs − self`, its `z`, the differences of its cubic components or an absolute value
    /// leaves `i32`, as `hexx` does in a debug build.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does. The subtraction is `const_sub`, not the operator.
    fn way_to(self: Hex, rhs: Hex) -> DirectionWay<EdgeDirection>;

    /// The six diagonal neighbours of `self`, in `VertexDirection` order.
    ///
    /// Mirrors `Hex::all_diagonals` (`src/hex/mod.rs:767`).
    ///
    /// #### Panics
    ///
    /// When a component of a diagonal leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn all_diagonals(self: Hex) -> [Hex; 6];

    /// `self` rotated around the origin counter-clockwise by 60 degrees.
    ///
    /// Mirrors `Hex::counter_clockwise` (`src/hex/mod.rs:784`).
    ///
    /// #### Panics
    ///
    /// When `z` or the negation of a component leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn counter_clockwise(self: Hex) -> Hex;

    /// `self` rotated around `center` counter-clockwise by 60 degrees.
    ///
    /// Mirrors `Hex::ccw_around` (`src/hex/mod.rs:791`).
    ///
    /// #### Panics
    ///
    /// Where `const_sub`, `counter_clockwise` or `const_add` does.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn ccw_around(self: Hex, center: Hex) -> Hex;

    /// `self` rotated around the origin counter-clockwise by `m` times 60 degrees (`m` modulo 6).
    ///
    /// Mirrors `Hex::rotate_ccw` (`src/hex/mod.rs:799`).
    ///
    /// #### Panics
    ///
    /// Where one of the single rotations or `const_neg` it applies does.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn rotate_ccw(self: Hex, m: u32) -> Hex;

    /// `self` rotated around `center` counter-clockwise by `m` times 60 degrees.
    ///
    /// Mirrors `Hex::rotate_ccw_around` (`src/hex/mod.rs:814`).
    ///
    /// #### Panics
    ///
    /// Where `const_sub`, `rotate_ccw` or `const_add` does.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn rotate_ccw_around(self: Hex, center: Hex, m: u32) -> Hex;

    /// `self` rotated around the origin clockwise by 60 degrees.
    ///
    /// Mirrors `Hex::clockwise` (`src/hex/mod.rs:831`).
    ///
    /// #### Panics
    ///
    /// When `z` or the negation of a component leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn clockwise(self: Hex) -> Hex;

    /// `self` rotated around `center` clockwise by 60 degrees.
    ///
    /// Mirrors `Hex::cw_around` (`src/hex/mod.rs:838`).
    ///
    /// #### Panics
    ///
    /// Where `const_sub`, `clockwise` or `const_add` does.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn cw_around(self: Hex, center: Hex) -> Hex;

    /// `self` rotated around the origin clockwise by `m` times 60 degrees (`m` modulo 6).
    ///
    /// Mirrors `Hex::rotate_cw` (`src/hex/mod.rs:846`).
    ///
    /// #### Panics
    ///
    /// Where one of the single rotations or `const_neg` it applies does.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn rotate_cw(self: Hex, m: u32) -> Hex;

    /// `self` rotated around `center` clockwise by `m` times 60 degrees.
    ///
    /// Mirrors `Hex::rotate_cw_around` (`src/hex/mod.rs:860`).
    ///
    /// #### Panics
    ///
    /// Where `const_sub`, `rotate_cw` or `const_add` does.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn rotate_cw_around(self: Hex, center: Hex, m: u32) -> Hex;

    /// The reflection of `self` across the `x` axis: `(x, z)`.
    ///
    /// Mirrors `Hex::reflect_x` (`src/hex/mod.rs:868`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn reflect_x(self: Hex) -> Hex;

    /// The reflection of `self` across the `y` axis: `(z, y)`.
    ///
    /// Mirrors `Hex::reflect_y` (`src/hex/mod.rs:876`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn reflect_y(self: Hex) -> Hex;

    /// The reflection of `self` across the `z` axis: `(y, x)`.
    ///
    /// Mirrors `Hex::reflect_z` (`src/hex/mod.rs:884`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn reflect_z(self: Hex) -> Hex;

    /// Every coordinate of the two-segment rectilinear path from `self` to `other`: `count + 1`
    /// coordinates, `count = (other − self).length()`, both ends included. The first segment
    /// follows the first direction of `main_diagonal_to(other).edge_directions()` when
    /// `clockwise`, the second otherwise, for `ca` steps, where `ca` is the distance from the full
    /// projection of the other direction to `other − self`; the second segment follows the other.
    ///
    /// Mirrors `Hex::rectiline_to` (`src/hex/mod.rs:936`).
    ///
    /// #### Panics
    ///
    /// When `other − self`, its `length`, the scaled direction or the distance leaves `i32`, as
    /// `hexx` does in a debug build.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`. `hexx` wraps in a release build and panics
    /// in a debug build (plan §3.1); this port panics exactly where the debug build does on the
    /// terms above. `hexx` also computes its reported length `count + 1` up front
    /// (`src/hex/mod.rs:960`), on which its debug build panics when `count = i32::MAX` (from
    /// `(0, 0)` to `(i32::MAX, 0)`); this port does not compute that length, and runs out of gas on
    /// such a path instead.
    fn rectiline_to(self: Hex, other: Hex, clockwise: bool) -> Span<Hex>;

    /// Every coordinate within `range` of `self`, `range_count(range)` of them, in the order of
    /// `hexx`: `x` ascending, then `y` ascending.
    ///
    /// Mirrors `Hex::range` (`src/hex/mod.rs:993`).
    ///
    /// #### Panics
    ///
    /// When `range_count(range)` leaves `u32` (`range` above 37,836), or a coordinate leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`. `hexx` wraps in a release build and panics
    /// in a debug build (plan §3.1); this port panics exactly where the debug build does.
    fn range(self: Hex, range: u32) -> Span<Hex>;

    /// Every coordinate within `range` of `self` except `self`, `range_count(range) − 1` of them
    /// (none for `range = 0`), in the order of `range`.
    ///
    /// Mirrors `Hex::xrange` (`src/hex/mod.rs:1021`).
    ///
    /// #### Panics
    ///
    /// As `range`.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`. `hexx` wraps in a release build and panics
    /// in a debug build (plan §3.1); this port panics exactly where the debug build does.
    fn xrange(self: Hex, range: u32) -> Span<Hex>;

    /// The coordinate of the lower resolution hexagon of radius `radius` that contains `self`:
    /// its *parent*, in its own coordinates system.
    ///
    /// Mirrors `Hex::to_lower_res` (`src/hex/mod.rs:1064`).
    ///
    /// #### Panics
    ///
    /// When `radius` is above 37,836 (`range_count` leaves `u32`), or when a term of the
    /// computation (`z`, `shift * x`, the sums) leaves `i32`, as `hexx` does in a debug build.
    ///
    /// #### Deviations
    ///
    /// Exact integer floor division in place of `hexx`'s `f32` floor. Identical to `hexx` while
    /// every operand converted to `f32` is exact: the three numerators `y + shift·x`,
    /// `z + shift·y`, `x + shift·z`, the divisor `range_count(radius)` and `1 + x − y`,
    /// `1 + y − z`, all within `|value| < 2^24` (a division `n / a` of exact operands floors in
    /// `f32`
    /// like the exact one when `|n| < 2^24`). Beyond, `hexx`'s result depends on the rounding of
    /// its `f32`; this port's is exact. `to_local` and `wrap_in_range` inherit it. `hexx` wraps in
    /// a release build and panics in a debug build (plan §3.1). On `range_count(radius)`, `z` and
    /// the three numerators, computed before any `f32` conversion, this port panics exactly where
    /// the debug build does; `1 + x − y` and `1 + y − z` are computed from the quotients, which
    /// agree within the bound above, so beyond it the two may panic on different inputs there (no
    /// such input has been found).
    fn to_lower_res(self: Hex, radius: u32) -> Hex;

    /// The center of `self` in the higher resolution system of radius `radius`: its first
    /// *child*.
    ///
    /// Mirrors `Hex::to_higher_res` (`src/hex/mod.rs:1114`).
    ///
    /// #### Panics
    ///
    /// When `radius` is above `i32::MAX`, or when a term of the computation leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` casts `radius` to `i32` with `as`, which wraps; this port panics above `i32::MAX`.
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn to_higher_res(self: Hex, radius: u32) -> Hex;

    /// The coordinates of `self` relative to the center of its parent hexagon of radius `radius`.
    ///
    /// Mirrors `Hex::to_local` (`src/hex/mod.rs:1143`).
    ///
    /// #### Panics
    ///
    /// Where `to_lower_res`, `to_higher_res` or `const_sub` does.
    ///
    /// #### Deviations
    ///
    /// Inherits the exact floor of `to_lower_res` and its bound `|value| < 2^24`.
    fn to_local(self: Hex, radius: u32) -> Hex;

    /// `self` wrapped into the hexagon of radius `range` around the origin: the seamless
    /// *wraparound* of a hexagonal map.
    ///
    /// Mirrors `Hex::wrap_in_range` (`src/hex/mod.rs:1183`).
    ///
    /// #### Panics
    ///
    /// Where `to_local` does.
    ///
    /// #### Deviations
    ///
    /// Inherits the exact floor of `to_lower_res` and its bound `|value| < 2^24`.
    fn wrap_in_range(self: Hex, range: u32) -> Hex;
}

pub impl HexImpl of HexTrait {
    const ZERO: Hex = Hex { x: 0, y: 0 };
    const NEIGHBORS_COORDS: [Hex; 6] = [
        Hex { x: 1, y: 0 }, Hex { x: 0, y: 1 }, Hex { x: -1, y: 1 }, Hex { x: -1, y: 0 },
        Hex { x: 0, y: -1 }, Hex { x: 1, y: -1 },
    ];
    const ORIGIN: Hex = Hex { x: 0, y: 0 };
    const ONE: Hex = Hex { x: 1, y: 1 };
    const NEG_ONE: Hex = Hex { x: -1, y: -1 };
    const X: Hex = Hex { x: 1, y: 0 };
    const NEG_X: Hex = Hex { x: -1, y: 0 };
    const Y: Hex = Hex { x: 0, y: 1 };
    const NEG_Y: Hex = Hex { x: 0, y: -1 };
    const INCR_X: [Hex; 2] = [Hex { x: 1, y: 0 }, Hex { x: 1, y: -1 }];
    const INCR_Y: [Hex; 2] = [Hex { x: 0, y: 1 }, Hex { x: -1, y: 1 }];
    const INCR_Z: [Hex; 2] = [Hex { x: -1, y: 0 }, Hex { x: 0, y: -1 }];
    const DECR_X: [Hex; 2] = [Hex { x: -1, y: 0 }, Hex { x: -1, y: 1 }];
    const DECR_Y: [Hex; 2] = [Hex { x: 0, y: -1 }, Hex { x: 1, y: -1 }];
    const DECR_Z: [Hex; 2] = [Hex { x: 1, y: 0 }, Hex { x: 0, y: 1 }];
    const DIAGONAL_COORDS: [Hex; 6] = [
        Hex { x: 2, y: -1 }, Hex { x: 1, y: 1 }, Hex { x: -1, y: 2 }, Hex { x: -2, y: 1 },
        Hex { x: -1, y: -1 }, Hex { x: 1, y: -2 },
    ];

    #[inline]
    fn new(x: i32, y: i32) -> Hex {
        Hex { x, y }
    }

    #[inline]
    fn x(self: Hex) -> i32 {
        self.x
    }

    #[inline]
    fn y(self: Hex) -> i32 {
        self.y
    }

    #[inline]
    fn z(self: Hex) -> i32 {
        -self.x - self.y
    }

    #[inline]
    fn const_sub(self: Hex, rhs: Hex) -> Hex {
        Hex { x: self.x - rhs.x, y: self.y - rhs.y }
    }

    fn length(self: Hex) -> i32 {
        let x = HexMathTrait::abs(self.x);
        let y = HexMathTrait::abs(self.y);
        let z = HexMathTrait::abs(self.z());
        HexMathTrait::max3(x, y, z)
    }

    fn ulength(self: Hex) -> u32 {
        let x = HexMathTrait::unsigned_abs(self.x);
        let y = HexMathTrait::unsigned_abs(self.y);
        let z = HexMathTrait::unsigned_abs(self.z());
        HexMathTrait::max3(x, y, z)
    }

    #[inline]
    fn distance_to(self: Hex, rhs: Hex) -> i32 {
        self.const_sub(rhs).length()
    }

    #[inline]
    fn unsigned_distance_to(self: Hex, rhs: Hex) -> u32 {
        self.const_sub(rhs).ulength()
    }

    fn line_to(self: Hex, other: Hex) -> Span<Hex> {
        // [Compute] The distance, panicking where `hexx`'s `unsigned_distance_to` does
        let delta = self.const_sub(other);
        let distance = delta.ulength();
        let mut line = array![self];
        if distance == 0 {
            return line.span();
        }
        // [Compute] One accumulator per axis: the magnitude `m` of the move after `i` steps is
        // `round(i·d / N)`, `e = 2·i·d + N − c − 2·N·m` stays in `0..2N`, and `c = 1`
        // rounds a tie down. `x` ties toward the larger `x`, `y` toward the smaller `y`.
        let n: u64 = distance.into();
        let (step_x, dx, mut ex) = if delta.x < 0 {
            (1, HexMathTrait::unsigned_abs(delta.x), n)
        } else {
            (-1, HexMathTrait::unsigned_abs(delta.x), n - 1)
        };
        let (step_y, dy, mut ey) = if delta.y < 0 {
            (1, HexMathTrait::unsigned_abs(delta.y), n - 1)
        } else {
            (-1, HexMathTrait::unsigned_abs(delta.y), n)
        };
        let (dx, dy): (u64, u64) = (2 * dx.into(), 2 * dy.into());
        let (tx, ty) = (2 * n - dx, 2 * n - dy);
        // [Compute] Each step moves `x` and `y` toward `other`: no `i32` leaves the endpoints
        let (mut x, mut y) = (self.x, self.y);
        let mut step: u32 = 0;
        while step != distance {
            if ex >= tx {
                ex -= tx;
                x += step_x;
            } else {
                ex += dx;
            }
            if ey >= ty {
                ey -= ty;
                y += step_y;
            } else {
                ey += dy;
            }
            line.append(Hex { x, y });
            step += 1;
        }
        line.span()
    }

    #[inline]
    fn splat(v: i32) -> Hex {
        Hex { x: v, y: v }
    }

    #[inline]
    fn new_cubic(x: i32, y: i32, z: i32) -> Hex {
        HexAssertTrait::cubic_sum(x, y, z);
        Hex { x, y }
    }

    #[inline]
    fn from_array(array: [i32; 2]) -> Hex {
        let [x, y] = array;
        Hex { x, y }
    }

    #[inline]
    fn to_array(self: Hex) -> [i32; 2] {
        [self.x, self.y]
    }

    #[inline]
    fn to_cubic_array(self: Hex) -> [i32; 3] {
        [self.x, self.y, self.z()]
    }

    #[inline]
    fn const_neg(self: Hex) -> Hex {
        Hex { x: -self.x, y: -self.y }
    }

    #[inline]
    fn const_add(self: Hex, rhs: Hex) -> Hex {
        Hex { x: self.x + rhs.x, y: self.y + rhs.y }
    }

    #[inline]
    fn abs(self: Hex) -> Hex {
        Hex { x: HexMathTrait::abs(self.x), y: HexMathTrait::abs(self.y) }
    }

    #[inline]
    fn min(self: Hex, rhs: Hex) -> Hex {
        Hex { x: core::cmp::min(self.x, rhs.x), y: core::cmp::min(self.y, rhs.y) }
    }

    #[inline]
    fn max(self: Hex, rhs: Hex) -> Hex {
        Hex { x: core::cmp::max(self.x, rhs.x), y: core::cmp::max(self.y, rhs.y) }
    }

    #[inline]
    fn dot(self: Hex, rhs: Hex) -> i32 {
        self.x * rhs.x + self.y * rhs.y
    }

    #[inline]
    fn signum(self: Hex) -> Hex {
        Hex { x: HexMathTrait::signum(self.x), y: HexMathTrait::signum(self.y) }
    }

    #[inline]
    fn range_count(range: u32) -> u32 {
        3 * range * (range + 1) + 1
    }

    #[inline]
    fn ring_count(range: u32) -> u32 {
        if range == 0 {
            1
        } else {
            6 * range
        }
    }

    #[inline]
    fn wedge_count(range: u32) -> u32 {
        range * (range + 3) / 2 + 1
    }

    #[inline]
    fn mul_scalar(self: Hex, rhs: i32) -> Hex {
        Hex { x: self.x * rhs, y: self.y * rhs }
    }

    #[inline]
    fn neighbor_coord(direction: EdgeDirection) -> Hex {
        direction.into_hex()
    }

    #[inline]
    fn add_dir(self: Hex, direction: EdgeDirection) -> Hex {
        self.const_add(direction.into_hex())
    }

    #[inline]
    fn neighbor(self: Hex, direction: EdgeDirection) -> Hex {
        self.const_add(direction.into_hex())
    }

    fn all_neighbors(self: Hex) -> [Hex; 6] {
        let [n0, n1, n2, n3, n4, n5] = Self::NEIGHBORS_COORDS;
        [
            self.const_add(n0), self.const_add(n1), self.const_add(n2), self.const_add(n3),
            self.const_add(n4), self.const_add(n5),
        ]
    }

    #[inline]
    fn diagonal_neighbor_coord(direction: VertexDirection) -> Hex {
        direction.into_hex()
    }

    #[inline]
    fn add_diag_dir(self: Hex, direction: VertexDirection) -> Hex {
        self.const_add(direction.into_hex())
    }

    #[inline]
    fn diagonal_neighbor(self: Hex, direction: VertexDirection) -> Hex {
        self.const_add(direction.into_hex())
    }

    fn neighbor_direction(self: Hex, other: Hex) -> Option<EdgeDirection> {
        let mut directions = EdgeDirectionTrait::iter();
        let mut found = None;
        while let Some(direction) = directions.pop_front() {
            if self.neighbor(*direction) == other {
                found = Some(*direction);
                break;
            }
        }
        found
    }

    fn main_diagonal_to(self: Hex, rhs: Hex) -> VertexDirection {
        self.diagonal_way_to(rhs).unwrap()
    }

    fn diagonal_way_to(self: Hex, rhs: Hex) -> DirectionWay<VertexDirection> {
        let [x, y, z] = rhs.const_sub(self).to_cubic_array();
        let (xa, ya, za) = (HexMathTrait::abs(x), HexMathTrait::abs(y), HexMathTrait::abs(z));
        if xa >= ya && xa >= za {
            DirectionWayFromTrait::way_from(
                x < 0, xa == ya, xa == za, VertexDirectionTrait::FLAT_RIGHT,
            )
        } else if ya >= za {
            DirectionWayFromTrait::way_from(
                y < 0, ya == za, ya == xa, VertexDirectionTrait::FLAT_BOTTOM_LEFT,
            )
        } else {
            DirectionWayFromTrait::way_from(
                z < 0, za == xa, za == ya, VertexDirectionTrait::FLAT_TOP_LEFT,
            )
        }
    }

    fn main_direction_to(self: Hex, rhs: Hex) -> EdgeDirection {
        self.way_to(rhs).unwrap()
    }

    fn way_to(self: Hex, rhs: Hex) -> DirectionWay<EdgeDirection> {
        let [x, y, z] = rhs.const_sub(self).to_cubic_array();
        let (x, y, z) = (y - x, z - y, x - z);
        let (xa, ya, za) = (HexMathTrait::abs(x), HexMathTrait::abs(y), HexMathTrait::abs(z));
        if xa >= ya && xa >= za {
            DirectionWayFromTrait::way_from(
                x < 0, xa == ya, xa == za, EdgeDirectionTrait::FLAT_BOTTOM_LEFT,
            )
        } else if ya >= za {
            DirectionWayFromTrait::way_from(y < 0, ya == za, ya == xa, EdgeDirectionTrait::FLAT_TOP)
        } else {
            DirectionWayFromTrait::way_from(
                z < 0, za == xa, za == ya, EdgeDirectionTrait::FLAT_BOTTOM_RIGHT,
            )
        }
    }

    fn all_diagonals(self: Hex) -> [Hex; 6] {
        let [d0, d1, d2, d3, d4, d5] = Self::DIAGONAL_COORDS;
        [
            self.const_add(d0), self.const_add(d1), self.const_add(d2), self.const_add(d3),
            self.const_add(d4), self.const_add(d5),
        ]
    }

    #[inline]
    fn counter_clockwise(self: Hex) -> Hex {
        Hex { x: -self.z(), y: -self.x }
    }

    #[inline]
    fn ccw_around(self: Hex, center: Hex) -> Hex {
        self.const_sub(center).counter_clockwise().const_add(center)
    }

    fn rotate_ccw(self: Hex, m: u32) -> Hex {
        match m % 6 {
            0 => self,
            1 => self.counter_clockwise(),
            2 => self.counter_clockwise().counter_clockwise(),
            3 => self.const_neg(),
            4 => self.clockwise().clockwise(),
            _ => self.clockwise(),
        }
    }

    #[inline]
    fn rotate_ccw_around(self: Hex, center: Hex, m: u32) -> Hex {
        self.const_sub(center).rotate_ccw(m).const_add(center)
    }

    #[inline]
    fn clockwise(self: Hex) -> Hex {
        Hex { x: -self.y, y: -self.z() }
    }

    #[inline]
    fn cw_around(self: Hex, center: Hex) -> Hex {
        self.const_sub(center).clockwise().const_add(center)
    }

    fn rotate_cw(self: Hex, m: u32) -> Hex {
        match m % 6 {
            0 => self,
            1 => self.clockwise(),
            2 => self.clockwise().clockwise(),
            3 => self.const_neg(),
            4 => self.counter_clockwise().counter_clockwise(),
            _ => self.counter_clockwise(),
        }
    }

    #[inline]
    fn rotate_cw_around(self: Hex, center: Hex, m: u32) -> Hex {
        self.const_sub(center).rotate_cw(m).const_add(center)
    }

    #[inline]
    fn reflect_x(self: Hex) -> Hex {
        Hex { x: self.x, y: self.z() }
    }

    #[inline]
    fn reflect_y(self: Hex) -> Hex {
        Hex { x: self.z(), y: self.y }
    }

    #[inline]
    fn reflect_z(self: Hex) -> Hex {
        Hex { x: self.y, y: self.x }
    }

    fn rectiline_to(self: Hex, other: Hex, clockwise: bool) -> Span<Hex> {
        let delta = other.const_sub(self);
        let count = delta.length();
        let [first, second] = self.main_diagonal_to(other).edge_directions();
        // [Compute] `rotate_left(1)` of the pair when counter-clockwise
        let (dir_a, dir_b) = if clockwise {
            (first, second)
        } else {
            (second, first)
        };
        // [Compute] The steps of `dir_a` are the distance between `delta` and the full
        // projection of `dir_b`
        let steps_a = dir_b.mul_scalar(count).distance_to(delta);
        let mut path = array![self];
        let mut p = self;
        let mut i: i32 = 0;
        while i != count {
            p = if i < steps_a {
                p.add_dir(dir_a)
            } else {
                p.add_dir(dir_b)
            };
            path.append(p);
            i += 1;
        }
        path.span()
    }

    fn range(self: Hex, range: u32) -> Span<Hex> {
        HexRangeTrait::collect(self, range, false)
    }

    fn xrange(self: Hex, range: u32) -> Span<Hex> {
        HexRangeTrait::collect(self, range, true)
    }

    fn to_lower_res(self: Hex, radius: u32) -> Hex {
        let [x, y, z] = self.to_cubic_array();
        let area = Self::range_count(radius);
        let shift: i32 = HexShiftTrait::shift(radius).try_into().unwrap();
        let a = HexMathTrait::floor_div(y + shift * x, area);
        let b = HexMathTrait::floor_div(z + shift * y, area);
        let c = HexMathTrait::floor_div(x + shift * z, area);
        Hex { x: HexMathTrait::floor_div(1 + a - b, 3), y: HexMathTrait::floor_div(1 + b - c, 3) }
    }

    fn to_higher_res(self: Hex, radius: u32) -> Hex {
        let range: i32 = radius.try_into().unwrap();
        let [x, y, z] = self.to_cubic_array();
        Hex { x: x * (range + 1) - range * z, y: y * (range + 1) - range * x }
    }

    fn to_local(self: Hex, radius: u32) -> Hex {
        let center = self.to_lower_res(radius).to_higher_res(radius);
        self.const_sub(center)
    }

    #[inline]
    fn wrap_in_range(self: Hex, range: u32) -> Hex {
        self.to_local(range)
    }
}

/// `Debug` of `Hex`, as `hexx`'s: `Hex { x: 1, y: 2, z: -3 }`.
///
/// Mirrors `impl Debug for Hex` (`src/hex/mod.rs:1189`).
pub impl HexDebug of Debug<Hex> {
    fn fmt(self: @Hex, ref f: Formatter) -> Result<(), Error> {
        write!(f, "Hex {{ x: {}, y: {}, z: {} }}", *self.x, *self.y, (*self).z())
    }
}

/// `Hex::shift` (`src/hex/mod.rs:1169`), the constant of the `hexmod` operations: `pub(crate)` in
/// `hexx`, so a crate-private trait here, outside the parity table and the public documentation
/// template. M2-T3's `to_hexmod_coordinates` and `from_hexmod_coordinates` are its readers.
/// Panics when `3 * range + 2` leaves `u32`, where `hexx` wraps in a release build and panics in a
/// debug build.
#[generate_trait]
pub(crate) impl HexShiftImpl of HexShiftTrait {
    #[inline]
    fn shift(range: u32) -> u32 {
        3 * range + 2
    }
}

/// The span builder of `range` and `xrange`: private, one loop for both.
#[generate_trait]
impl HexRangeImpl of HexRangeTrait {
    /// The coordinates within `range` of `center`, `x` ascending then `y` ascending, without
    /// `center` itself when `skip_center`. Panics where `range_count(range)` does, as `hexx`'s
    /// eager `count` does.
    fn collect(center: Hex, range: u32, skip_center: bool) -> Span<Hex> {
        let _ = HexTrait::range_count(range);
        let radius: i32 = range.try_into().unwrap();
        let mut hexes = array![];
        let mut x = -radius;
        while x <= radius {
            // [Compute] `max(-radius, -x - radius)` and `min(radius, radius - x)`
            let mut y = if x < 0 {
                -radius - x
            } else {
                -radius
            };
            let y_max = if x > 0 {
                radius - x
            } else {
                radius
            };
            while y <= y_max {
                if !(skip_center && x == 0 && y == 0) {
                    hexes.append(Hex { x: center.x + x, y: center.y + y });
                }
                y += 1;
            }
            x += 1;
        }
        hexes.span()
    }
}

/// The checks of `Hex`.
#[generate_trait]
impl HexAssertImpl of HexAssertTrait {
    /// `x + y + z == 0`, as `Hex::new_cubic` asserts it (`src/hex/mod.rs:248`).
    #[inline]
    fn cubic_sum(x: i32, y: i32, z: i32) {
        assert(x + y + z == 0, errors::HEX_CUBIC_SUM);
    }
}

/// The scalar helpers of `length` and `ulength`: private, what `i32::abs`, `i32::unsigned_abs`
/// and the three-way maximum of `src/hex/mod.rs:568-607` are in Rust.
#[generate_trait]
impl HexMathImpl of HexMathTrait {
    /// `|v|`, panicking on `i32::MIN` as `i32::abs` does in a debug build.
    #[inline]
    fn abs(v: i32) -> i32 {
        if v < 0 {
            -v
        } else {
            v
        }
    }

    /// `|v|` as a `u32`, exact on `i32::MIN` (`i32::unsigned_abs`).
    #[inline]
    fn unsigned_abs(v: i32) -> u32 {
        if v < 0 {
            // `-(v + 1)` is in `0..=i32::MAX` for every negative `v`.
            let magnitude: u32 = (-(v + 1)).try_into().unwrap();
            magnitude + 1
        } else {
            v.try_into().unwrap()
        }
    }

    /// `floor(n / d)` for `d > 0`, exact on all of `i32`: the exact counterpart of `hexx`'s
    /// `(n as f32 / d as f32).floor() as i32`.
    #[inline]
    fn floor_div(n: i32, d: u32) -> i32 {
        if n >= 0 {
            let n: u32 = n.try_into().unwrap();
            (n / d).try_into().unwrap()
        } else {
            // `-(n + 1)` is in `0..=i32::MAX`; `floor(n / d) = -((-n - 1) / d) - 1`
            let above: u32 = (-(n + 1)).try_into().unwrap();
            let quotient: i32 = (above / d).try_into().unwrap();
            -quotient - 1
        }
    }

    /// The sign of `v`: `0`, `1` or `-1` (`i32::signum`).
    #[inline]
    fn signum(v: i32) -> i32 {
        if v < 0 {
            -1
        } else if v > 0 {
            1
        } else {
            0
        }
    }

    /// The largest of three values, in the branch order of `hexx`.
    #[inline]
    fn max3<T, +PartialOrd<T>, +Copy<T>, +Drop<T>>(x: T, y: T, z: T) -> T {
        if x >= y && x >= z {
            x
        } else if y >= x && y >= z {
            y
        } else {
            z
        }
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::direction::edge_direction::EdgeDirectionTrait;
    use crate::direction::vertex_direction::VertexDirectionTrait;
    use crate::direction::way::{DirectionWay, DirectionWayTrait};
    use super::{Hex, HexShiftTrait, HexTrait, hex};

    #[generate_trait]
    impl Line of LineTrait {
        /// The line reversed.
        fn reversed(line: Span<Hex>) -> Span<Hex> {
            let mut back = array![];
            let mut i = line.len();
            while i != 0 {
                i -= 1;
                back.append(*line.at(i));
            }
            back.span()
        }
    }

    /// R-N5-5 (audit pass 2, finding 25): no tie, `N = 7`; sample 2 is `(8_000_000, 2)` exactly,
    /// where `hexx` returns `(8_000_001, 2)` (`docs/deviations/line_ties.md`).
    #[test]
    #[available_gas(l2_gas: 55157)]
    fn test_hex_line_to_regression_r_n5_5() {
        let line = HexTrait::new(8_000_000, 0).line_to(HexTrait::new(8_000_001, 6));
        assert!(line.len() == 8);
        assert!(*line.at(2) == HexTrait::new(8_000_000, 2));
        assert!(*line.at(7) == HexTrait::new(8_000_001, 6));
    }

    /// R-N5-6 (audit pass 1, finding 8): beyond `2^24` the ends are exact, where `hexx` starts at
    /// `(16_777_216, 0)`.
    #[test]
    #[available_gas(l2_gas: 21063)]
    fn test_hex_line_to_regression_r_n5_6() {
        let line = HexTrait::new(16_777_217, 0).line_to(HexTrait::new(16_777_218, 0));
        assert!(line == array![HexTrait::new(16_777_217, 0), HexTrait::new(16_777_218, 0)].span());
    }

    /// The ends: one element for a coordinate with itself, `N + 1` elements, `self` first and
    /// `other` last, and the extremes of `i32` where the difference stays in `i32`.
    #[test]
    #[available_gas(l2_gas: 220038)]
    fn test_hex_line_to_ends() {
        let a = HexTrait::new(-3, 7);
        assert!(a.line_to(a) == array![a].span());
        let max: i32 = 0x7fffffff;
        let ends: [(Hex, Hex); 3] = [
            (HexTrait::new(0, 0), HexTrait::new(5, 0)),
            (HexTrait::new(max - 3, 0), HexTrait::new(max, -3)),
            (HexTrait::new(-max, 1), HexTrait::new(-max + 2, -1)),
        ];
        for (a, b) in ends.span() {
            let line = a.line_to(*b);
            assert!(line.len() == a.unsigned_distance_to(*b) + 1);
            assert!(*line.at(0) == *a);
            assert!(*line.at(line.len() - 1) == *b);
        }
    }

    /// The tie rule: `Δ = (3, 3)` has a tie at every odd step, resolved to the smaller `y`; on a
    /// row, `Δ = (−1, 2)` ties at its midpoint to the larger `x` (R-N5-2 in the mirror frame).
    #[test]
    #[available_gas(l2_gas: 90500)]
    fn test_hex_line_to_ties() {
        let line = HexTrait::new(0, 0).line_to(HexTrait::new(3, 3));
        let expected = array![
            HexTrait::new(0, 0), HexTrait::new(1, 0), HexTrait::new(1, 1), HexTrait::new(2, 1),
            HexTrait::new(2, 2), HexTrait::new(3, 2), HexTrait::new(3, 3),
        ];
        assert!(line == expected.span());
        let line = HexTrait::new(-5, 3).line_to(HexTrait::new(-6, 5));
        assert!(
            line == array![HexTrait::new(-5, 3), HexTrait::new(-5, 4), HexTrait::new(-6, 5)].span(),
        );
    }

    /// Symmetric and translation-invariant, on every pair of `[-3, 3]²`.
    #[test]
    #[available_gas(l2_gas: 559849532)]
    fn test_hex_line_to_symmetry_translation() {
        let shift = HexTrait::new(1_000_003, -999_997);
        let mut ax: i32 = -3;
        while ax != 4 {
            let mut ay: i32 = -3;
            while ay != 4 {
                let a = HexTrait::new(ax, ay);
                let mut bx: i32 = -3;
                while bx != 4 {
                    let mut by: i32 = -3;
                    while by != 4 {
                        let b = HexTrait::new(bx, by);
                        let line = a.line_to(b);
                        assert!(LineTrait::reversed(b.line_to(a)) == line);
                        let moved = HexTrait::new(ax + shift.x, ay + shift.y)
                            .line_to(HexTrait::new(bx + shift.x, by + shift.y));
                        let mut i = 0;
                        while i != line.len() {
                            let h = *line.at(i);
                            assert!(*moved.at(i) == HexTrait::new(h.x + shift.x, h.y + shift.y));
                            i += 1;
                        }
                        by += 1;
                    }
                    bx += 1;
                }
                ay += 1;
            }
            ax += 1;
        }
    }

    /// The panics of `unsigned_distance_to`: a difference that leaves `i32`.
    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_line_to_revert_overflow() {
        let max: i32 = 0x7fffffff;
        HexTrait::new(max, 0).line_to(HexTrait::new(-1, 0));
    }

    /// The constants of `Hex` (`src/hex/mod.rs:95-186`).
    #[test]
    #[available_gas(l2_gas: 31710)]
    fn test_hex_constants_l_m2() {
        assert!(HexTrait::ORIGIN == HexTrait::ZERO);
        assert!(HexTrait::ONE == HexTrait::new(1, 1));
        assert!(HexTrait::NEG_ONE == HexTrait::new(-1, -1));
        assert!(HexTrait::X == HexTrait::new(1, 0));
        assert!(HexTrait::NEG_X == HexTrait::new(-1, 0));
        assert!(HexTrait::Y == HexTrait::new(0, 1));
        assert!(HexTrait::NEG_Y == HexTrait::new(0, -1));
        let incr_x = HexTrait::INCR_X;
        assert!(incr_x.span() == array![HexTrait::new(1, 0), HexTrait::new(1, -1)].span());
        let decr_z = HexTrait::DECR_Z;
        assert!(decr_z.span() == array![HexTrait::new(1, 0), HexTrait::new(0, 1)].span());
        let diagonal = HexTrait::DIAGONAL_COORDS;
        assert!(diagonal.span().len() == 6);
        assert!(*diagonal.span().at(0) == HexTrait::new(2, -1));
        assert!(*diagonal.span().at(5) == HexTrait::new(1, -2));
    }

    /// The constructors and the array forms: `hex`, `splat`, `from_array`, `to_array`,
    /// `to_cubic_array`, `new_cubic`.
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_hex_constructors() {
        assert!(hex(3, -5) == HexTrait::new(3, -5));
        assert!(HexTrait::splat(7) == HexTrait::new(7, 7));
        assert!(HexTrait::from_array([3, -5]) == HexTrait::new(3, -5));
        assert!(HexTrait::new(3, -5).to_array() == [3, -5]);
        assert!(HexTrait::new(3, 5).to_cubic_array() == [3, 5, -8]);
        assert!(HexTrait::new_cubic(3, 5, -8) == HexTrait::new(3, 5));
    }

    /// `new_cubic` asserts the cubic sum.
    #[test]
    #[available_gas(l2_gas: 14679)]
    #[should_panic(expected: ('Hex: cubic sum',))]
    fn test_hex_new_cubic_revert_sum() {
        HexTrait::new_cubic(3, 5, -7);
    }

    /// The component-wise items.
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_hex_component_items() {
        let a = HexTrait::new(-3, 7);
        let b = HexTrait::new(5, -2);
        assert!(a.const_neg() == HexTrait::new(3, -7));
        assert!(a.const_add(b) == HexTrait::new(2, 5));
        assert!(a.abs() == HexTrait::new(3, 7));
        assert!(a.min(b) == HexTrait::new(-3, -2));
        assert!(a.max(b) == HexTrait::new(5, 7));
        assert!(a.dot(b) == -29);
        assert!(a.signum() == HexTrait::new(-1, 1));
        assert!(HexTrait::ZERO.signum() == HexTrait::ZERO);
        assert!(a.mul_scalar(-4) == HexTrait::new(12, -28));
    }

    /// The counts against the plain definition: a range is the sum of its rings, a wedge of its
    /// rings' edges (`k + 1` tiles on the ring `k`).
    #[test]
    #[available_gas(l2_gas: 772013)]
    fn test_hex_counts_oracle() {
        let mut range_sum: u32 = 1;
        let mut wedge_sum: u32 = 1;
        assert!(HexTrait::ring_count(0) == 1);
        let mut range: u32 = 0;
        while range != 65 {
            if range != 0 {
                range_sum += HexTrait::ring_count(range);
                wedge_sum += range + 1;
            }
            assert!(HexTrait::range_count(range) == range_sum);
            assert!(HexTrait::wedge_count(range) == wedge_sum);
            assert!(HexShiftTrait::shift(range) == 3 * range + 2);
            range += 1;
        }
        assert!(HexTrait::ring_count(5) == 30);
    }

    /// The neighbours: `all_neighbors` is `neighbor` in every direction, `neighbor` is `add_dir`
    /// of the direction's coordinates, and each is at distance one.
    #[test]
    #[available_gas(l2_gas: 178028)]
    fn test_hex_neighbors() {
        let h = HexTrait::new(10, -5);
        let all = h.all_neighbors();
        let directions = EdgeDirectionTrait::ALL_DIRECTIONS;
        let mut i = 0;
        while i != 6 {
            let direction = *directions.span().at(i);
            let neighbor = *all.span().at(i);
            assert!(h.neighbor(direction) == neighbor);
            assert!(h.add_dir(direction) == neighbor);
            assert!(HexTrait::neighbor_coord(direction) == neighbor.const_sub(h));
            assert!(h.distance_to(neighbor) == 1);
            i += 1;
        }
        assert!(h.neighbor(EdgeDirectionTrait::FLAT_BOTTOM) == HexTrait::new(10, -4));
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_const_add_revert_overflow() {
        HexTrait::new(0x7fffffff, 0).const_add(HexTrait::new(1, 0));
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_const_neg_revert_min() {
        HexTrait::new(-0x7fffffff - 1, 0).const_neg();
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_abs_revert_min() {
        HexTrait::new(0, -0x7fffffff - 1).abs();
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_to_cubic_array_revert_z() {
        HexTrait::new(-0x7fffffff - 1, 0).to_cubic_array();
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_dot_revert_overflow() {
        HexTrait::new(0x10000, 0).dot(HexTrait::new(0x10000, 0));
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_mul_scalar_revert_overflow() {
        HexTrait::new(0x7fffffff, 0).mul_scalar(2);
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_range_count_revert_overflow() {
        HexTrait::range_count(0xffffffff);
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_ring_count_revert_overflow() {
        HexTrait::ring_count(715_827_883);
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_wedge_count_revert_overflow() {
        HexTrait::wedge_count(0xffffffff);
    }

    #[test]
    #[available_gas(l2_gas: 9744)]
    #[should_panic]
    fn test_hex_neighbor_revert_overflow() {
        HexTrait::new(0x7fffffff, 0).neighbor(EdgeDirectionTrait::X);
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_all_neighbors_revert_overflow() {
        HexTrait::new(0, 0x7fffffff).all_neighbors();
    }

    // Benchmarks of M2-T0 (LIB-06), 100 repetitions per test, one call per repetition: per call =
    // (test − matching baseline) / 100. Targets (`L`, `U = ceil(1.25 L)`, plan §7 has none for
    // L-M2), derived from the L-M1 measurements of `bench_mirror` (`z` 2,059 for two operations,
    // `const_sub` 2,930, `EdgeDirection::into_hex` 1,411), written before the first measurement:
    //
    // | function | `L` | `U` |
    // |---|---|---|
    // | `const_add`, `mul_scalar` | 2,930 (as `const_sub`) | 3,663 |
    // | `const_neg`, `to_cubic_array` | 2,059 (as `z`) | 2,574 |
    // | `new_cubic`, `dot` | 3,090 (three operations) | 3,863 |
    // | `range_count`, `ring_count`, `wedge_count` | 4,120 (four operations) | 5,150 |
    // | `neighbor` | 4,341 (`into_hex` 1,411 + `const_add` 2,930) | 5,427 |
    // | `all_neighbors` | 26,046 (6 × `neighbor`) | 32,558 |

    const REPS: u8 = 100;

    /// The loop, the accumulator and the two operands `(-n, -n)` and `(n, n)`.
    #[test]
    #[available_gas(l2_gas: 468594)]
    fn bench_hex_baseline_operands() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.x + b.y;
        }
        assert!(acc == 0);
    }

    /// The loop, the accumulator and the operand `range = 1 + n` (the longest branch of
    /// `ring_count`: `range != 0`).
    #[test]
    #[available_gas(l2_gas: 249312)]
    fn bench_hex_baseline_range() {
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let range: u32 = 1 + n.into();
            acc += range;
        }
        assert!(acc == 5050);
    }

    #[test]
    #[available_gas(l2_gas: 623532)]
    fn bench_hex_const_add() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.const_add(b).x + b.y;
        }
        assert!(acc == 4950);
    }

    #[test]
    #[available_gas(l2_gas: 623532)]
    fn bench_hex_mul_scalar() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.mul_scalar(-3).x + b.y;
        }
        assert!(acc == 4950 * 4);
    }

    #[test]
    #[available_gas(l2_gas: 521661)]
    fn bench_hex_const_neg() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.const_neg().x + b.y;
        }
        assert!(acc == 9900);
    }

    #[test]
    #[available_gas(l2_gas: 577794)]
    fn bench_hex_to_cubic_array() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            let [_, _, z] = a.to_cubic_array();
            acc += z + b.y;
        }
        assert!(acc == 14850);
    }

    #[test]
    #[available_gas(l2_gas: 709758)]
    fn bench_hex_new_cubic() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += HexTrait::new_cubic(a.x, a.y, b.x + b.y).x + b.y;
        }
        assert!(acc == 0);
    }

    #[test]
    #[available_gas(l2_gas: 700455)]
    fn bench_hex_dot() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.dot(b) + b.y;
        }
        assert!(acc == 0 - 656700 + 4950);
    }

    #[test]
    #[available_gas(l2_gas: 419580)]
    fn bench_hex_range_count() {
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let range: u32 = 1 + n.into();
            acc += HexTrait::range_count(range);
        }
        assert!(acc != 0);
    }

    #[test]
    #[available_gas(l2_gas: 350144)]
    fn bench_hex_ring_count() {
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let range: u32 = 1 + n.into();
            acc += HexTrait::ring_count(range);
        }
        assert!(acc == 30300);
    }

    #[test]
    #[available_gas(l2_gas: 493385)]
    fn bench_hex_wedge_count() {
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let range: u32 = 1 + n.into();
            acc += HexTrait::wedge_count(range);
        }
        assert!(acc != 0);
    }

    #[test]
    #[available_gas(l2_gas: 790923)]
    fn bench_hex_neighbor() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.neighbor(EdgeDirectionTrait::NEG_X_Y).x + b.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 1207626)]
    fn bench_hex_all_neighbors() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            let [first, _, _, _, _, _] = a.all_neighbors();
            acc += first.x + b.y;
        }
        assert!(acc != 1);
    }

    /// The oracles of M2-T2: plain, obviously correct versions of the optimised or repeated items.
    #[generate_trait]
    impl Oracle of OracleTrait {
        /// The hexes within `radius` of `center` by definition: every hex of the square
        /// `[-radius, radius]²` around it whose distance is at most `radius`, `x` then `y`.
        fn within(center: Hex, radius: i32, skip_center: bool) -> Array<Hex> {
            let mut hexes = array![];
            let mut x = -radius;
            while x <= radius {
                let mut y = -radius;
                while y <= radius {
                    let h = HexTrait::new(center.x + x, center.y + y);
                    if h.distance_to(center) <= radius && !(skip_center && h == center) {
                        hexes.append(h);
                    }
                    y += 1;
                }
                x += 1;
            }
            hexes
        }

        /// `m` single clockwise rotations around the origin.
        fn repeat_cw(h: Hex, m: u32) -> Hex {
            let mut h = h;
            let mut i = 0;
            while i != m {
                h = h.clockwise();
                i += 1;
            }
            h
        }

        /// `m` single counter-clockwise rotations around the origin.
        fn repeat_ccw(h: Hex, m: u32) -> Hex {
            let mut h = h;
            let mut i = 0;
            while i != m {
                h = h.counter_clockwise();
                i += 1;
            }
            h
        }

        /// Whether `got` is `want`, element by element.
        fn same(got: Span<Hex>, want: Span<Hex>) -> bool {
            if got.len() != want.len() {
                return false;
            }
            let mut i = 0;
            let mut equal = true;
            while i != got.len() {
                if *got.at(i) != *want.at(i) {
                    equal = false;
                    break;
                }
                i += 1;
            }
            equal
        }
    }

    /// The sample of the oracles: the origin, both signs, the axes.
    fn sample() -> Span<Hex> {
        array![
            HexTrait::new(0, 0), HexTrait::new(1, 2), HexTrait::new(-7, 2), HexTrait::new(3, -5),
            HexTrait::new(-4, -6), HexTrait::new(9, 0), HexTrait::new(0, -8),
        ]
            .span()
    }

    /// `range` and `xrange` against the per-hex definition, radii `0..=8`, order included.
    #[test]
    #[available_gas(l2_gas: 45546018)]
    fn test_hex_range_oracle() {
        let center = HexTrait::new(7, -3);
        let mut r: u32 = 0;
        while r != 9 {
            let radius: i32 = r.try_into().unwrap();
            let want = OracleTrait::within(center, radius, false);
            assert!(want.len() == HexTrait::range_count(r));
            assert!(OracleTrait::same(center.range(r), want.span()));
            let want = OracleTrait::within(center, radius, true);
            assert!(want.len() == HexTrait::range_count(r) - 1);
            assert!(OracleTrait::same(center.xrange(r), want.span()));
            r += 1;
        }
    }

    /// `range` of `hexx`'s doc: 1 and 7 hexes, `x` ascending then `y` ascending.
    #[test]
    #[available_gas(l2_gas: 255917)]
    fn test_hex_range_doc() {
        let h = HexTrait::new(12, 34);
        assert!(h.range(0).len() == 1 && h.xrange(0).len() == 0);
        assert!(h.range(1).len() == 7 && h.xrange(1).len() == 6);
        assert!(*h.range(1).at(0) == HexTrait::new(11, 34));
        assert!(*h.range(1).at(3) == HexTrait::new(12, 34));
        assert!(*h.range(1).at(6) == HexTrait::new(13, 34));
    }

    /// Each `rotate_*` against `m` repeated single rotations, around the origin and around a
    /// center, for `m` in `0..=13` and 255.
    #[test]
    #[available_gas(l2_gas: 36834588)]
    fn test_hex_rotate_oracle() {
        let center = HexTrait::new(-2, 5);
        let mut points = sample();
        while let Some(h) = points.pop_front() {
            let h = *h;
            let mut m: u32 = 0;
            while m != 256 {
                if m == 14 {
                    m = 255;
                }
                assert!(h.rotate_cw(m) == OracleTrait::repeat_cw(h, m));
                assert!(h.rotate_ccw(m) == OracleTrait::repeat_ccw(h, m));
                let moved = h.const_sub(center);
                assert!(
                    h
                        .rotate_cw_around(center, m) == OracleTrait::repeat_cw(moved, m)
                        .const_add(center),
                );
                assert!(
                    h
                        .rotate_ccw_around(center, m) == OracleTrait::repeat_ccw(moved, m)
                        .const_add(center),
                );
                m += 1;
            }
            assert!(h.cw_around(center) == h.rotate_cw_around(center, 1));
            assert!(h.ccw_around(center) == h.rotate_ccw_around(center, 1));
            assert!(h.clockwise().counter_clockwise() == h);
        }
    }

    /// The examples of `hexx`'s documentation, and the reflections.
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_hex_rotate_reflect_doc() {
        let p = HexTrait::new(1, 2);
        assert!(p.counter_clockwise() == HexTrait::new(3, -1));
        assert!(p.clockwise() == HexTrait::new(-2, 3));
        assert!(p.reflect_x() == HexTrait::new(1, -3));
        assert!(p.reflect_y() == HexTrait::new(-3, 2));
        assert!(p.reflect_z() == HexTrait::new(2, 1));
        assert!(p.reflect_x().reflect_x() == p);
        assert!(p.reflect_y().reflect_y() == p);
        assert!(p.reflect_z().reflect_z() == p);
    }

    /// The diagonals: `all_diagonals` is `diagonal_neighbor` in every direction, at distance two.
    #[test]
    #[available_gas(l2_gas: 167328)]
    fn test_hex_diagonals() {
        let h = HexTrait::new(10, 5);
        assert!(h.diagonal_neighbor(VertexDirectionTrait::FLAT_RIGHT) == HexTrait::new(12, 4));
        let all = h.all_diagonals();
        let mut directions = VertexDirectionTrait::iter();
        let mut i = 0;
        while let Some(direction) = directions.pop_front() {
            let direction = *direction;
            let diagonal = *all.span().at(i);
            assert!(h.diagonal_neighbor(direction) == diagonal);
            assert!(h.add_diag_dir(direction) == diagonal);
            assert!(HexTrait::diagonal_neighbor_coord(direction) == diagonal.const_sub(h));
            assert!(h.distance_to(diagonal) == 2);
            i += 1;
        }
    }

    /// `neighbor_direction`: the direction of each neighbour, `None` for the others and for `self`.
    #[test]
    #[available_gas(l2_gas: 504819)]
    fn test_hex_neighbor_direction() {
        let h = HexTrait::new(10, 5);
        let mut directions = EdgeDirectionTrait::iter();
        while let Some(direction) = directions.pop_front() {
            let direction = *direction;
            assert!(h.neighbor_direction(h.neighbor(direction)) == Some(direction));
        }
        assert!(h.neighbor_direction(h).is_none());
        assert!(h.neighbor_direction(HexTrait::new(12, 5)).is_none());
        let mut diagonals = VertexDirectionTrait::iter();
        while let Some(direction) = diagonals.pop_front() {
            assert!(h.neighbor_direction(h.diagonal_neighbor(*direction)).is_none());
        }
    }

    /// `rectiline_to` against its properties, on every ordered pair of a radius-one hexagon, both
    /// senses: `distance + 1` hexes, the ends included, each step a neighbour in one of the two
    /// directions of `main_diagonal_to(...).edge_directions()`.
    #[test]
    #[available_gas(l2_gas: 11281074)]
    fn test_hex_rectiline_to_properties() {
        let hexagon = HexTrait::new(5, -3).range(1);
        let mut senders = hexagon;
        while let Some(a) = senders.pop_front() {
            let a = *a;
            let mut receivers = hexagon;
            while let Some(b) = receivers.pop_front() {
                let b = *b;
                let [first, second] = a.main_diagonal_to(b).edge_directions();
                let mut sense = 0_u8;
                while sense != 2 {
                    let path = a.rectiline_to(b, sense == 0);
                    assert!(path.len() == a.unsigned_distance_to(b) + 1);
                    assert!(*path.at(0) == a && *path.at(path.len() - 1) == b);
                    let mut i = 1;
                    while i != path.len() {
                        let step = (*path.at(i - 1)).neighbor_direction(*path.at(i));
                        let step = step.unwrap();
                        assert!(step == first || step == second);
                        i += 1;
                    }
                    sense += 1;
                }
            }
        }
    }

    /// The straight case of `hexx`'s documentation: `(0, 0)` to `(5, 0)`, six hexes.
    #[test]
    #[available_gas(l2_gas: 51125)]
    fn test_hex_rectiline_to_doc() {
        let path = HexTrait::new(0, 0).rectiline_to(HexTrait::new(5, 0), true);
        assert!(path.len() == 6);
        assert!(*path.at(0) == HexTrait::new(0, 0) && *path.at(5) == HexTrait::new(5, 0));
    }

    /// `way_to` and `diagonal_way_to`: a clear wedge is a single direction, a boundary a tie that
    /// contains both, and the main direction is the first one.
    #[test]
    #[available_gas(l2_gas: 455144)]
    fn test_hex_ways() {
        let origin = HexTrait::new(0, 0);
        let mut directions = EdgeDirectionTrait::iter();
        while let Some(direction) = directions.pop_front() {
            let direction = *direction;
            let far = direction.into_hex().mul_scalar(5);
            assert!(origin.way_to(far).contains(@direction));
            assert!(origin.main_direction_to(far) == direction);
        }
        let mut diagonals = VertexDirectionTrait::iter();
        while let Some(direction) = diagonals.pop_front() {
            let direction = *direction;
            let far = direction.into_hex().mul_scalar(5);
            assert!(origin.diagonal_way_to(far).contains(@direction));
            assert!(origin.main_diagonal_to(far) == direction);
        }
        // Between two edge directions: `(1, 1)` is the vertex direction `Y`... a tie of the edges
        match origin.way_to(HexTrait::new(1, 1)) {
            DirectionWay::Tie(_) => {},
            DirectionWay::Single(_) => panic!("no tie"),
        }
        match origin.way_to(HexTrait::new(2, 1)) {
            DirectionWay::Tie(_) => panic!("tie"),
            DirectionWay::Single(_) => {},
        }
    }

    /// The resolutions: a hexagon of radius `r` is its parent's child within `r`, `to_local` is
    /// the offset from the parent's center, and `wrap_in_range` lands within the range and keeps
    /// the hexes already inside.
    #[test]
    #[available_gas(l2_gas: 79719707)]
    fn test_hex_resolution_properties() {
        let coord = HexTrait::new(23, 45);
        let parent = coord.to_lower_res(5);
        assert!(coord.distance_to(parent.to_higher_res(5)) <= 5);
        assert!(coord.to_higher_res(5).to_local(5) == HexTrait::ZERO);
        let mut radius: u32 = 1;
        while radius != 7 {
            let r: i32 = radius.try_into().unwrap();
            let mut points = HexTrait::new(-11, 9).range(3);
            while let Some(p) = points.pop_front() {
                let p = *p;
                let parent = p.to_lower_res(radius);
                let center = parent.to_higher_res(radius);
                assert!(p.distance_to(center) <= r);
                assert!(p.to_local(radius) == p.const_sub(center));
                assert!(p.wrap_in_range(radius) == p.to_local(radius));
                assert!(p.wrap_in_range(radius).length() <= r);
                // The centers are fixed points of the parent map
                assert!(center.to_lower_res(radius) == parent);
            }
            let mut inside = HexTrait::ZERO.range(radius);
            while let Some(p) = inside.pop_front() {
                assert!(*p == (*p).wrap_in_range(radius));
            }
            radius += 1;
        }
    }

    /// `to_lower_res` floors on negative values (a truncation gives `(0, -2)` for `(-6, -6)`).
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_hex_to_lower_res_floor() {
        assert!(HexTrait::new(-6, -6).to_lower_res(1) == HexTrait::new(-1, -3));
        assert!(HexTrait::new(-6, -4).to_lower_res(1) == HexTrait::new(-1, -3));
        assert!(HexTrait::new(0, 0).to_lower_res(1) == HexTrait::new(0, 0));
        assert!(HexTrait::new(1, 0).to_lower_res(1) == HexTrait::new(0, 0));
        assert!(HexTrait::new(2, -1).to_lower_res(0) == HexTrait::new(2, -1));
        assert!(HexTrait::new(-5, 3).to_lower_res(0) == HexTrait::new(-5, 3));
    }

    /// `Debug` prints what `hexx`'s prints: `x`, `y` and `z`.
    #[test]
    #[available_gas(l2_gas: 259445)]
    fn test_hex_debug() {
        assert!(format!("{:?}", HexTrait::new(1, 2)) == "Hex { x: 1, y: 2, z: -3 }");
        assert!(format!("{:?}", HexTrait::new(-4, 0)) == "Hex { x: -4, y: 0, z: 4 }");
        assert!(format!("{:?}", HexTrait::ZERO) == "Hex { x: 0, y: 0, z: 0 }");
    }

    #[test]
    #[available_gas(l2_gas: 9744)]
    #[should_panic]
    fn test_hex_diagonal_neighbor_revert_overflow() {
        HexTrait::new(0x7fffffff, 0).diagonal_neighbor(VertexDirectionTrait::FLAT_RIGHT);
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_all_diagonals_revert_overflow() {
        HexTrait::new(0, 0x7fffffff).all_diagonals();
    }

    #[test]
    #[available_gas(l2_gas: 13818)]
    #[should_panic]
    fn test_hex_neighbor_direction_revert_overflow() {
        HexTrait::new(0x7fffffff, 0).neighbor_direction(HexTrait::ZERO);
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_way_to_revert_overflow() {
        HexTrait::new(0x7fffffff, 0).way_to(HexTrait::new(-0x7fffffff, 0));
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_diagonal_way_to_revert_overflow() {
        HexTrait::new(0x7fffffff, 0).diagonal_way_to(HexTrait::new(-0x7fffffff, 0));
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_rotate_cw_revert_z() {
        HexTrait::new(-0x7fffffff - 1, 0).rotate_cw(1);
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_reflect_x_revert_z() {
        HexTrait::new(-0x7fffffff - 1, 0).reflect_x();
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_rectiline_to_revert_overflow() {
        HexTrait::new(0x7fffffff, 0).rectiline_to(HexTrait::new(-0x7fffffff, 0), true);
    }

    /// `range_count(37_837)` leaves `u32`: `range` and `xrange` panic before building anything.
    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_range_revert_count() {
        HexTrait::ZERO.range(37_837);
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_xrange_revert_count() {
        HexTrait::ZERO.xrange(37_837);
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_to_lower_res_revert_count() {
        HexTrait::ZERO.to_lower_res(37_837);
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_to_lower_res_revert_overflow() {
        HexTrait::new(0x7fffffff, 0).to_lower_res(1);
    }

    /// `hexx` wraps `radius` into `i32`; this port panics above `i32::MAX`.
    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_hex_to_higher_res_revert_radius() {
        HexTrait::ZERO.to_higher_res(0x80000000);
    }

    // Benchmarks of M2-T2 (LIB-06), 100 repetitions per test, one call per repetition, per call =
    // (test − matching baseline) / 100; `range`, `xrange` and `rectiline_to` run once, per call =
    // test − 7,610 (an empty test's entry cost, the measured minimum of the `#[should_panic]`
    // tests). Targets (`L`, `U = ceil(1.25 L)`) derived from the L-M1 measurements of
    // `bench_mirror` and the M2-T0/M2-T1 benches of this file (`i32` operation 1,030, `const_sub`
    // 2,930, `z` and `const_neg` 2,059, `distance_to` 8,722, `neighbor` 4,341, `way_from` 4,683,
    // `range_count`
    // 4,120, a span built by a loop 7,358 per element), written before the first measurement:
    //
    // | function | case | `L` | `U` |
    // |---|---|---|---|
    // | `way_to` | a tie | 24,092 | 30,115 |
    // | `main_direction_to` | a tie | 24,092 + `unwrap` | 30,115 |
    // | `diagonal_way_to` | a tie | 20,002 | 25,003 |
    // | `main_diagonal_to` | a tie | 20,002 + `unwrap` | 25,003 |
    // | `neighbor_direction` | not a neighbour | 32,226 | 40,283 |
    // | `rotate_cw`, `rotate_ccw` | `m = 4` | 9,338 | 11,673 |
    // | `rotate_cw_around` | `m = 4` | 15,198 | 18,998 |
    // | `range` | radius 6 | 934,466 | 1,168,083 |
    // | `rectiline_to` | distance 20 | 187,332 | 234,165 |
    // | `to_lower_res` | radius 6 | 22,659 | 28,324 |
    // | `to_local`, `wrap_in_range` | radius 6 | 33,828 | 42,285 |
    // | `diagonal_neighbor` | | 4,341 (as `neighbor`) | 5,427 |
    // | `all_diagonals` | | 26,046 (6 × `neighbor`) | 32,558 |
    // | `counter_clockwise`, `clockwise` | | 4,120 (`z` + two negations) | 5,150 |
    // | `ccw_around`, `cw_around` | | 9,980 (`const_sub` + rotation + `const_add`) | 12,475 |
    // | `reflect_x`, `reflect_y` | | 2,059 (as `z`) | 2,574 |
    // | `to_higher_res` | | 8,239 (`z` + 6 operations) | 10,299 |
    // | `xrange` | radius 6 | 934,466 (as `range`) | 1,168,083 |
    //
    // `reflect_z` swaps two fields and `add_diag_dir`, `diagonal_neighbor_coord`, `ccw_around`'s
    // peers are the bodies measured above: no bench of their own.

    /// The loop, the accumulator and the operands `(-n, -n)` and `(n, -n)`: the tie of
    /// `diagonal_way_to` (`b − a = (2n, 0)`).
    #[test]
    #[available_gas(l2_gas: 558369)]
    fn bench_hex_baseline_tie() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), 0 - n.into());
            acc += a.x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 722043)]
    fn bench_hex_diagonal_neighbor() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.diagonal_neighbor(VertexDirectionTrait::FLAT_RIGHT).x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 1558368)]
    fn bench_hex_all_diagonals() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += {
                let [first, _, _, _, _, _] = a.all_diagonals();
                first.x + b.y
            };
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 4253372)]
    fn bench_hex_neighbor_direction() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += match a.neighbor_direction(b) {
                Some(_) => 1,
                None => 0,
            } + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 631134)]
    fn bench_hex_counter_clockwise() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.counter_clockwise().x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 631134)]
    fn bench_hex_clockwise() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.clockwise().x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 949221)]
    fn bench_hex_ccw_around() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.ccw_around(b).x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 949221)]
    fn bench_hex_cw_around() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.cw_around(b).x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 999275)]
    fn bench_hex_rotate_cw() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.rotate_cw(4).x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 999117)]
    fn bench_hex_rotate_ccw() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.rotate_ccw(4).x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 1306967)]
    fn bench_hex_rotate_cw_around() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.rotate_cw_around(b, 4).x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 578277)]
    fn bench_hex_reflect_x() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.reflect_x().x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 579159)]
    fn bench_hex_reflect_y() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.reflect_y().x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 2144646)]
    fn bench_hex_way_to() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += match a.way_to(b) {
                DirectionWay::Single(_) => 0,
                DirectionWay::Tie(_) => 1,
            }
                + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 2144646)]
    fn bench_hex_main_direction_to() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.main_direction_to(b).index().into() + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 2001195)]
    fn bench_hex_diagonal_way_to() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), 0 - n.into());
            acc += match a.diagonal_way_to(b) {
                DirectionWay::Single(_) => 0,
                DirectionWay::Tie(_) => 1,
            }
                + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 2001195)]
    fn bench_hex_main_diagonal_to() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), 0 - n.into());
            acc += a.main_diagonal_to(b).index().into() + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 1272506)]
    fn bench_hex_to_higher_res() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 0 - n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.to_higher_res(6).x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 615353)]
    fn bench_hex_range() {
        let ranged = HexTrait::new(3, -7).range(6);
        assert!(ranged.len() == 127);
    }

    #[test]
    #[available_gas(l2_gas: 721760)]
    fn bench_hex_xrange() {
        let ranged = HexTrait::new(3, -7).xrange(6);
        assert!(ranged.len() == 126);
    }

    #[test]
    #[available_gas(l2_gas: 153867)]
    fn bench_hex_rectiline_to() {
        let path = HexTrait::new(3, -7).rectiline_to(HexTrait::new(13, 3), true);
        assert!(path.len() == 21);
    }

    #[test]
    #[available_gas(l2_gas: 3479364)]
    fn bench_hex_to_lower_res() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 45 + n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.to_lower_res(6).x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 4434665)]
    fn bench_hex_to_local() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 45 + n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.to_local(6).x + b.y;
        }
        assert!(acc != 1000000);
    }

    #[test]
    #[available_gas(l2_gas: 4434665)]
    fn bench_hex_wrap_in_range() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(0 - n.into(), 45 + n.into());
            let b = HexTrait::new(n.into(), n.into());
            acc += a.wrap_in_range(6).x + b.y;
        }
        assert!(acc != 1000000);
    }
}
