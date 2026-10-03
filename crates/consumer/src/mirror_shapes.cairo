//! The call sites of the shapes (`hexx::shapes`), written by M2-T6 (LIB-06): one per public item,
//! so that the tracked class size follows them: the six free functions, the `new` and `coords` of
//! each struct's trait, and the `Default` of each struct.

/// The shapes of milestone L-M2.
#[starknet::contract]
pub mod HexxShapes {
    use hexx::hex::Hex;
    use hexx::shapes::{
        FlatRectangle, FlatRectangleTrait, Hexagon, HexagonTrait, Parallelogram, ParallelogramTrait,
        PointyRectangle, PointyRectangleTrait, Rombus, RombusTrait, Triangle, TriangleTrait,
        flat_rectangle, hexagon, parallelogram, pointy_rectangle, rombus, triangle,
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn parallelogram_coords(self: @ContractState, min: Hex, max: Hex) -> Span<Hex> {
        parallelogram(min, max)
    }

    #[external(v0)]
    fn triangle_coords(self: @ContractState, size: u32) -> Span<Hex> {
        triangle(size)
    }

    #[external(v0)]
    fn hexagon_coords(self: @ContractState, center: Hex, radius: u32) -> Span<Hex> {
        hexagon(center, radius)
    }

    #[external(v0)]
    fn rombus_coords(self: @ContractState, point: Hex, rows: u32, columns: u32) -> Span<Hex> {
        rombus(point, rows, columns)
    }

    #[external(v0)]
    fn pointy_rectangle_coords(self: @ContractState, bounds: [i32; 4]) -> Span<Hex> {
        pointy_rectangle(bounds)
    }

    #[external(v0)]
    fn flat_rectangle_coords(self: @ContractState, bounds: [i32; 4]) -> Span<Hex> {
        flat_rectangle(bounds)
    }

    #[external(v0)]
    fn new_parallelogram(self: @ContractState, min: Hex, max: Hex) -> Parallelogram {
        ParallelogramTrait::new(min, max)
    }

    #[external(v0)]
    fn new_triangle(self: @ContractState, size: u32) -> Triangle {
        TriangleTrait::new(size)
    }

    #[external(v0)]
    fn new_hexagon(self: @ContractState, center: Hex, radius: u32) -> Hexagon {
        HexagonTrait::new(center, radius)
    }

    #[external(v0)]
    fn parallelogram_struct_coords(self: @ContractState, shape: Parallelogram) -> Span<Hex> {
        shape.coords()
    }

    #[external(v0)]
    fn triangle_struct_coords(self: @ContractState, shape: Triangle) -> Span<Hex> {
        shape.coords()
    }

    #[external(v0)]
    fn hexagon_struct_coords(self: @ContractState, shape: Hexagon) -> Span<Hex> {
        shape.coords()
    }

    #[external(v0)]
    fn rombus_struct_coords(self: @ContractState, shape: Rombus) -> Span<Hex> {
        shape.coords()
    }

    #[external(v0)]
    fn pointy_rectangle_struct_coords(self: @ContractState, shape: PointyRectangle) -> Span<Hex> {
        shape.coords()
    }

    #[external(v0)]
    fn flat_rectangle_struct_coords(self: @ContractState, shape: FlatRectangle) -> Span<Hex> {
        shape.coords()
    }

    #[external(v0)]
    fn default_parallelogram(self: @ContractState) -> Parallelogram {
        Default::default()
    }

    #[external(v0)]
    fn default_triangle(self: @ContractState) -> Triangle {
        Default::default()
    }

    #[external(v0)]
    fn default_hexagon(self: @ContractState) -> Hexagon {
        Default::default()
    }

    #[external(v0)]
    fn default_rombus(self: @ContractState) -> Rombus {
        Default::default()
    }

    #[external(v0)]
    fn default_pointy_rectangle(self: @ContractState) -> PointyRectangle {
        Default::default()
    }

    #[external(v0)]
    fn default_flat_rectangle(self: @ContractState) -> FlatRectangle {
        Default::default()
    }
}
