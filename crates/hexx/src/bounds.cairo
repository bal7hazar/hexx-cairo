//! `bounds`: `HexBounds`, a hexagonal area given by a centre and a radius (`src/bounds.rs`), with
//! membership, wrapping, corners, intersection and the smallest bounds of a set of hexes
//! (`FromIterator<Hex>`, here `from_span`). The cubic array `as_ivec3` of `hexx` is
//! `to_cubic_array` (the `glam` vectors belong to the companion package of L-M3).
//!
//! Where `hexx` returns an iterator (`all_coords`, `intersecting_with`) this port returns a
//! `Span<Hex>`; where it casts a `u32` radius to `i32` with `as` (which wraps) this port panics
//! above `i32::MAX`. Every operation whose result leaves its integer type panics, where `hexx`
//! panics in a debug build and wraps in a release build (plan §3.1).

use crate::direction::edge_direction::EdgeDirectionTrait;
use crate::direction::impls::EdgeDirectionOpsTrait;
use crate::hex::impls::HexOpsTrait;
use crate::hex::{Hex, HexTrait};

/// Hexagonal bounds, represented as a centre and a radius.
///
/// Mirrors `hexx::HexBounds` (`src/bounds.rs:36`), with its public fields `center` (`:38`) and
/// `radius` (`:40`).
///
/// #### Panics
///
/// None: a struct holds any centre and any radius.
///
/// #### Deviations
///
/// Derives `Serde`, `Default`, `Hash` as a matter of course (plan §2.3), as `Hex` does.
#[derive(Copy, Drop, Serde, PartialEq, Default, Hash, Debug)]
pub struct HexBounds {
    pub center: Hex,
    pub radius: u32,
}

/// The items of `impl HexBounds` (`src/bounds.rs`) and of its `FromIterator<Hex>`.
pub trait HexBoundsTrait {
    /// Instantiates new bounds from a `center` and `radius`.
    ///
    /// Mirrors `HexBounds::new` (`src/bounds.rs:47`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn new(center: Hex, radius: u32) -> HexBounds;

    /// Instantiates new bounds from a `radius` at `Hex::ZERO`.
    ///
    /// Mirrors `HexBounds::from_radius` (`src/bounds.rs:54`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn from_radius(radius: u32) -> HexBounds;

    /// The bounds of centre `(min + max) / 2` and of radius the distance from that centre to
    /// `max`.
    ///
    /// Mirrors `HexBounds::from_min_max` (`src/bounds.rs:64`).
    ///
    /// #### Panics
    ///
    /// Where `const_add`, `div_scalar` or `unsigned_distance_to` does.
    ///
    /// #### Deviations
    ///
    /// Inherits the deviation of `div_scalar` (M2-T3): `(min + max) / 2` is `hexx`'s `Div<i32>`,
    /// the rescale of `Hex` by its length, which `hexx` computes in `f32` and this port computes
    /// exactly. The centre differs from `hexx`'s where `div_scalar(2)` does (the pairs listed in
    /// `docs/deviations/div_scalar.md`: `f32` error at a rounding tie, and lengths beyond `2^20`),
    /// and the radius with it. `hexx` wraps in a release build and panics in a debug build (plan
    /// §3.1); this port panics exactly where the debug build does.
    fn from_min_max(min: Hex, max: Hex) -> HexBounds;

    /// The bounds of radius `radius` whose coordinates are all positive: centred on
    /// `Hex::splat(radius)`. Efficient map storage in a 2D array disallowing negative coordinates.
    ///
    /// Mirrors `HexBounds::positive_radius` (`src/bounds.rs:78`).
    ///
    /// #### Panics
    ///
    /// When `radius` is above `i32::MAX`.
    ///
    /// #### Deviations
    ///
    /// `hexx` casts `radius` to `i32` with `as`, which wraps; this port panics above `i32::MAX`.
    fn positive_radius(radius: u32) -> HexBounds;

