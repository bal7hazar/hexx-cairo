//! The call sites of `GridEdge` and `GridVertex` (`hexx::hex::grid`), written by M2-T7 (LIB-06):
//! one per public item, so that the tracked class size follows them: the methods, `Neg`, the
//! `Into` of a direction, `Hex::all_edges` and `Hex::all_vertices`.

/// The grid edges and vertices of milestone L-M2.
#[starknet::contract]
pub mod HexxGrid {
    use hexx::direction::edge_direction::EdgeDirection;
    use hexx::direction::vertex_direction::VertexDirection;
    use hexx::hex::Hex;
    use hexx::hex::grid::edge::{GridEdge, GridEdgeNeg, GridEdgeTrait, HexEdgesTrait};
    use hexx::hex::grid::vertex::{GridVertex, GridVertexNeg, GridVertexTrait, HexVerticesTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn edge_equivalent(self: @ContractState, a: GridEdge, b: GridEdge) -> bool {
        a.equivalent(b)
    }

    #[external(v0)]
    fn edge_destination(self: @ContractState, edge: GridEdge) -> Hex {
        edge.destination()
    }

    #[external(v0)]
    fn edge_vertices(self: @ContractState, edge: GridEdge) -> Span<GridVertex> {
        let [ccw, cw] = edge.vertices();
        array![ccw, cw].span()
    }

    #[external(v0)]
    fn edge_flipped(self: @ContractState, edge: GridEdge) -> GridEdge {
        edge.flipped()
    }

    #[external(v0)]
    fn edge_const_neg(self: @ContractState, edge: GridEdge) -> GridEdge {
        edge.const_neg()
    }

    #[external(v0)]
    fn edge_neg(self: @ContractState, edge: GridEdge) -> GridEdge {
        -edge
    }

    #[external(v0)]
    fn edge_clockwise(self: @ContractState, edge: GridEdge) -> GridEdge {
        edge.clockwise()
    }

    #[external(v0)]
    fn edge_counter_clockwise(self: @ContractState, edge: GridEdge) -> GridEdge {
        edge.counter_clockwise()
    }

    #[external(v0)]
    fn edge_rotate_cw(self: @ContractState, edge: GridEdge, offset: u8) -> GridEdge {
        edge.rotate_cw(offset)
    }

    #[external(v0)]
    fn edge_rotate_ccw(self: @ContractState, edge: GridEdge, offset: u8) -> GridEdge {
        edge.rotate_ccw(offset)
    }

    #[external(v0)]
    fn edge_from_direction(self: @ContractState, direction: EdgeDirection) -> GridEdge {
        direction.into()
    }

    #[external(v0)]
    fn all_edges(self: @ContractState, hex: Hex) -> Span<GridEdge> {
        let [e0, e1, e2, e3, e4, e5] = hex.all_edges();
        array![e0, e1, e2, e3, e4, e5].span()
    }

    #[external(v0)]
    fn vertex_equivalent(self: @ContractState, a: GridVertex, b: GridVertex) -> bool {
        a.equivalent(b)
    }

    #[external(v0)]
    fn vertex_coordinates(self: @ContractState, vertex: GridVertex) -> Span<Hex> {
        let [c0, c1, c2] = vertex.coordinates();
        array![c0, c1, c2].span()
    }

    #[external(v0)]
    fn vertex_destinations(self: @ContractState, vertex: GridVertex) -> Span<Hex> {
        let [d0, d1] = vertex.destinations();
        array![d0, d1].span()
    }

    #[external(v0)]
    fn vertex_side_edges(self: @ContractState, vertex: GridVertex) -> Span<GridEdge> {
        let [ccw, cw] = vertex.side_edges();
        array![ccw, cw].span()
    }

    #[external(v0)]
    fn vertex_const_neg(self: @ContractState, vertex: GridVertex) -> GridVertex {
        vertex.const_neg()
    }

    #[external(v0)]
    fn vertex_neg(self: @ContractState, vertex: GridVertex) -> GridVertex {
        -vertex
    }

    #[external(v0)]
    fn vertex_clockwise(self: @ContractState, vertex: GridVertex) -> GridVertex {
        vertex.clockwise()
    }

    #[external(v0)]
    fn vertex_counter_clockwise(self: @ContractState, vertex: GridVertex) -> GridVertex {
        vertex.counter_clockwise()
    }

    #[external(v0)]
    fn vertex_rotate_cw(self: @ContractState, vertex: GridVertex, offset: u8) -> GridVertex {
        vertex.rotate_cw(offset)
    }

    #[external(v0)]
    fn vertex_rotate_ccw(self: @ContractState, vertex: GridVertex, offset: u8) -> GridVertex {
        vertex.rotate_ccw(offset)
    }

    #[external(v0)]
    fn vertex_from_direction(self: @ContractState, direction: VertexDirection) -> GridVertex {
        direction.into()
    }

    #[external(v0)]
    fn all_vertices(self: @ContractState, hex: Hex) -> Span<GridVertex> {
        let [v0, v1, v2, v3, v4, v5] = hex.all_vertices();
        array![v0, v1, v2, v3, v4, v5].span()
    }
}
