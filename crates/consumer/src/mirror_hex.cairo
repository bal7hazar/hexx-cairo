//! The call sites of the rest of `Hex` (`hexx::hex`), written by M2-T2 (LIB-06): one per public
//! item, so that the tracked class size follows them: the diagonals, the ways, the rotations and
//! reflections, the rectilinear path, the ranges and the resolutions, and `Debug`.

/// The rest of `HexTrait` of milestone L-M2.
#[starknet::contract]
pub mod HexxHex {
    use hexx::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
    use hexx::direction::vertex_direction::{VertexDirection, VertexDirectionTrait};
    use hexx::direction::way::{DirectionWay, DirectionWayTrait};
    use hexx::hex::{Hex, HexTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn diagonal_neighbor_coord(self: @ContractState, direction: VertexDirection) -> Hex {
        HexTrait::diagonal_neighbor_coord(direction)
    }

    #[external(v0)]
    fn add_diag_dir(self: @ContractState, hex: Hex, direction: VertexDirection) -> Hex {
        hex.add_diag_dir(direction)
    }

    #[external(v0)]
    fn diagonal_neighbor(self: @ContractState, hex: Hex, direction: VertexDirection) -> Hex {
        hex.diagonal_neighbor(direction)
    }

    #[external(v0)]
    fn all_diagonals(self: @ContractState, hex: Hex) -> Span<Hex> {
        let all = hex.all_diagonals();
        all.span()
    }

    #[external(v0)]
    fn neighbor_direction(self: @ContractState, hex: Hex, other: Hex) -> Option<EdgeDirection> {
        hex.neighbor_direction(other)
    }

    #[external(v0)]
    fn main_diagonal_to(self: @ContractState, hex: Hex, rhs: Hex) -> VertexDirection {
        hex.main_diagonal_to(rhs)
    }

    /// `(tie, first, second)` of the way, as indices.
    #[external(v0)]
    fn diagonal_way_to(self: @ContractState, hex: Hex, rhs: Hex) -> (bool, u8, u8) {
        match hex.diagonal_way_to(rhs) {
            DirectionWay::Single(d) => (false, d.index(), d.index()),
            DirectionWay::Tie(pair) => {
                let [a, b] = pair;
                (true, a.index(), b.index())
            },
        }
    }

    #[external(v0)]
    fn main_direction_to(self: @ContractState, hex: Hex, rhs: Hex) -> EdgeDirection {
        hex.main_direction_to(rhs)
    }

    /// `(tie, first, second)` of the way, as indices.
    #[external(v0)]
    fn way_to(self: @ContractState, hex: Hex, rhs: Hex) -> (bool, u8, u8) {
        match hex.way_to(rhs) {
            DirectionWay::Single(d) => (false, d.index(), d.index()),
            DirectionWay::Tie(pair) => {
                let [a, b] = pair;
                (true, a.index(), b.index())
            },
        }
    }

    #[external(v0)]
    fn way_unwrap(self: @ContractState, hex: Hex, rhs: Hex) -> EdgeDirection {
        hex.way_to(rhs).unwrap()
    }

    #[external(v0)]
    fn counter_clockwise(self: @ContractState, hex: Hex) -> Hex {
        hex.counter_clockwise()
    }

    #[external(v0)]
    fn ccw_around(self: @ContractState, hex: Hex, center: Hex) -> Hex {
        hex.ccw_around(center)
    }

    #[external(v0)]
    fn rotate_ccw(self: @ContractState, hex: Hex, m: u32) -> Hex {
        hex.rotate_ccw(m)
    }

    #[external(v0)]
    fn rotate_ccw_around(self: @ContractState, hex: Hex, center: Hex, m: u32) -> Hex {
        hex.rotate_ccw_around(center, m)
    }

    #[external(v0)]
    fn clockwise(self: @ContractState, hex: Hex) -> Hex {
        hex.clockwise()
    }

    #[external(v0)]
    fn cw_around(self: @ContractState, hex: Hex, center: Hex) -> Hex {
        hex.cw_around(center)
    }

    #[external(v0)]
    fn rotate_cw(self: @ContractState, hex: Hex, m: u32) -> Hex {
        hex.rotate_cw(m)
    }

    #[external(v0)]
    fn rotate_cw_around(self: @ContractState, hex: Hex, center: Hex, m: u32) -> Hex {
        hex.rotate_cw_around(center, m)
    }

    #[external(v0)]
    fn reflect_x(self: @ContractState, hex: Hex) -> Hex {
        hex.reflect_x()
    }

    #[external(v0)]
    fn reflect_y(self: @ContractState, hex: Hex) -> Hex {
        hex.reflect_y()
    }

    #[external(v0)]
    fn reflect_z(self: @ContractState, hex: Hex) -> Hex {
        hex.reflect_z()
    }

    #[external(v0)]
    fn rectiline_to(self: @ContractState, hex: Hex, other: Hex, clockwise: bool) -> Span<Hex> {
        hex.rectiline_to(other, clockwise)
    }

    #[external(v0)]
    fn range(self: @ContractState, hex: Hex, range: u32) -> Span<Hex> {
        hex.range(range)
    }

    #[external(v0)]
    fn xrange(self: @ContractState, hex: Hex, range: u32) -> Span<Hex> {
        hex.xrange(range)
    }

    #[external(v0)]
    fn to_lower_res(self: @ContractState, hex: Hex, radius: u32) -> Hex {
        hex.to_lower_res(radius)
    }

    #[external(v0)]
    fn to_higher_res(self: @ContractState, hex: Hex, radius: u32) -> Hex {
        hex.to_higher_res(radius)
    }

    #[external(v0)]
    fn to_local(self: @ContractState, hex: Hex, radius: u32) -> Hex {
        hex.to_local(radius)
    }

    #[external(v0)]
    fn wrap_in_range(self: @ContractState, hex: Hex, range: u32) -> Hex {
        hex.wrap_in_range(range)
    }

    /// `Debug` of `Hex`: the string `hexx` prints.
    #[external(v0)]
    fn debug(self: @ContractState, hex: Hex) -> ByteArray {
        format!("{:?}", hex)
    }
}