    /// Whether `rhs` is in the bounds: its distance from the centre is at most the radius.
    ///
    /// Mirrors `HexBounds::is_in_bounds` (`src/bounds.rs:86`).
    ///
    /// #### Panics
    ///
    /// Where `unsigned_distance_to` does.
    ///
    /// #### Deviations
    ///
    /// `hexx` wraps in a release build and panics in a debug build (plan §3.1); this port panics
    /// exactly where the debug build does.
    fn is_in_bounds(self: HexBounds, rhs: Hex) -> bool;

    /// The number of hexagons in the bounds.
    ///
    /// Mirrors `HexBounds::hex_count` (`src/bounds.rs:95`).
    ///
    /// #### Panics
    ///
    /// When `Hex::range_count(radius)` leaves `u32` (`radius` above 37,836).
    ///
    /// #### Deviations
    ///
    /// `usize` is `u32` in Cairo, so this is `hex_count32`.
    fn hex_count(self: HexBounds) -> usize;

    /// The number of hexagons in the bounds.
    ///
    /// Mirrors `HexBounds::hex_count32` (`src/bounds.rs:104`).
    ///
    /// #### Panics
    ///
    /// When `Hex::range_count(radius)` leaves `u32` (`radius` above 37,836).
    ///
    /// #### Deviations
    ///
    /// None.
    fn hex_count32(self: HexBounds) -> u32;

    /// Every coordinate in the bounds, `hex_count` of them, in the order of `Hex::range`: `x`
    /// ascending, then `y` ascending.
    ///
    /// Mirrors `HexBounds::all_coords` (`src/bounds.rs:111`).
    ///
    /// #### Panics
    ///
    /// Where `Hex::range` does.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `ExactSizeIterator`.
    fn all_coords(self: HexBounds) -> Span<Hex>;

    /// Every coordinate in the intersection of `self` and `rhs`: the coordinates of the bounds of
    /// the smaller radius (`self` when the radii are equal), in the order of `all_coords`, that
    /// are in the other.
    ///
    /// Mirrors `HexBounds::intersecting_with` (`src/bounds.rs:116`).
    ///
    /// #### Panics
    ///
    /// Where `all_coords` or `is_in_bounds` does.
    ///
    /// #### Deviations
    ///
    /// A `Span<Hex>` instead of an `Iterator`.
    fn intersecting_with(self: HexBounds, rhs: HexBounds) -> Span<Hex>;

    /// `coord` wrapped into the bounds, as a local coordinate relative to the centre: the
    /// seamless *wraparound* of a hexagonal map.
    ///
    /// Mirrors `HexBounds::wrap_local` (`src/bounds.rs:135`).
    ///
    /// #### Panics
    ///
    /// Where `const_sub` or `wrap_in_range` does.
    ///
    /// #### Deviations
    ///
    /// Inherits the exact floor of `wrap_in_range` and its bound `|value| < 2^24`.
    fn wrap_local(self: HexBounds, coord: Hex) -> Hex;

    /// `coord` wrapped into the bounds, as a global coordinate.
    ///
    /// Mirrors `HexBounds::wrap` (`src/bounds.rs:149`).
    ///
    /// #### Panics
    ///
    /// Where `wrap_local` or `const_add` does.
    ///
    /// #### Deviations
    ///
    /// Inherits the exact floor of `wrap_in_range` and its bound `|value| < 2^24`.
    fn wrap(self: HexBounds, coord: Hex) -> Hex;

    /// The six corners of the bounds, in `EdgeDirection::ALL_DIRECTIONS` order.
    ///
    /// Mirrors `HexBounds::corners` (`src/bounds.rs:156`).
    ///
    /// #### Panics
    ///
    /// When `radius` is above `i32::MAX`, or a coordinate of a corner leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// `hexx` casts `radius` to `i32` with `as`, which wraps; this port panics above `i32::MAX`.
    fn corners(self: HexBounds) -> [Hex; 6];

    /// The smallest bounds that contain every hexagon of `span`; the origin with radius 0 for the
    /// empty span. The centre is the first admissible one in the order of `hexx`'s algorithm
    /// (the minimal radius, then the centre moved along `x`, then `y`).
    ///
    /// Counterpart of `impl FromIterator<Hex> for HexBounds` (`src/bounds.rs:161`).
    ///
    /// #### Panics
    ///
    /// When a term of the computation (the cubic coordinates, the extent, the sums) leaves `i32`,
    /// where `hexx` panics in a debug build.
    ///
    /// #### Deviations
    ///
    /// A named method on a `Span<Hex>`: Cairo has no `FromIterator`. `hexx` works on `IVec3`
    /// (`as_ivec3`); this port on the three components of `to_cubic_array`.
    fn from_span(span: Span<Hex>) -> HexBounds;
}

