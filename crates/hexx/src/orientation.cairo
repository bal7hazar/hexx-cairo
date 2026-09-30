//! `HexOrientation`, the mirror of `hexx::HexOrientation` (`src/orientation.rs`).
//!
//! Only the enum is ported: it parametrises the integer offset conversions
//! (`src/conversions.rs:65-84`). `HexOrientationData`, `forward`, `inverse`, `orientation_data`
//! and `Deref` are `f32` matrices and are excluded (plan §2.3).

/// The orientation of the hexagons of a grid: `Pointy` (pointy-topped) or `Flat` (flat-topped).
///
/// Mirrors `hexx::HexOrientation` (`src/orientation.rs:124`), its variants `Pointy` (`:127`) and
/// `Flat` (`:130`, the default) and its `Default` (`#[default]`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The discriminants (`Pointy = 0`, `Flat = 1`, `#[repr(u8)]`) are not exposed: a Cairo enum has
/// its own, and `Serde` writes the variant index, which is the same.
#[derive(Copy, Drop, Serde, PartialEq, Debug, Default, Hash)]
pub enum HexOrientation {
    Pointy,
    #[default]
    Flat,
}

/// The other orientation: `!Pointy` is `Flat` and `!Flat` is `Pointy`.
///
/// Mirrors `impl Not for HexOrientation` (`src/orientation.rs:152`).
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// None.
pub impl HexOrientationNot of Not<HexOrientation> {
    fn not(a: HexOrientation) -> HexOrientation {
        match a {
            HexOrientation::Pointy => HexOrientation::Flat,
            HexOrientation::Flat => HexOrientation::Pointy,
        }
    }
}
