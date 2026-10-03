//! `hex/swizzle`: the swizzles of `Hex` (`src/hex/swizzle.rs`): a new `Hex` from two of the
//! cubic components `x`, `y`, `z` of `self`.

use crate::hex::{Hex, HexTrait};

/// The swizzles of `Hex`.
pub trait HexSwizzleTrait {
    /// The coordinate `(x, x)` of the cubic components of `self` (alias `qq`).
    ///
    /// Mirrors `Hex::xx` (`src/hex/swizzle.rs:17`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn xx(self: Hex) -> Hex;

    /// The coordinate `(y, y)` of the cubic components of `self` (alias `rr`).
    ///
    /// Mirrors `Hex::yy` (`src/hex/swizzle.rs:34`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn yy(self: Hex) -> Hex;

    /// The coordinate `(z, z)` of the cubic components of `self` (alias `ss`).
    ///
    /// Mirrors `Hex::zz` (`src/hex/swizzle.rs:51`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32` (as `HexTrait::z`).
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn zz(self: Hex) -> Hex;

    /// The coordinate `(y, x)` of the cubic components of `self` (alias `rq`).
    ///
    /// Mirrors `Hex::yx` (`src/hex/swizzle.rs:68`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn yx(self: Hex) -> Hex;

    /// The coordinate `(y, z)` of the cubic components of `self` (alias `rs`).
    ///
    /// Mirrors `Hex::yz` (`src/hex/swizzle.rs:88`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32` (as `HexTrait::z`).
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn yz(self: Hex) -> Hex;

    /// The coordinate `(x, z)` of the cubic components of `self` (alias `qs`).
    ///
    /// Mirrors `Hex::xz` (`src/hex/swizzle.rs:108`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32` (as `HexTrait::z`).
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn xz(self: Hex) -> Hex;

    /// The coordinate `(z, x)` of the cubic components of `self` (alias `sq`).
    ///
    /// Mirrors `Hex::zx` (`src/hex/swizzle.rs:128`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32` (as `HexTrait::z`).
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn zx(self: Hex) -> Hex;

    /// The coordinate `(z, y)` of the cubic components of `self` (alias `sr`).
    ///
    /// Mirrors `Hex::zy` (`src/hex/swizzle.rs:148`).
    ///
    /// #### Panics
    ///
    /// When `z` leaves `i32` (as `HexTrait::z`).
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn zy(self: Hex) -> Hex;
}

pub impl HexSwizzleImpl of HexSwizzleTrait {
    #[inline]
    fn xx(self: Hex) -> Hex {
        HexTrait::splat(self.x)
    }

    #[inline]
    fn yy(self: Hex) -> Hex {
        HexTrait::splat(self.y)
    }

    #[inline]
    fn zz(self: Hex) -> Hex {
        HexTrait::splat(self.z())
    }

    #[inline]
    fn yx(self: Hex) -> Hex {
        Hex { x: self.y, y: self.x }
    }

    #[inline]
    fn yz(self: Hex) -> Hex {
        Hex { x: self.y, y: self.z() }
    }

    #[inline]
    fn xz(self: Hex) -> Hex {
        Hex { x: self.x, y: self.z() }
    }

    #[inline]
    fn zx(self: Hex) -> Hex {
        Hex { x: self.z(), y: self.x }
    }

    #[inline]
    fn zy(self: Hex) -> Hex {
        Hex { x: self.z(), y: self.y }
    }
}
