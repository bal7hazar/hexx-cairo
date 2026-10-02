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

use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};

// The modules of milestone L-M2 (plan §2.2): each is filled by the task that owns it (M2-T3:
// `impls`, `swizzle`, `euclidean`, `convert`; M2-T4: `rings`; M2-T5: `iter`; M2-T7: `grid`).
pub mod convert;
pub mod euclidean;
pub mod grid;
pub mod impls;
pub mod iter;
pub mod rings;
pub mod swizzle;

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
/// The path is `hexx::hex::hex`, not `hexx::hex` as in hexx 0.25.0: the root cannot re-export it,
/// because Cairo refuses `pub use hex::hex` beside `pub mod hex` (E2118).
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
/// Derives `Serde`, `Debug`, `Default`, `Hash` as a matter of course (plan §2.3); `Debug` prints
/// the fields, not `x`, `y` and `z` as `hexx` does (L-M2).
#[derive(Copy, Drop, Serde, PartialEq, Debug, Default, Hash)]
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
    /// Returns a `u32`, where `hexx` returns a `usize` (Cairo has no `usize`); `hexx` on a 64-bit
    /// host never overflows there, this port panics from `range = 715_827_883`.
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
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
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
}
