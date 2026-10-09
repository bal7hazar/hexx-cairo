//! The call sites of the field of view (`hexx::algorithms::{range_fov, directional_fov}`), written
//! by M3-T2 (LIB-06b): one per public item, so that the tracked class size follows them.

/// The field of view of milestone L-M3.
#[starknet::contract]
pub mod HexxFov {
    use hexx::algorithms::{directional_fov, range_fov};
    use hexx::{EdgeDirection, HexMap};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn range_fov_bitmap(self: @ContractState, map: HexMap, from: u8, range: u8) -> felt252 {
        range_fov(map, from, range)
    }

    #[external(v0)]
    fn directional_fov_bitmap(
        self: @ContractState, map: HexMap, from: u8, range: u8, direction: EdgeDirection,
    ) -> felt252 {
        directional_fov(map, from, range, direction)
    }
}
