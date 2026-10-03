//! The call sites of the directions of L-M2 (`hexx::direction`), written by M2-T1 (LIB-06): one per
//! public item, so that the tracked class size follows them: the 36 compass constants of
//! `VertexDirection`, its methods, the new methods of `EdgeDirection`, the operators, and
//! `DirectionWay` (`map` with a closure included: it is the one item that makes the class hash of
//! this contract depend on the build path until the upstream compiler issue 10359 ships in a
//! Scarb, see the documentation of `DirectionWayTrait::map`).

/// The directions of milestone L-M2.
#[starknet::contract]
pub mod HexxDirections {
    use hexx::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
    use hexx::direction::impls::{
        EdgeDirectionNeg, EdgeDirectionOpsTrait, VertexDirectionNeg, VertexDirectionOpsTrait,
    };
    use hexx::direction::vertex_direction::{VertexDirection, VertexDirectionTrait};
    use hexx::direction::way::{DirectionWay, DirectionWayTrait};
    use hexx::hex::Hex;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn vertex_constants(self: @ContractState) -> Span<u8> {
        let mut indices = array![];
        indices.append(VertexDirectionTrait::X_NEG_Y_NEG_Z.index());
        indices.append(VertexDirectionTrait::X.index());
        indices.append(VertexDirectionTrait::FLAT_RIGHT.index());
        indices.append(VertexDirectionTrait::FLAT_EAST.index());
        indices.append(VertexDirectionTrait::POINTY_TOP_RIGHT.index());
        indices.append(VertexDirectionTrait::POINTY_NORTH_EAST.index());
        indices.append(VertexDirectionTrait::X_NEG_Y_Z.index());
        indices.append(VertexDirectionTrait::NEG_Y.index());
        indices.append(VertexDirectionTrait::FLAT_TOP_RIGHT.index());
        indices.append(VertexDirectionTrait::FLAT_NORTH_EAST.index());
        indices.append(VertexDirectionTrait::POINTY_TOP.index());
        indices.append(VertexDirectionTrait::POINTY_NORTH.index());
        indices.append(VertexDirectionTrait::NEG_X_NEG_Y.index());
        indices.append(VertexDirectionTrait::Z.index());
        indices.append(VertexDirectionTrait::FLAT_TOP_LEFT.index());
        indices.append(VertexDirectionTrait::FLAT_NORTH_WEST.index());
        indices.append(VertexDirectionTrait::POINTY_TOP_LEFT.index());
        indices.append(VertexDirectionTrait::POINTY_NORTH_WEST.index());
        indices.append(VertexDirectionTrait::NEG_X_Y_Z.index());
        indices.append(VertexDirectionTrait::NEG_X.index());
        indices.append(VertexDirectionTrait::FLAT_LEFT.index());
        indices.append(VertexDirectionTrait::FLAT_WEST.index());
        indices.append(VertexDirectionTrait::POINTY_BOTTOM_LEFT.index());
        indices.append(VertexDirectionTrait::POINTY_SOUTH_WEST.index());
        indices.append(VertexDirectionTrait::NEG_X_Y_NEG_Z.index());
        indices.append(VertexDirectionTrait::Y.index());
        indices.append(VertexDirectionTrait::FLAT_BOTTOM_LEFT.index());
        indices.append(VertexDirectionTrait::FLAT_SOUTH_WEST.index());
        indices.append(VertexDirectionTrait::POINTY_BOTTOM.index());
        indices.append(VertexDirectionTrait::POINTY_SOUTH.index());
        indices.append(VertexDirectionTrait::X_Y.index());
        indices.append(VertexDirectionTrait::NEG_Z.index());
        indices.append(VertexDirectionTrait::FLAT_BOTTOM_RIGHT.index());
        indices.append(VertexDirectionTrait::FLAT_SOUTH_EAST.index());
        indices.append(VertexDirectionTrait::POINTY_BOTTOM_RIGHT.index());
        indices.append(VertexDirectionTrait::POINTY_SOUTH_EAST.index());
        indices.span()
    }

    #[external(v0)]
    fn vertex_all_directions(self: @ContractState) -> Span<VertexDirection> {
        let all = VertexDirectionTrait::ALL_DIRECTIONS;
        all.span()
    }

    #[external(v0)]
    fn vertex_iter(self: @ContractState) -> Span<VertexDirection> {
        VertexDirectionTrait::iter()
    }

    #[external(v0)]
    fn vertex_index(self: @ContractState, direction: VertexDirection) -> u8 {
        direction.index()
    }

    #[external(v0)]
    fn vertex_into_hex(self: @ContractState, direction: VertexDirection) -> Hex {
        direction.into_hex()
    }

    #[external(v0)]
    fn vertex_into(self: @ContractState, direction: VertexDirection) -> Hex {
        direction.into()
    }

    #[external(v0)]
    fn vertex_const_neg(self: @ContractState, direction: VertexDirection) -> VertexDirection {
        direction.const_neg()
    }

