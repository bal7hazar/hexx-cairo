//! `Hex`: an axial hexagonal coordinate on `i32`, the mirror of `hexx::Hex` (`src/hex/mod.rs`).
//!
//! Every operation whose result leaves `i32` **panics** with Cairo's native message, where `hexx`
//! panics in a debug build and wraps in a release build (plan §3.1). The cubic coordinate is
//! `z = -x - y`, computed as `hexx` computes it (`src/hex/mod.rs:274-276`), so it panics exactly
//! where a debug build of `hexx` does.
//!
//! The compass of `hexx` (y down) is kept verbatim by `EdgeDirection`; `Hex` itself has no
//! orientation. This file holds the items of milestone L-M1 (plan §8); the rest of
//! `src/hex/mod.rs`
//! lands with L-M2 and `line_to` with M1-T6.

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

/// The items of `impl Hex` of milestone L-M1.
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
}

pub impl HexImpl of HexTrait {
    const ZERO: Hex = Hex { x: 0, y: 0 };
    const NEIGHBORS_COORDS: [Hex; 6] = [
        Hex { x: 1, y: 0 }, Hex { x: 0, y: 1 }, Hex { x: -1, y: 1 }, Hex { x: -1, y: 0 },
        Hex { x: 0, y: -1 }, Hex { x: 1, y: -1 },
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