pub impl HexBoundsImpl of HexBoundsTrait {
    #[inline]
    fn new(center: Hex, radius: u32) -> HexBounds {
        HexBounds { center, radius }
    }

    #[inline]
    fn from_radius(radius: u32) -> HexBounds {
        HexBounds { center: HexTrait::ZERO, radius }
    }

    fn from_min_max(min: Hex, max: Hex) -> HexBounds {
        let center = min.const_add(max).div_scalar(2);
        let radius = center.unsigned_distance_to(max);
        HexBounds { center, radius }
    }

    #[inline]
    fn positive_radius(radius: u32) -> HexBounds {
        let center = HexTrait::splat(radius.try_into().unwrap());
        HexBounds { center, radius }
    }

    #[inline]
    fn is_in_bounds(self: HexBounds, rhs: Hex) -> bool {
        self.center.unsigned_distance_to(rhs) <= self.radius
    }

    #[inline]
    fn hex_count(self: HexBounds) -> usize {
        HexTrait::range_count(self.radius)
    }

    #[inline]
    fn hex_count32(self: HexBounds) -> u32 {
        HexTrait::range_count(self.radius)
    }

    #[inline]
    fn all_coords(self: HexBounds) -> Span<Hex> {
        self.center.range(self.radius)
    }

    fn intersecting_with(self: HexBounds, rhs: HexBounds) -> Span<Hex> {
        let (start, end) = if self.radius > rhs.radius {
            (rhs, self)
        } else {
            (self, rhs)
        };
        let mut coords = start.all_coords();
        let mut intersection = array![];
        while let Some(hex) = coords.pop_front() {
            if end.is_in_bounds(*hex) {
                intersection.append(*hex);
            }
        }
        intersection.span()
    }

    #[inline]
    fn wrap_local(self: HexBounds, coord: Hex) -> Hex {
        coord.const_sub(self.center).wrap_in_range(self.radius)
    }

    #[inline]
    fn wrap(self: HexBounds, coord: Hex) -> Hex {
        self.wrap_local(coord).const_add(self.center)
    }

    fn corners(self: HexBounds) -> [Hex; 6] {
        let radius: i32 = self.radius.try_into().unwrap();
        let [n0, n1, n2, n3, n4, n5] = EdgeDirectionTrait::ALL_DIRECTIONS;
        [
            self.center.const_add(n0.mul_scalar(radius)),
            self.center.const_add(n1.mul_scalar(radius)),
            self.center.const_add(n2.mul_scalar(radius)),
            self.center.const_add(n3.mul_scalar(radius)),
            self.center.const_add(n4.mul_scalar(radius)),
            self.center.const_add(n5.mul_scalar(radius)),
        ]
    }