    #[external(v0)]
    fn vertex_neg(self: @ContractState, direction: VertexDirection) -> VertexDirection {
        -direction
    }

    #[external(v0)]
    fn vertex_clockwise(self: @ContractState, direction: VertexDirection) -> VertexDirection {
        direction.clockwise()
    }

    #[external(v0)]
    fn vertex_counter_clockwise(
        self: @ContractState, direction: VertexDirection,
    ) -> VertexDirection {
        direction.counter_clockwise()
    }

    #[external(v0)]
    fn vertex_rotate_cw(
        self: @ContractState, direction: VertexDirection, offset: u8,
    ) -> VertexDirection {
        direction.rotate_cw(offset)
    }

    #[external(v0)]
    fn vertex_rotate_ccw(
        self: @ContractState, direction: VertexDirection, offset: u8,
    ) -> VertexDirection {
        direction.rotate_ccw(offset)
    }

    #[external(v0)]
    fn vertex_direction_ccw(self: @ContractState, direction: VertexDirection) -> EdgeDirection {
        direction.direction_ccw()
    }

    #[external(v0)]
    fn vertex_edge_ccw(self: @ContractState, direction: VertexDirection) -> EdgeDirection {
        direction.edge_ccw()
    }

    #[external(v0)]
    fn vertex_direction_cw(self: @ContractState, direction: VertexDirection) -> EdgeDirection {
        direction.direction_cw()
    }

    #[external(v0)]
    fn vertex_edge_cw(self: @ContractState, direction: VertexDirection) -> EdgeDirection {
        direction.edge_cw()
    }

    #[external(v0)]
    fn vertex_edge_directions(
        self: @ContractState, direction: VertexDirection,
    ) -> (EdgeDirection, EdgeDirection) {
        let [ccw, cw] = direction.edge_directions();
        (ccw, cw)
    }

    #[external(v0)]
    fn vertex_mul_scalar(self: @ContractState, direction: VertexDirection, rhs: i32) -> Hex {
        direction.mul_scalar(rhs)
    }

    #[external(v0)]
    fn vertex_debug(self: @ContractState, direction: VertexDirection) -> ByteArray {
        format!("{:?}", direction)
    }

    #[external(v0)]
    fn edge_diagonal_ccw(self: @ContractState, direction: EdgeDirection) -> VertexDirection {
        direction.diagonal_ccw()
    }

    #[external(v0)]
    fn edge_vertex_ccw(self: @ContractState, direction: EdgeDirection) -> VertexDirection {
        direction.vertex_ccw()
    }

    #[external(v0)]
    fn edge_diagonal_cw(self: @ContractState, direction: EdgeDirection) -> VertexDirection {
        direction.diagonal_cw()
    }

    #[external(v0)]
    fn edge_vertex_cw(self: @ContractState, direction: EdgeDirection) -> VertexDirection {
        direction.vertex_cw()
    }

    #[external(v0)]
    fn edge_vertex_directions(
        self: @ContractState, direction: EdgeDirection,
    ) -> (VertexDirection, VertexDirection) {
        let [ccw, cw] = direction.vertex_directions();
        (ccw, cw)
    }

    #[external(v0)]
    fn edge_neg(self: @ContractState, direction: EdgeDirection) -> EdgeDirection {
        -direction
    }

    #[external(v0)]
    fn edge_mul_scalar(self: @ContractState, direction: EdgeDirection, rhs: i32) -> Hex {
        direction.mul_scalar(rhs)
    }

    #[external(v0)]
    fn edge_debug(self: @ContractState, direction: EdgeDirection) -> ByteArray {
        format!("{:?}", direction)
    }

    /// `DirectionWay` of edge directions, as its parts: `tie` selects `Tie([a, b])`, else
    /// `Single(a)`.
    #[external(v0)]
    fn way_unwrap(
        self: @ContractState, tie: bool, a: EdgeDirection, b: EdgeDirection,
    ) -> EdgeDirection {
        let way: DirectionWay<EdgeDirection> = if tie {
            [a, b].into()
        } else {
            a.into()
        };
        way.unwrap()
    }

    #[external(v0)]
    fn way_contains(
        self: @ContractState, tie: bool, a: EdgeDirection, b: EdgeDirection, dir: EdgeDirection,
    ) -> bool {
        let way: DirectionWay<EdgeDirection> = if tie {
            [a, b].into()
        } else {
            a.into()
        };
        way.contains(@dir)
    }

    /// `map`, with a closure: the indices of the directions of the way.
    #[external(v0)]
    fn way_map(self: @ContractState, tie: bool, a: EdgeDirection, b: EdgeDirection) -> (u8, u8) {
        let way: DirectionWay<EdgeDirection> = if tie {
            [a, b].into()
        } else {
            a.into()
        };
        match way.map(|d: EdgeDirection| d.index()) {
            DirectionWay::Single(v) => (v, v),
            DirectionWay::Tie(pair) => {
                let [x, y] = pair;
                (x, y)
            },
        }
    }
}
