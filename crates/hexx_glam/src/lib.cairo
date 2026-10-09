//! `hexx_glam`: the `glam` interop of `hexx::Hex`, the companion package of `hexx` (plan §2.1,
//! §4.4). It ports the five items of `hexx` 0.25.0 that convert a `Hex` to and from the `IVec2`
//! and `IVec3` of the Cairo `glam` (scarbs.xyz): `Hex::as_ivec2`, `Hex::as_ivec3`,
//! `From<Hex> for IVec2`, `From<Hex> for IVec3` and `From<IVec2> for Hex`. `hexx` has no
//! `From<IVec3> for Hex`, and none is added.
//!
//! `as_ivec3` is `IVec3 { x, y, z: self.z() }` (`src/hex/mod.rs:390-396`), and `z` is
//! golden-tested in `hexx` since L-M1, so no vector of `hexx` is needed here: the tests below
//! check the definition over `[-40, 40]²` and the `i32` extremes.
//!
//! Ported to Cairo from bevy hexx 0.25.0 (Apache-2.0); the code is a rewrite, not a copy.
//!
//! #### Import rule
//!
//! The three `Into` impls are defined in this package: not in the module of `Into`, nor in those
//! of `Hex` or `IVec2`. A consumer brings them into scope for `.into()` to find them
//! (`use hexx_glam::{HexIntoIVec2, HexIntoIVec3, IVec2IntoHex};`, or `use hexx_glam::*;`), and
//! `HexGlamTrait` for the methods. The call sites in `crates/consumer/src/mirror_glam.cairo`
//! import the impls explicitly.

use glam::ivec2::IVec2;
use glam::ivec3::IVec3;
use hexx::hex::{Hex, HexTrait};

/// The `glam` conversion methods of `Hex`.
pub trait HexGlamTrait {
    /// Converts to an `IVec2`: `IVec2 { x, y }`.
    ///
    /// Mirrors `Hex::as_ivec2` (`src/hex/mod.rs:365`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn as_ivec2(self: Hex) -> IVec2;

    /// Converts to an `IVec3`: `IVec3 { x, y, z }`, `z` being `HexTrait::z`.
    ///
    /// Mirrors `Hex::as_ivec3` (`src/hex/mod.rs:390`).
    ///
    /// #### Panics
    ///
    /// The panics of `HexTrait::z`: when `-x - y` leaves `i32` (for example `x = i32::MIN`).
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn as_ivec3(self: Hex) -> IVec3;
}

impl HexGlamImpl of HexGlamTrait {
    #[inline]
    fn as_ivec2(self: Hex) -> IVec2 {
        IVec2 { x: self.x, y: self.y }
    }

    #[inline]
    fn as_ivec3(self: Hex) -> IVec3 {
        IVec3 { x: self.x, y: self.y, z: self.z() }
    }
}

/// Converts a `Hex` into an `IVec2`: `IVec2 { x, y }`.
///
/// Mirrors `impl From<Hex> for IVec2` (`src/hex/convert.rs:32`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// Cairo's conversion trait is `Into`, `Into<Hex, IVec2>` is the form of Rust's `From`. The impl
/// is not in the module of `Into`, `Hex` or `IVec2`: bring it into scope (`use
/// hexx_glam::HexIntoIVec2;`) for `.into()` to find it.
pub impl HexIntoIVec2 of Into<Hex, IVec2> {
    #[inline]
    fn into(self: Hex) -> IVec2 {
        self.as_ivec2()
    }
}

/// Converts a `Hex` into an `IVec3`: `IVec3 { x, y, z }`, `z` being `HexTrait::z`.
///
/// Mirrors `impl From<Hex> for IVec3` (`src/hex/convert.rs:42`).
///
/// #### Panics
///
/// The panics of `HexTrait::z`: when `-x - y` leaves `i32`.
///
/// #### Deviations
///
/// Cairo's conversion trait is `Into`, `Into<Hex, IVec3>` is the form of Rust's `From`; bring the
/// impl into scope (`use hexx_glam::HexIntoIVec3;`), as for `HexIntoIVec2`.
pub impl HexIntoIVec3 of Into<Hex, IVec3> {
    #[inline]
    fn into(self: Hex) -> IVec3 {
        self.as_ivec3()
    }
}