    fn from_span(span: Span<Hex>) -> HexBounds {
        let mut span = span;
        // Exit early with a zero radius bounds at the origin
        let Some(first) = span.pop_front() else {
            return Self::from_radius(0);
        };

        // Step 1: the minimum size of the hexagon that can contain all the hexes: the minimum and
        // the maximum of each cubic axis, starting from the first hex
        let [x, y, z] = (*first).to_cubic_array();
        let (mut max_x, mut max_y, mut max_z) = (x, y, z);
        let (mut min_x, mut min_y, mut min_z) = (x, y, z);
        while let Some(hex) = span.pop_front() {
            let [x, y, z] = (*hex).to_cubic_array();
            if x > max_x {
                max_x = x;
            } else if x < min_x {
                min_x = x;
            }
            if y > max_y {
                max_y = y;
            } else if y < min_y {
                min_y = y;
            }
            if z > max_z {
                max_z = z;
            } else if z < min_z {
                min_z = z;
            }
        }

        // The hexagon is bounded 5 ways: 3 by opposite edges (`duo`: the largest extent of an
        // axis), 2 by triplets of edges, for the more triangular shapes (`trio`: the larger of
        // the two sums). Each size is converted to a radius, rounding up, and the largest radius
        // is the minimum one.
        let duo_size = BoundsMathTrait::max3(max_x - min_x, max_y - min_y, max_z - min_z);
        let trio_size = BoundsMathTrait::max2(max_x + max_y + max_z, -(min_x + min_y + min_z));
        let duo_radius = (duo_size + 1) / 2;
        let trio_radius = (trio_size + 2) / 3;
        let radius = BoundsMathTrait::max2(duo_radius, trio_radius);

        // Step 2: the centre of the hexagon exists between these extremes ...
        let (min_center_x, min_center_y, min_center_z) = (
            max_x - radius, max_y - radius, max_z - radius,
        );
        let (max_center_x, max_center_y, max_center_z) = (
            min_x + radius, min_y + radius, min_z + radius,
        );
        // ... with this much room on each axis (`z`'s is never read, but `hexx` computes it)
        let range_x = max_center_x - min_center_x;
        let range_y = max_center_y - min_center_y;
        let _range_z = max_center_z - min_center_z;

        // Start with the centre at the minimum; the sum of its cubic coordinates needs to be 0,
        // and is never positive. Fix it by moving along `x` if the room allows, else as far as
        // possible along `x` and then along `y`; `z` could always fix it, and the centre would
        // then be `max_center`, so its axis is skipped.
        let mut center_x = min_center_x;
        let mut center_y = min_center_y;
        let mut sum = min_center_x + min_center_y + min_center_z;
        if -sum > range_x {
            sum += range_x;
            center_x += range_x;
            if -sum > range_y {
                center_y += range_y;
            } else {
                center_y -= sum;
            }
        } else {
            center_x -= sum;
        }
        HexBounds { center: Hex { x: center_x, y: center_y }, radius: radius.try_into().unwrap() }
    }
}

/// The scalar helpers of `from_span`: private, what `Ord::max` is on `i32` in Rust.
#[generate_trait]
impl BoundsMathImpl of BoundsMathTrait {
    #[inline]
    fn max2(a: i32, b: i32) -> i32 {
        if a > b {
            a
        } else {
            b
        }
    }

