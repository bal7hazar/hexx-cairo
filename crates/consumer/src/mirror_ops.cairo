//! The call sites of the operators, swizzles and conversions of `Hex` (`hexx::hex::{impls,
//! swizzle, euclidean, convert}`, `hexx::conversions`), written by M2-T3 (LIB-06): one per public
//! item, so that the tracked class size follows them.

/// The operators, swizzles and conversions of milestone L-M2.
#[starknet::contract]
pub mod HexxOps {
    use hexx::conversions::{DoubledHexMode, HexConversionsTrait};
    use hexx::direction::edge_direction::EdgeDirection;
    use hexx::direction::vertex_direction::VertexDirection;
    use hexx::hex::Hex;
    use hexx::hex::convert::{HexConvertTrait, HexFromArray, HexFromTuple};
    use hexx::hex::euclidean::HexEuclideanTrait;
    use hexx::hex::impls::{
        HexAdd, HexAddAssign, HexDiv, HexDivAssign, HexMul, HexMulAssign, HexNeg, HexOpsTrait,
        HexRem, HexRemAssign, HexSub, HexSubAssign,
    };
    use hexx::hex::swizzle::HexSwizzleTrait;

    #[storage]
    struct Storage {}

    /// `Add`, `Sub`, `Mul`, `Div`, `Rem`, `Neg` and the assignment operators.
    #[external(v0)]
    fn operators(self: @ContractState, a: Hex, b: Hex) -> Span<Hex> {
        let mut c = a;
        c += b;
        let mut d = a;
        d -= b;
        let mut e = a;
        e *= b;
        let mut f = a;
        f /= b;
        let mut g = a;
        g %= b;
        array![a + b, a - b, a * b, a / b, a % b, -a, c, d, e, f, g].span()
    }

    #[external(v0)]
    fn scalars(self: @ContractState, a: Hex, k: i32) -> Span<Hex> {
        array![a.add_scalar(k), a.sub_scalar(k), a.div_scalar(k), a.rem_scalar(k)].span()
    }

    #[external(v0)]
    fn directions(
        self: @ContractState, a: Hex, edge: EdgeDirection, vertex: VertexDirection,
    ) -> Span<Hex> {
        array![
            a.add_direction(edge), a.sub_direction(edge), a.add_diagonal(vertex),
            a.sub_diagonal(vertex),
        ]
            .span()
    }

    #[external(v0)]
    fn swizzles(self: @ContractState, a: Hex) -> Span<Hex> {
        array![a.xx(), a.yy(), a.zz(), a.yx(), a.yz(), a.xz(), a.zx(), a.zy()].span()
    }

    #[external(v0)]
    fn euclidean(self: @ContractState, a: Hex, b: Hex) -> (i32, i32) {
        (a.squared_euclidean_length(), a.squared_euclidean_distance_to(b))
    }

    #[external(v0)]
    fn convert(self: @ContractState, a: Hex, v: u64, x: i32, y: i32) -> (u64, Hex, Hex, Hex) {
        let t: Hex = (x, y).into();
        let r: Hex = [x, y].into();
        (a.as_u64(), HexConvertTrait::from_u64(v), t, r)
    }

    #[external(v0)]
    fn doubled(
        self: @ContractState, a: Hex, doubled: [i32; 2], mode: DoubledHexMode,
    ) -> ([i32; 2], Hex) {
        (
            a.to_doubled_coordinates(mode),
            HexConversionsTrait::from_doubled_coordinates(doubled, mode),
        )
    }

    #[external(v0)]
    fn hexmod(self: @ContractState, a: Hex, coord: u32, range: u32) -> (u32, Hex) {
        (a.to_hexmod_coordinates(range), HexConversionsTrait::from_hexmod_coordinates(coord, range))
    }

    #[external(v0)]
    fn doubled_default(self: @ContractState) -> DoubledHexMode {
        Default::default()
    }
}
