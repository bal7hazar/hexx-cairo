//! The call sites of `hexx_glam` (LIB-06b, M3-T3): the five interop items, so that the tracked
//! class size follows them. The impls are imported by name: they are defined in `hexx_glam`,
//! not in the module of `Into`, `Hex` or `IVec2`, so `.into()` finds them only when imported.

/// The `glam` interop of `Hex`.
#[starknet::contract]
pub mod HexxGlam {
    use glam::ivec2::IVec2;
    use glam::ivec3::IVec3;
    use hexx::hex::{Hex, HexTrait};
    use hexx_glam::{HexGlamTrait, HexIntoIVec2, HexIntoIVec3, IVec2IntoHex};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn as_ivec2(self: @ContractState, x: i32, y: i32) -> IVec2 {
        HexTrait::new(x, y).as_ivec2()
    }

    #[external(v0)]
    fn as_ivec3(self: @ContractState, x: i32, y: i32) -> IVec3 {
        HexTrait::new(x, y).as_ivec3()
    }

    #[external(v0)]
    fn hex_into_ivec2(self: @ContractState, x: i32, y: i32) -> IVec2 {
        HexTrait::new(x, y).into()
    }

    #[external(v0)]
    fn hex_into_ivec3(self: @ContractState, x: i32, y: i32) -> IVec3 {
        HexTrait::new(x, y).into()
    }

    #[external(v0)]
    fn ivec2_into_hex(self: @ContractState, x: i32, y: i32) -> Hex {
        IVec2 { x, y }.into()
    }
}