/// Converts an `IVec2` into a `Hex`: `Hex { x, y }`.
///
/// Mirrors `impl From<IVec2> for Hex` (`src/hex/convert.rs:52`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// Cairo's conversion trait is `Into`, `Into<IVec2, Hex>` is the form of Rust's `From`; bring the
/// impl into scope (`use hexx_glam::IVec2IntoHex;`), as for `HexIntoIVec2`.
pub impl IVec2IntoHex of Into<IVec2, Hex> {
    #[inline]
    fn into(self: IVec2) -> Hex {
        HexTrait::new(self.x, self.y)
    }
}

#[cfg(test)]
mod tests {
    use glam::ivec2::IVec2;
    use glam::ivec3::IVec3;
    use hexx::hex::{Hex, HexTrait};
    use super::{HexGlamTrait, HexIntoIVec2, HexIntoIVec3, IVec2IntoHex};

    const MAX: i32 = 0x7fffffff;
    const MIN: i32 = -0x80000000;

    /// The oracle is the definition, over `[-40, 40]²`.
    #[test]
    #[available_gas(l2_gas: 66573022)]
    fn test_conversions_oracle() {
        let mut x: i32 = -40;
        while x <= 40 {
            let mut y: i32 = -40;
            while y <= 40 {
                let hex = HexTrait::new(x, y);
                let v2 = IVec2 { x, y };
                let v3 = IVec3 { x, y, z: -x - y };
                assert!(hex.as_ivec2() == v2);
                let into2: IVec2 = hex.into();
                assert!(into2 == v2);
                let back: Hex = v2.into();
                assert!(back == hex);
                assert!(hex.as_ivec3() == v3);
                let into3: IVec3 = hex.into();
                assert!(into3 == v3);
                y += 1;
            }
            x += 1;
        }
    }

    /// The `i32` extremes of `IVec2`, both ways.
    #[test]
    #[available_gas(l2_gas: 30870)]
    fn test_ivec2_extremes() {
        let corners = array![(MIN, MIN), (MIN, MAX), (MAX, MIN), (MAX, MAX), (MIN, 0), (0, MAX)];
        for (x, y) in corners {
            let hex = HexTrait::new(x, y);
            let v2 = IVec2 { x, y };
            assert!(hex.as_ivec2() == v2);
            let into2: IVec2 = hex.into();
            assert!(into2 == v2);
            let back: Hex = v2.into();
            assert!(back == hex);
        }
    }

    /// `as_ivec3` where `z` is representable at the extremes.
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_as_ivec3_extremes_in_range() {
        let hex = HexTrait::new(MAX, 0);
        assert!(hex.as_ivec3() == IVec3 { x: MAX, y: 0, z: -MAX });
        let hex = HexTrait::new(0, MAX);
        assert!(hex.as_ivec3() == IVec3 { x: 0, y: MAX, z: -MAX });
        let hex = HexTrait::new(MAX, MIN);
        assert!(hex.as_ivec3() == IVec3 { x: MAX, y: MIN, z: 1 });
    }

    /// `z` leaves `i32` at `x = i32::MIN`: `as_ivec3` panics where `HexTrait::z` does.
    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_as_ivec3_panics_at_min_x() {
        let _ = HexTrait::new(MIN, 0).as_ivec3();
    }

    /// `z` leaves `i32` at `x = 0, y = i32::MIN`.
    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_into_ivec3_panics_at_min_y() {
        let _: IVec3 = HexTrait::new(0, MIN).into();
    }
}
