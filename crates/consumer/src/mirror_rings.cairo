//! The call sites of the rings, wedges and spirals (`hexx::hex::rings`), written by M2-T4 (LIB-06):
//! one per public item, so that the tracked class size follows them.

/// The rings, ring edges, wedges and spirals of milestone L-M2.
#[starknet::contract]
pub mod HexxRings {
    use hexx::direction::edge_direction::EdgeDirection;
    use hexx::direction::vertex_direction::VertexDirection;
    use hexx::hex::Hex;
    use hexx::hex::rings::HexRingsTrait;

    #[storage]
    struct Storage {}

    /// `ring`, `custom_ring`, `rings`, `custom_rings`.
    #[external(v0)]
    fn rings(
        self: @ContractState,
        center: Hex,
        range: u32,
        ranges: Span<u32>,
        dir: EdgeDirection,
        clockwise: bool,
    ) -> Span<Span<Hex>> {
        let mut out = array![center.ring(range), center.custom_ring(range, dir, clockwise)];
        out.append_span(center.rings(ranges));
        out.append_span(center.custom_rings(ranges, dir, clockwise));
        out.span()
    }

    /// `ring_edge`, `custom_ring_edge`, `ring_edges`, `custom_ring_edges`.
    #[external(v0)]
    fn ring_edges(
        self: @ContractState,
        center: Hex,
        radius: u32,
        ranges: Span<u32>,
        vertex: VertexDirection,
        clockwise: bool,
    ) -> Span<Span<Hex>> {
        let mut out = array![
            center.ring_edge(radius, vertex), center.custom_ring_edge(radius, vertex, clockwise),
        ];
        out.append_span(center.ring_edges(ranges, vertex));
        out.append_span(center.custom_ring_edges(ranges, vertex, clockwise));
        out.span()
    }

    /// `wedge`, `custom_wedge`, `full_wedge`, `custom_full_wedge`, `wedge_to`, `custom_wedge_to`.
    #[external(v0)]
    fn wedges(
        self: @ContractState,
        center: Hex,
        to: Hex,
        radius: u32,
        ranges: Span<u32>,
        vertex: VertexDirection,
        clockwise: bool,
    ) -> Span<Span<Hex>> {
        array![
            center.wedge(ranges, vertex), center.custom_wedge(ranges, vertex, clockwise),
            center.full_wedge(radius, vertex), center.custom_full_wedge(radius, vertex, clockwise),
            center.wedge_to(to), center.custom_wedge_to(to, clockwise),
        ]
            .span()
    }

    /// `corner_wedge`, `corner_wedge_to`.
    #[external(v0)]
    fn corner_wedges(
        self: @ContractState, center: Hex, to: Hex, ranges: Span<u32>, dir: EdgeDirection,
    ) -> Span<Span<Hex>> {
        array![center.corner_wedge(ranges, dir), center.corner_wedge_to(to)].span()
    }

    /// The cached forms.
    #[external(v0)]
    fn cached(
        self: @ContractState,
        center: Hex,
        range: u32,
        dir: EdgeDirection,
        vertex: VertexDirection,
        clockwise: bool,
    ) -> Span<Span<Span<Hex>>> {
        array![
            center.cached_rings(range), center.cached_custom_rings(range, dir, clockwise),
            center.cached_ring_edges(range, vertex),
            center.cached_custom_ring_edges(range, vertex, clockwise),
        ]
            .span()
    }

    /// `spiral_range`, `custom_spiral_range`, `circular_range_squared`.
    #[external(v0)]
    fn spirals(
        self: @ContractState,
        center: Hex,
        ranges: Span<u32>,
        dir: EdgeDirection,
        clockwise: bool,
        range_squared: i32,
    ) -> Span<Span<Hex>> {
        array![
            center.spiral_range(ranges), center.custom_spiral_range(ranges, dir, clockwise),
            center.circular_range_squared(range_squared),
        ]
            .span()
    }
}