    #[inline]
    fn max3(a: i32, b: i32, c: i32) -> i32 {
        Self::max2(Self::max2(a, b), c)
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::direction::edge_direction::EdgeDirectionTrait;
    use crate::hex::impls::HexOpsTrait;
    use crate::hex::{Hex, HexTrait};
    use super::{HexBounds, HexBoundsTrait};

    /// What the oracles and the benchmarks share: a deterministic generator (an LCG on `u64`,
    /// below `2^31`, so that no product leaves `u64`) and the plain definition of membership.
    #[generate_trait]
    impl OracleImpl of OracleTrait {
        /// The next state of the generator.
        fn next(seed: u64) -> u64 {
            (seed * 1103515245 + 12345) % 2147483648
        }

        /// A seeded value of `[-range, range]`.
        fn value(ref seed: u64, range: u32) -> i32 {
            seed = Self::next(seed);
            let width: u64 = (2 * range + 1).into();
            let v: i32 = ((seed / 65536) % width).try_into().unwrap();
            v - range.try_into().unwrap()
        }

        /// A seeded hexagon of `[-range, range]²`.
        fn point(ref seed: u64, range: u32) -> Hex {
            let x = Self::value(ref seed, range);
            let y = Self::value(ref seed, range);
            Hex { x, y }
        }

        /// A seeded span of `count` hexagons of `[-range, range]²`.
        fn points(ref seed: u64, count: u32, range: u32) -> Span<Hex> {
            let mut hexes = array![];
            let mut i = 0;
            while i < count {
                hexes.append(Self::point(ref seed, range));
                i += 1;
            }
            hexes.span()
        }

        fn abs(v: i32) -> i32 {
            if v < 0 {
                -v
            } else {
                v
            }
        }

        /// The definition of the bounds, in cubic coordinates, and nothing else: `|dx|`, `|dy|`
        /// and `|dx + dy|` are at most the radius, `d` being the offset from the centre.
        fn plain_in(bounds: HexBounds, h: Hex) -> bool {
            let r: i32 = bounds.radius.try_into().unwrap();
            let dx = h.x - bounds.center.x;
            let dy = h.y - bounds.center.y;
            Self::abs(dx) <= r && Self::abs(dy) <= r && Self::abs(dx + dy) <= r
        }

        /// Whether every hexagon of `span` is in `bounds`, by the plain definition.
        fn plain_contains(bounds: HexBounds, span: Span<Hex>) -> bool {
            let mut rest = span;
            let mut all = true;
            while let Some(h) = rest.pop_front() {
                if !Self::plain_in(bounds, *h) {
                    all = false;
                    break;
                }
            }
            all
        }

        /// Whether some bounds of radius `radius` contain `span`: the centre is within `radius`
        /// of the first hexagon, so the candidates are `first.range(radius)`.
        fn exists_with(span: Span<Hex>, radius: u32) -> bool {
            let mut centers = (*span.at(0)).range(radius);
            let mut found = false;
            while let Some(center) = centers.pop_front() {
                if Self::plain_contains(HexBounds { center: *center, radius }, span) {
                    found = true;
                    break;
                }
            }
            found
        }
    }

    // ----- the tests of `hexx` (`src/bounds.rs:241-455`) -----

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_in_bounds_work() {
        let bounds = HexBoundsTrait::new(HexTrait::new(-4, 23), 7);
        let mut coords = bounds.all_coords();
        assert!(coords.len() == 127);
        while let Some(h) = coords.pop_front() {
            assert!(bounds.is_in_bounds(*h));
        }
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_intersecting_with() {
        let ba = HexBoundsTrait::new(HexTrait::ZERO, 3);
        let bb = HexBoundsTrait::new(HexTrait::new(4, 0), 3);
        assert!(ba.intersecting_with(bb).len() == 9);
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_wrapping_works() {
        let map = HexBoundsTrait::from_radius(3);
        assert!(map.wrap(HexTrait::new(0, 4)) == HexTrait::new(-3, 0));
        assert!(map.wrap(HexTrait::new(4, 0)) == HexTrait::new(-3, 3));
        assert!(map.wrap(HexTrait::new(4, -4)) == HexTrait::new(0, 3));
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_wrapping_outside_works() {
        let map = HexBoundsTrait::from_radius(2);
        assert!(map.wrap(HexTrait::new(3, 0)) == HexTrait::new(-2, 2));
        assert!(map.wrap(HexTrait::new(5, 0)) == HexTrait::new(0, 2));
        assert!(map.wrap(HexTrait::new(6, 0)) == HexTrait::new(-1, -1));
        // mirror
        assert!(map.wrap(HexTrait::new(2, 3)) == HexTrait::new(0, 0));
        assert!(map.wrap(HexTrait::new(4, 6)) == HexTrait::new(0, 0));
    }

    /// `hexx` goes to radius 99; the coordinates of radius `r` are all positive for any `r`, and
    /// 0 to 6 hold the property in the ranges the gas budget allows.
    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_positive_radius() {
        let mut radius = 0;
        while radius < 7 {
            let bounds = HexBoundsTrait::positive_radius(radius);
            assert!(bounds.radius == radius);
            let mut coords = bounds.all_coords();
            while let Some(c) = coords.pop_front() {
                assert!(*c.x >= 0 && *c.y >= 0);
            }
            radius += 1;
        }
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_bounds_hexagon() {
        let mut centers = array![HexTrait::ZERO, HexTrait::new(15, -19)].span();
        while let Some(center) = centers.pop_front() {
            let mut radius = 0;
            while radius < 5 {
                let bounds = HexBoundsTrait::new(*center, radius);
                assert!(HexBoundsTrait::from_span(bounds.all_coords()) == bounds);
                assert!(HexBoundsTrait::from_span(bounds.corners().span()) == bounds);
                radius += 1;
            }
        }
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_range_works() {
        let coords = HexTrait::ZERO.range(5);
        let bounds = HexBoundsTrait::from_span(coords);
        assert!(bounds.center == HexTrait::ZERO && bounds.radius == 5);
        let mut rest = coords;
        while let Some(h) = rest.pop_front() {
            assert!(bounds.is_in_bounds(*h));
        }
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_bounds_rhombus() {
        let mut size = 1;
        while size < 6 {
            let mut rotation = 0;
            while rotation < 3 {
                let mut coords = array![];
                let mut i = 0;
                while i < size * size {
                    coords.append(HexTrait::new(i / size, i % size).rotate_cw(rotation));
                    i += 1;
                }
                let reconstructed = HexBoundsTrait::from_span(coords.span());
                assert!(OracleTrait::plain_contains(reconstructed, coords.span()));
                assert!(reconstructed.radius == size.try_into().unwrap() - 1);
                rotation += 1;
            }
            size += 1;
        }
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_bounds_line() {
        let mut direction = 0;
        while direction < 6 {
            let mut size = 1;
            while size < 6 {
                let mut line = HexTrait::ZERO.line_to(HexTrait::new(size, 0));
                let mut coords = array![];
                while let Some(h) = line.pop_front() {
                    coords.append((*h).rotate_cw(direction));
                }
                let reconstructed = HexBoundsTrait::from_span(coords.span());
                assert!(OracleTrait::plain_contains(reconstructed, coords.span()));
                // `size.div_ceil(2)`
                assert!(reconstructed.radius == (size.try_into().unwrap() + 1) / 2);
                size += 1;
            }
            direction += 1;
        }
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_bounds_edge_cases() {
        // Doesn't matter where it's placed, the radius is 0: the origin, as `hexx` does.
        let empty: Span<Hex> = array![].span();
        assert!(HexBoundsTrait::from_span(empty) == HexBoundsTrait::from_radius(0));
        let one = array![HexTrait::ZERO].span();
        assert!(HexBoundsTrait::from_span(one) == HexBoundsTrait::from_radius(0));
    }

    // ----- the other items -----

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_constructors() {
        let bounds = HexBoundsTrait::new(HexTrait::new(1, -2), 3);
        assert!(bounds.center == HexTrait::new(1, -2) && bounds.radius == 3);
        assert!(HexBoundsTrait::from_radius(4) == HexBoundsTrait::new(HexTrait::ZERO, 4));
        assert!(HexBoundsTrait::positive_radius(4).center == HexTrait::splat(4));
        let bounds = HexBoundsTrait::from_min_max(HexTrait::new(-2, 0), HexTrait::new(2, 0));
        assert!(bounds == HexBoundsTrait::new(HexTrait::ZERO, 2));
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_hex_count() {
        assert!(HexBoundsTrait::from_radius(0).hex_count() == 1);
        assert!(HexBoundsTrait::from_radius(6).hex_count() == 127);
        assert!(HexBoundsTrait::from_radius(64).hex_count32() == 12481);
        assert!(HexBoundsTrait::from_radius(37836).hex_count32() == 4294705153);
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    #[should_panic]
    fn test_hex_count_overflow() {
        let _ = HexBoundsTrait::from_radius(37837).hex_count32();
    }

    /// `hexx` casts the radius with `as`, which wraps; the port panics above `i32::MAX`.
    #[test]
    #[available_gas(l2_gas: 7000000)]
    #[should_panic]
    fn test_positive_radius_above_i32() {
        let _ = HexBoundsTrait::positive_radius(2147483648);
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    #[should_panic]
    fn test_corners_radius_above_i32() {
        let _ = HexBoundsTrait::from_radius(2147483648).corners();
    }

    #[test]
    #[available_gas(l2_gas: 7000000)]
    fn test_corners() {
        let [c0, c1, c2, c3, c4, c5] = HexBoundsTrait::new(HexTrait::new(1, 1), 2).corners();
        let all = EdgeDirectionTrait::ALL_DIRECTIONS.span();
        let mut corners = array![c0, c1, c2, c3, c4, c5].span();
        let mut directions = all;
        while let Some(corner) = corners.pop_front() {
            let direction = *directions.pop_front().unwrap();
            assert!(
                *corner == HexTrait::new(1, 1).add_direction(direction).add_direction(direction),
            );
        }
    }

    // ----- the oracles (D-167) -----

    /// `is_in_bounds` against the plain cubic definition, over `all_coords` of a larger bounds
    /// (every hexagon of it is tested, in or out), and the count of hexagons in against
    /// `hex_count`.
    #[test]
    #[available_gas(l2_gas: 40000000)]
    fn test_is_in_bounds_oracle() {
        let bounds = HexBoundsTrait::new(HexTrait::new(3, -5), 4);
        let larger = HexBoundsTrait::new(HexTrait::new(1, 1), 9);
        let mut coords = larger.all_coords();
        let mut inside = 0;
        while let Some(h) = coords.pop_front() {
            let expected = OracleTrait::plain_in(bounds, *h);
            assert!(bounds.is_in_bounds(*h) == expected);
            assert!(expected == (bounds.center.unsigned_distance_to(*h) <= bounds.radius));
            if expected {
                inside += 1;
            }
        }
        assert!(inside == bounds.hex_count32());
    }

    /// `intersecting_with` as a set against the per-hexagon membership of both bounds: over a
    /// window that holds both, its elements are exactly the hexagons in both, each once (the
    /// order is `x` then `y` ascending), whichever of the two is the smaller, and for equal radii.
    #[test]
    #[available_gas(l2_gas: 400000000)]
    fn test_intersecting_with_oracle() {
        let window = HexBoundsTrait::from_radius(14);
        let bounds = array![
            HexBoundsTrait::new(HexTrait::new(0, 0), 5),
            HexBoundsTrait::new(HexTrait::new(4, -2), 5),
            HexBoundsTrait::new(HexTrait::new(-3, 3), 2),
            HexBoundsTrait::new(HexTrait::new(6, 1), 4),
            HexBoundsTrait::new(HexTrait::new(7, -7), 0),
        ];
        let mut firsts = bounds.span();
        while let Some(a) = firsts.pop_front() {
            let mut seconds = bounds.span();
            while let Some(b) = seconds.pop_front() {
                let mut expected = array![];
                let mut coords = window.all_coords();
                while let Some(h) = coords.pop_front() {
                    if OracleTrait::plain_in(*a, *h) && OracleTrait::plain_in(*b, *h) {
                        expected.append(*h);
                    }
                }
                let got = (*a).intersecting_with(*b);
                assert!(got == expected.span());
            }
        }
    }

    /// `from_span` returns bounds that contain every point of the span (by the plain definition)
    /// and whose radius minus one does not, around the same centre, on 16 seeded spans of 1 to 32
    /// points, triangular shapes (the `trio` branch of `hexx`'s algorithm) among them.
    #[test]
    #[available_gas(l2_gas: 400000000)]
    fn test_from_span_oracle() {
        let mut seed: u64 = 20260610;
        let mut i: u32 = 0;
        while i < 16 {
            let count = 1 + OracleTrait::next(seed) % 32;
            seed = OracleTrait::next(seed);
            let span = OracleTrait::points(ref seed, count.try_into().unwrap(), 20);
            let bounds = HexBoundsTrait::from_span(span);
            assert!(OracleTrait::plain_contains(bounds, span));
            if bounds.radius > 0 {
                let smaller = HexBounds { center: bounds.center, radius: bounds.radius - 1 };
                assert!(!OracleTrait::plain_contains(smaller, span));
            }
            i += 1;
        }
    }

    /// Minimality in full: no bounds of radius `r - 1`, around any centre, contain a seeded span
    /// of a small window, nor a triangle of side 1 to 8 (the shapes of the `trio` branch).
    #[test]
    #[available_gas(l2_gas: 2000000000)]
    fn test_from_span_minimal() {
        let mut seed: u64 = 7;
        let mut spans = array![];
        let mut i: u32 = 0;
        while i < 8 {
            seed = OracleTrait::next(seed);
            let count: u32 = (1 + seed % 8).try_into().unwrap();
            spans.append(OracleTrait::points(ref seed, count, 5));
            i += 1;
        }
        let mut side = 1;
        while side < 9 {
            spans
                .append(
                    array![HexTrait::ZERO, HexTrait::new(side, 0), HexTrait::new(0, side)].span(),
                );
            side += 1;
        }
        let mut rest = spans.span();
        while let Some(span) = rest.pop_front() {
            let bounds = HexBoundsTrait::from_span(*span);
            assert!(OracleTrait::plain_contains(bounds, *span));
            if bounds.radius > 0 {
                assert!(!OracleTrait::exists_with(*span, bounds.radius - 1));
            }
        }
    }

    // Benchmarks of M2-T5 (LIB-06): per call = (test - baseline) / reps. Targets (`L`, `U =
    // ceil(1.25 L)`, the brief's table, written before the first measurement; the budgets of these
    // tests are placeholders until CI's artefact pins them, LIB-04i):
    //
    // | function | case | `L` | `U` |
    // |---|---|---|---|
    // | `is_in_bounds` | any | 12,073 | 15,092 |
    // | `hex_count`, `hex_count32` | radius 64 | 4,120 | 5,150 |
    // | `wrap`, `wrap_local` | radius 6 | 39,688 | 49,610 |
    // | `from_min_max` | any | 42,930 | 53,663 |
    // | `corners` | radius 6 | 43,626 | 54,533 |
    // | `all_coords` | radius 6 | 934,466 | 1,168,083 |
    // | `intersecting_with` | radii 6 and 6 | 2,467,737 | 3,084,672 |
    // | `from_span` | 16 points | 168,904 | 211,130 |

    const REPS: u8 = 10;

    #[test]
    #[available_gas(l2_gas: 20000000)]
    fn bench_bounds_baseline() {
        let bounds = HexBoundsTrait::new(HexTrait::new(2, -3), 6);
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let h = HexTrait::new(n.into(), 2);
            acc += h.x + bounds.center.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 20000000)]
    fn bench_bounds_is_in_bounds() {
        let bounds = HexBoundsTrait::new(HexTrait::new(2, -3), 6);
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let h = HexTrait::new(n.into(), 2);
            if bounds.is_in_bounds(h) {
                acc += 1;
            }
            acc += h.x + bounds.center.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 20000000)]
    fn bench_bounds_hex_count() {
        let bounds = HexBoundsTrait::from_radius(64);
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            acc += bounds.hex_count() + bounds.hex_count32();
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 20000000)]
    fn bench_bounds_wrap() {
        let bounds = HexBoundsTrait::new(HexTrait::new(2, -3), 6);
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let h = bounds.wrap(HexTrait::new(30 + n.into(), -25));
            acc += h.x + bounds.center.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 20000000)]
    fn bench_bounds_wrap_local() {
        let bounds = HexBoundsTrait::new(HexTrait::new(2, -3), 6);
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let h = bounds.wrap_local(HexTrait::new(30 + n.into(), -25));
            acc += h.x + bounds.center.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 20000000)]
    fn bench_bounds_from_min_max() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let b = HexBoundsTrait::from_min_max(HexTrait::new(-9, 4), HexTrait::new(n.into(), 7));
            acc += b.center.x;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 20000000)]
    fn bench_bounds_corners() {
        let bounds = HexBoundsTrait::new(HexTrait::new(2, -3), 6);
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let [c0, _, _, _, _, _] = bounds.corners();
            acc += c0.x + bounds.center.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 20000000)]
    fn bench_bounds_all_coords() {
        let bounds = HexBoundsTrait::new(HexTrait::new(2, -3), 6);
        assert!(bounds.all_coords().len() == 127);
    }

    #[test]
    #[available_gas(l2_gas: 20000000)]
    fn bench_bounds_intersecting_with() {
        let a = HexBoundsTrait::new(HexTrait::new(2, -3), 6);
        let b = HexBoundsTrait::new(HexTrait::new(-1, 2), 6);
        assert!(a.intersecting_with(b).len() > 0);
    }

    #[test]
    #[available_gas(l2_gas: 20000000)]
    fn bench_bounds_from_span_baseline() {
        let mut seed: u64 = 99;
        let span = OracleTrait::points(ref seed, 16, 20);
        assert!(span.len() == 16);
    }

    #[test]
    #[available_gas(l2_gas: 20000000)]
    fn bench_bounds_from_span() {
        let mut seed: u64 = 99;
        let span = OracleTrait::points(ref seed, 16, 20);
        assert!(HexBoundsTrait::from_span(span).radius > 0);
    }
}
