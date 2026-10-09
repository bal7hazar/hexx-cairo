//! The call sites of the algorithms (`hexx::algorithms`), written by M3-T1 (LIB-06b): one per
//! public item, so that the tracked class size follows them: `field_of_movement` and `a_star`.

/// The algorithms of milestone L-M3.
#[starknet::contract]
pub mod HexxAlgorithms {
    use hexx::HexMap;
    use hexx::algorithms::a_star;
    use hexx::algorithms::field_of_movement::field_of_movement;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn field_of_movement_bitmap(
        self: @ContractState, map: HexMap, from: u8, budget: u8, costs: Span<felt252>,
    ) -> felt252 {
        field_of_movement(map, from, budget, costs)
    }

    #[external(v0)]
    fn a_star_path(
        self: @ContractState, map: HexMap, from: u8, to: u8, costs: Span<felt252>,
    ) -> Option<Span<u8>> {
        a_star(map, from, to, costs)
    }
}
