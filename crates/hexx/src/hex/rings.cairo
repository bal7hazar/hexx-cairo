//! `hex/rings`: the rings, ring edges, wedges and spirals of `Hex` (`src/hex/rings.rs`), and
//! `circular_range_squared`, the integer counterpart of `circular_range` (`src/hex/euclidean.rs`).
//! `ring_count` and `wedge_count` are in `hex.cairo` (M2-T0).
//!
//! `hexx`'s iterators are eager spans here (plan §4.4): an `impl Iterator<Item = Hex>` is a
//! `Span<Hex>`, an iterator of `Vec<Hex>` a `Span<Span<Hex>>`, and an `impl Iterator<Item = u32>`
//! of radii a `Span<u32>`. Every span keeps `hexx`'s order and length, radius 0 included. Being
//! eager, a function panics at its call where `hexx` panics only if the iterator is consumed that
//! far.

use core::num::traits::Sqrt;
use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
use crate::direction::impls::EdgeDirectionOpsTrait;
use crate::direction::vertex_direction::{VertexDirection, VertexDirectionTrait};
use crate::direction::way::DirectionWayTrait;
use crate::hex::{Hex, HexTrait};

/// The rings, ring edges, wedges and spirals of `Hex`.
pub trait HexRingsTrait {
    /// One ring around `self` at `range`, starting from `start_dir` and looping counter-clockwise
    /// unless `clockwise`. It has `ring_count(range)` hexes: `6 * range`, or `self` alone when
    /// `range` is 0.
    ///
    /// Mirrors `Hex::custom_ring` (`src/hex/rings.rs:15`).
    ///
    /// #### Panics
    ///
    /// When `range` does not fit `i32`, or `self + start_dir * range` or a hex of the ring leaves
    /// `i32`.
    ///
    /// #### Deviations
    ///
    /// Eager: the span is built at the call. `hexx` wraps in a release build and panics in a
    /// debug build (plan §3.1); this port panics exactly where the debug build does, and also on
    /// a range that does not fit `i32`, where `hexx` casts (`as i32`).
    fn custom_ring(self: Hex, range: u32, start_dir: EdgeDirection, clockwise: bool) -> Span<Hex>;

    /// One ring around `self` at `range`, starting from the default `EdgeDirection` and looping
    /// counter-clockwise.
    ///
    /// Mirrors `Hex::ring` (`src/hex/rings.rs:57`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring`.
    ///
    /// #### Deviations
    ///
    /// As `custom_ring`.
    fn ring(self: Hex, range: u32) -> Span<Hex>;

    /// The rings of `self` at each radius of `range`, from the default `EdgeDirection`,
    /// counter-clockwise.
    ///
    /// Mirrors `Hex::rings` (`src/hex/rings.rs:75`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring`.
    ///
    /// #### Deviations
    ///
    /// The iterator of radii is a `Span<u32>`, the iterator of rings a `Span<Span<Hex>>`; eager.
    fn rings(self: Hex, range: Span<u32>) -> Span<Span<Hex>>;

    /// The rings of `self` at each radius of `range`, from `start_dir`, counter-clockwise unless
    /// `clockwise`.
    ///
    /// Mirrors `Hex::custom_rings` (`src/hex/rings.rs:95`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring`.
    ///
    /// #### Deviations
    ///
    /// As `rings`.
    fn custom_rings(
        self: Hex, range: Span<u32>, start_dir: EdgeDirection, clockwise: bool,
    ) -> Span<Span<Hex>>;

    /// One ring edge around `self` at `radius` and `direction`: `radius + 1` hexes, counter-
    /// clockwise unless `clockwise`.
    ///
    /// Mirrors `Hex::custom_ring_edge` (`src/hex/rings.rs:113`).
    ///
    /// #### Panics
    ///
    /// When `radius` does not fit `i32`, or `self + start * radius` or a hex of the edge leaves
    /// `i32`.
    ///
    /// #### Deviations
    ///
    /// Eager: the span is built at the call. `hexx` wraps in a release build and panics in a
    /// debug build (plan §3.1); this port panics exactly where the debug build does, and also on
    /// a range that does not fit `i32`, where `hexx` casts (`as i32`).
    fn custom_ring_edge(
        self: Hex, radius: u32, direction: VertexDirection, clockwise: bool,
    ) -> Span<Hex>;

    /// One ring edge around `self` at `radius` and `direction`, counter-clockwise.
    ///
    /// Mirrors `Hex::ring_edge` (`src/hex/rings.rs:160`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring_edge`.
    ///
    /// #### Deviations
    ///
    /// As `custom_ring_edge`.
    fn ring_edge(self: Hex, radius: u32, direction: VertexDirection) -> Span<Hex>;

    /// The successive ring edges around `self` at each radius of `ranges`, counter-clockwise.
    ///
    /// Mirrors `Hex::ring_edges` (`src/hex/rings.rs:185`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring_edge`.
    ///
    /// #### Deviations
    ///
    /// The iterator of radii is a `Span<u32>`, the iterator of edges a `Span<Span<Hex>>`; eager.
    fn ring_edges(self: Hex, ranges: Span<u32>, direction: VertexDirection) -> Span<Span<Hex>>;

    /// The successive ring edges around `self` at each radius of `ranges`, counter-clockwise
    /// unless `clockwise`.
    ///
    /// Mirrors `Hex::custom_ring_edges` (`src/hex/rings.rs:211`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring_edge`.
    ///
    /// #### Deviations
    ///
    /// As `ring_edges`.
    fn custom_ring_edges(
        self: Hex, ranges: Span<u32>, direction: VertexDirection, clockwise: bool,
    ) -> Span<Span<Hex>>;

    /// The successive ring edges of `custom_ring_edges`, flattened into one span.
    ///
    /// Mirrors `Hex::custom_wedge` (`src/hex/rings.rs:229`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring_edge`.
    ///
    /// #### Deviations
    ///
    /// The iterator of radii is a `Span<u32>`; eager.
    fn custom_wedge(
        self: Hex, ranges: Span<u32>, direction: VertexDirection, clockwise: bool,
    ) -> Span<Hex>;

    /// The wedge from `self` to `rhs`: `custom_full_wedge` at their distance, in the diagonal
    /// direction of `diagonal_way_to` (the first of the two on a tie).
    ///
    /// Mirrors `Hex::custom_wedge_to` (`src/hex/rings.rs:245`).
    ///
    /// #### Panics
    ///
    /// As `custom_full_wedge`, or when `self − rhs` leaves `i32`, the difference that
    /// `unsigned_distance_to` computes first (`Hex(i32::MAX, 0).wedge_to(Hex(-1, 0))`), as in
    /// `hexx`'s debug build; the distance itself, at most `2^31`, always fits `u32`.
    ///
    /// #### Deviations
    ///
    /// Eager.
    fn custom_wedge_to(self: Hex, rhs: Hex, clockwise: bool) -> Span<Hex>;

    /// The full wedge around `self` from radius 0 to `range` (`wedge_count(range)` hexes),
    /// counter-clockwise unless `clockwise`.
    ///
    /// Mirrors `Hex::custom_full_wedge` (`src/hex/rings.rs:261`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring_edge`, or when `wedge_count(range)` leaves `u32`.
    ///
    /// #### Deviations
    ///
    /// Eager.
    fn custom_full_wedge(
        self: Hex, range: u32, direction: VertexDirection, clockwise: bool,
    ) -> Span<Hex>;

    /// The successive ring edges around `self` at each radius of `range`, flattened,
    /// counter-clockwise.
    ///
    /// Mirrors `Hex::wedge` (`src/hex/rings.rs:295`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring_edge`.
    ///
    /// #### Deviations
    ///
    /// The iterator of radii is a `Span<u32>`; eager.
    fn wedge(self: Hex, range: Span<u32>, direction: VertexDirection) -> Span<Hex>;

    /// The wedge from `self` to `rhs`, counter-clockwise.
    ///
    /// Mirrors `Hex::wedge_to` (`src/hex/rings.rs:308`).
    ///
    /// #### Panics
    ///
    /// As `custom_wedge_to`.
    ///
    /// #### Deviations
    ///
    /// Eager.
    fn wedge_to(self: Hex, rhs: Hex) -> Span<Hex>;

    /// The full wedge around `self` from radius 0 to `range`, counter-clockwise.
    ///
    /// Mirrors `Hex::full_wedge` (`src/hex/rings.rs:318`).
    ///
    /// #### Panics
    ///
    /// As `custom_full_wedge`.
    ///
    /// #### Deviations
    ///
    /// Eager.
    fn full_wedge(self: Hex, range: u32, direction: VertexDirection) -> Span<Hex>;

    /// The half ring edges around `self` at each radius of `range` in `direction`: for each
    /// radius `r`, the first `r / 2 + 1` hexes of the edge towards `direction << 2`, then the
    /// `r / 2` hexes after the first of the edge towards `direction >> 2`.
    ///
    /// Mirrors `Hex::corner_wedge` (`src/hex/rings.rs:330`).
    ///
    /// #### Panics
    ///
    /// When a radius does not fit `i32`, or a hex of an edge leaves `i32`.
    ///
    /// #### Deviations
    ///
    /// The iterator of radii is a `Span<u32>`; eager.
    fn corner_wedge(self: Hex, range: Span<u32>, direction: EdgeDirection) -> Span<Hex>;

    /// The half ring edges from `self` to `rhs`: `corner_wedge` from radius 0 to their distance,
    /// in the direction of `way_to` (the first of the two on a tie).
    ///
    /// Mirrors `Hex::corner_wedge_to` (`src/hex/rings.rs:345`).
    ///
    /// #### Panics
    ///
    /// As `corner_wedge`, or when `self − rhs` leaves `i32`, the difference that
    /// `unsigned_distance_to` computes first (`Hex(i32::MAX, 0).corner_wedge_to(Hex(-1, 0))`), as
    /// in `hexx`'s debug build; the distance itself, at most `2^31`, always fits `u32`.
    ///
    /// #### Deviations
    ///
    /// Eager.
    fn corner_wedge_to(self: Hex, rhs: Hex) -> Span<Hex>;

    /// The ring edges of radii `0..range` around `self` in `direction`, counter-clockwise unless
    /// `clockwise`, as a span of edges: what `hexx` returns as `[Vec<Hex>; RANGE]`.
    ///
    /// Mirrors `Hex::cached_custom_ring_edges` (`src/hex/rings.rs:382`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring_edge`.
    ///
    /// #### Deviations
    ///
    /// The const generic `RANGE: usize` is a runtime `range: u32` (`usize` is `u32` in Cairo),
    /// and the array of vectors is a `Span<Span<Hex>>` of `range` edges.
    fn cached_custom_ring_edges(
        self: Hex, range: u32, direction: VertexDirection, clockwise: bool,
    ) -> Span<Span<Hex>>;

    /// The ring edges of radii `0..range` around `self` in `direction`, counter-clockwise.
    ///
    /// Mirrors `Hex::cached_ring_edges` (`src/hex/rings.rs:425`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring_edge`.
    ///
    /// #### Deviations
    ///
    /// As `cached_custom_ring_edges`.
    fn cached_ring_edges(self: Hex, range: u32, direction: VertexDirection) -> Span<Span<Hex>>;

    /// The rings of radii `0..range` around `self` from the default `EdgeDirection`,
    /// counter-clockwise.
    ///
    /// Mirrors `Hex::cached_rings` (`src/hex/rings.rs:464`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring`.
    ///
    /// #### Deviations
    ///
    /// As `cached_custom_ring_edges`.
    fn cached_rings(self: Hex, range: u32) -> Span<Span<Hex>>;

    /// The rings of radii `0..range` around `self` from `start_dir`, counter-clockwise unless
    /// `clockwise`.
    ///
    /// Mirrors `Hex::cached_custom_rings` (`src/hex/rings.rs:500`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring`.
    ///
    /// #### Deviations
    ///
    /// As `cached_custom_ring_edges`.
    fn cached_custom_rings(
        self: Hex, range: u32, start_dir: EdgeDirection, clockwise: bool,
    ) -> Span<Span<Hex>>;

    /// The hexes of the rings of `range`, flattened into one span (a spiral), from `start_dir`,
    /// counter-clockwise unless `clockwise`.
    ///
    /// Mirrors `Hex::custom_spiral_range` (`src/hex/rings.rs:516`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring`.
    ///
    /// #### Deviations
    ///
    /// The iterator of radii is a `Span<u32>`; eager.
    fn custom_spiral_range(
        self: Hex, range: Span<u32>, start_dir: EdgeDirection, clockwise: bool,
    ) -> Span<Hex>;

    /// The hexes of the rings of `range`, flattened into one span, from the default
    /// `EdgeDirection`, counter-clockwise.
    ///
    /// Mirrors `Hex::spiral_range` (`src/hex/rings.rs:533`).
    ///
    /// #### Panics
    ///
    /// As `custom_ring`.
    ///
    /// #### Deviations
    ///
    /// The iterator of radii is a `Span<u32>`; eager.
    fn spiral_range(self: Hex, range: Span<u32>) -> Span<Hex>;

    /// The hexes whose squared Euclidean distance to `self` is at most `range_squared`, in the
    /// order of `range`. A negative `range_squared` gives the empty span.
    ///
    /// For `range_squared = r²` with `r` an integer in `0..=40` it is the span of
    /// `hexx`'s `circular_range(r as f32)` element by element. For any other `range_squared` it
    /// is the exact set: a hex at hex distance `n` is at squared Euclidean distance at least
    /// `3 n² / 4` (the hexagon of radius `n` has inradius `n √3 / 2`), so the search stops at
    /// the largest `n` with `3 n² <= 4 * range_squared`, i.e. `floor(sqrt(4 * range_squared /
    /// 3))`.
    ///
    /// Mirrors `Hex::circular_range` (`src/hex/euclidean.rs:110`).
    ///
    /// #### Panics
    ///
    /// When `x² + y²`, the first sum of the squared distance `x² + y² + x·y` of an offset
    /// `(x, y)` of the search, leaves `i32`: from a search radius of 32,768
    /// (`range_squared ≥ 805,306,368`, far beyond gas, the cost being that of the `range` of that
    /// radius); or when a hex of the circle leaves `i32`. A hex outside the circle is never built.
    ///
    /// #### Deviations
    ///
    /// Counterpart, not a port: `hexx` takes an `f32` radius, this takes its square, an `i32`
    /// (plan §4.4, §14 #43). `hexx` searches `range(ceil(r) + floor(r / 6))`, a radius that is
    /// never smaller than the one used here, so the sets agree; a hex is added to the span only
    /// when it is in the circle, so a hex outside it does not panic on overflow.
    fn circular_range_squared(self: Hex, range_squared: i32) -> Span<Hex>;
}

pub impl HexRingsImpl of HexRingsTrait {
    fn custom_ring(self: Hex, range: u32, start_dir: EdgeDirection, clockwise: bool) -> Span<Hex> {
        let mut ring = array![];
        if range == 0 {
            ring.append(self);
            return ring.span();
        }
        let mut point = self.const_add(start_dir.mul_scalar(range.try_into().unwrap()));
        ring.append(point);
        // [Compute] the sixth direction is walked `range - 1` times: `hexx` stops at `6 * range`
        // hexes, one step before the start point
        let mut dir = if clockwise {
            start_dir.rotate_cw(4)
        } else {
            start_dir.rotate_cw(2)
        };
        let mut side: u8 = 0;
        while side != 6 {
            let step = dir.into_hex();
            let mut n = if side == 5 {
                range - 1
            } else {
                range
            };
            while n != 0 {
                point = point.const_add(step);
                ring.append(point);
                n -= 1;
            }
            dir = if clockwise {
                dir.counter_clockwise()
            } else {
                dir.clockwise()
            };
            side += 1;
        }
        ring.span()
    }

    fn ring(self: Hex, range: u32) -> Span<Hex> {
        self.custom_ring(range, Default::default(), false)
    }

    fn rings(self: Hex, range: Span<u32>) -> Span<Span<Hex>> {
        let mut rings = array![];
        for r in range {
            rings.append(self.ring(*r));
        }
        rings.span()
    }

    fn custom_rings(
        self: Hex, range: Span<u32>, start_dir: EdgeDirection, clockwise: bool,
    ) -> Span<Span<Hex>> {
        let mut rings = array![];
        for r in range {
            rings.append(self.custom_ring(*r, start_dir, clockwise));
        }
        rings.span()
    }

    fn custom_ring_edge(
        self: Hex, radius: u32, direction: VertexDirection, clockwise: bool,
    ) -> Span<Hex> {
        let (start_dir, end_dir) = HexRingsEdgeTrait::edge_dirs(direction, clockwise);
        let mut edge = array![];
        HexRingsEdgeTrait::append_edge(ref edge, self, radius, radius, start_dir, end_dir, 0);
        edge.span()
    }

    fn ring_edge(self: Hex, radius: u32, direction: VertexDirection) -> Span<Hex> {
        self.custom_ring_edge(radius, direction, false)
    }

    fn ring_edges(self: Hex, ranges: Span<u32>, direction: VertexDirection) -> Span<Span<Hex>> {
        self.custom_ring_edges(ranges, direction, false)
    }

    fn custom_ring_edges(
        self: Hex, ranges: Span<u32>, direction: VertexDirection, clockwise: bool,
    ) -> Span<Span<Hex>> {
        let (start_dir, end_dir) = HexRingsEdgeTrait::edge_dirs(direction, clockwise);
        let mut edges = array![];
        for r in ranges {
            let mut edge = array![];
            HexRingsEdgeTrait::append_edge(ref edge, self, *r, *r, start_dir, end_dir, 0);
            edges.append(edge.span());
        }
        edges.span()
    }

    fn custom_wedge(
        self: Hex, ranges: Span<u32>, direction: VertexDirection, clockwise: bool,
    ) -> Span<Hex> {
        let (start_dir, end_dir) = HexRingsEdgeTrait::edge_dirs(direction, clockwise);
        let mut wedge = array![];
        for r in ranges {
            HexRingsEdgeTrait::append_edge(ref wedge, self, *r, *r, start_dir, end_dir, 0);
        }
        wedge.span()
    }

    fn custom_wedge_to(self: Hex, rhs: Hex, clockwise: bool) -> Span<Hex> {
        let range = self.unsigned_distance_to(rhs);
        let direction = self.diagonal_way_to(rhs).unwrap();
        self.custom_full_wedge(range, direction, clockwise)
    }

    fn custom_full_wedge(
        self: Hex, range: u32, direction: VertexDirection, clockwise: bool,
    ) -> Span<Hex> {
        let _ = HexTrait::wedge_count(range);
        let (start_dir, end_dir) = HexRingsEdgeTrait::edge_dirs(direction, clockwise);
        let mut wedge = array![];
        let mut r: u32 = 0;
        loop {
            HexRingsEdgeTrait::append_edge(ref wedge, self, r, r, start_dir, end_dir, 0);
            if r == range {
                break;
            }
            r += 1;
        }
        wedge.span()
    }

    fn wedge(self: Hex, range: Span<u32>, direction: VertexDirection) -> Span<Hex> {
        self.custom_wedge(range, direction, false)
    }

    fn wedge_to(self: Hex, rhs: Hex) -> Span<Hex> {
        self.custom_wedge_to(rhs, false)
    }

    fn full_wedge(self: Hex, range: u32, direction: VertexDirection) -> Span<Hex> {
        self.custom_full_wedge(range, direction, false)
    }

    fn corner_wedge(self: Hex, range: Span<u32>, direction: EdgeDirection) -> Span<Hex> {
        let left = direction.rotate_ccw(2);
        let right = direction.rotate_cw(2);
        let mut wedge = array![];
        for r in range {
            HexRingsEdgeTrait::append_edge(ref wedge, self, *r, *r / 2, direction, left, 0);
            HexRingsEdgeTrait::append_edge(ref wedge, self, *r, *r / 2, direction, right, 1);
        }
        wedge.span()
    }

    fn corner_wedge_to(self: Hex, rhs: Hex) -> Span<Hex> {
        let range = self.unsigned_distance_to(rhs);
        let direction = self.way_to(rhs).unwrap();
        let mut radii = array![];
        let mut r: u32 = 0;
        loop {
            radii.append(r);
            if r == range {
                break;
            }
            r += 1;
        }
        self.corner_wedge(radii.span(), direction)
    }

    fn cached_custom_ring_edges(
        self: Hex, range: u32, direction: VertexDirection, clockwise: bool,
    ) -> Span<Span<Hex>> {
        let mut edges = array![];
        let mut r: u32 = 0;
        while r != range {
            edges.append(self.custom_ring_edge(r, direction, clockwise));
            r += 1;
        }
        edges.span()
    }

    fn cached_ring_edges(self: Hex, range: u32, direction: VertexDirection) -> Span<Span<Hex>> {
        self.cached_custom_ring_edges(range, direction, false)
    }

    fn cached_rings(self: Hex, range: u32) -> Span<Span<Hex>> {
        self.cached_custom_rings(range, Default::default(), false)
    }

    fn cached_custom_rings(
        self: Hex, range: u32, start_dir: EdgeDirection, clockwise: bool,
    ) -> Span<Span<Hex>> {
        let mut rings = array![];
        let mut r: u32 = 0;
        while r != range {
            rings.append(self.custom_ring(r, start_dir, clockwise));
            r += 1;
        }
        rings.span()
    }

    fn custom_spiral_range(
        self: Hex, range: Span<u32>, start_dir: EdgeDirection, clockwise: bool,
    ) -> Span<Hex> {
        let mut spiral = array![];
        for r in range {
            spiral.append_span(self.custom_ring(*r, start_dir, clockwise));
        }
        spiral.span()
    }

    fn spiral_range(self: Hex, range: Span<u32>) -> Span<Hex> {
        self.custom_spiral_range(range, Default::default(), false)
    }

    fn circular_range_squared(self: Hex, range_squared: i32) -> Span<Hex> {
        let mut hexes = array![];
        if range_squared < 0 {
            return hexes.span();
        }
        let radius: i32 = HexRingsCircleTrait::radius(range_squared.try_into().unwrap())
            .try_into()
            .unwrap();
        let mut x = -radius;
        while x <= radius {
            let mut y = if x < 0 {
                -radius - x
            } else {
                -radius
            };
            let y_max = if x > 0 {
                radius - x
            } else {
                radius
            };
            while y <= y_max {
                if x * x + y * y + x * y <= range_squared {
                    hexes.append(Hex { x: self.x + x, y: self.y + y });
                }
                y += 1;
            }
            x += 1;
        }
        hexes.span()
    }
}

/// The edge builder and the directions of the ring edges: private.
#[generate_trait]
impl HexRingsEdgeImpl of HexRingsEdgeTrait {
    /// `[start_dir, end_dir]` of `hexx`'s `__vertex_dir_to_edge_dir` (`src/hex/rings.rs:124`):
    /// the edge direction counter-clockwise of the vertex and the one two steps clockwise of it
    /// when `clockwise`, else the one clockwise of it and the one two steps counter-clockwise.
    #[inline]
    fn edge_dirs(direction: VertexDirection, clockwise: bool) -> (EdgeDirection, EdgeDirection) {
        if clockwise {
            let dir = direction.direction_ccw();
            (dir, dir.rotate_cw(2))
        } else {
            let dir = direction.direction_cw();
            (dir, dir.rotate_ccw(2))
        }
    }

    /// Appends to `out` the hexes `p + end_dir * i` for `i` in `skip..=len`, where `p = center +
    /// start_dir * dist` (`__ring_edge`, `src/hex/rings.rs:137`, and its `skip(1)`): each is the
    /// previous plus `end_dir`, which leaves `i32` only where the last does.
    fn append_edge(
        ref out: Array<Hex>,
        center: Hex,
        dist: u32,
        len: u32,
        start_dir: EdgeDirection,
        end_dir: EdgeDirection,
        skip: u32,
    ) {
        let mut point = center.const_add(start_dir.mul_scalar(dist.try_into().unwrap()));
        let step = end_dir.into_hex();
        let mut i: u32 = 0;
        loop {
            if i >= skip {
                out.append(point);
            }
            if i == len {
                break;
            }
            point = point.const_add(step);
            i += 1;
        }
    }
}

/// The search radius of `circular_range_squared`: private.
#[generate_trait]
impl HexRingsCircleImpl of HexRingsCircleTrait {
    /// The largest `n` with `3 n² <= 4 s`: `floor(sqrt(floor(4 s / 3)))`. A hex at hex distance
    /// `n` is at squared Euclidean distance at least `3 n² / 4`.
    fn radius(s: u32) -> u32 {
        let four_thirds: u64 = 4 * s.into() / 3;
        let n: u32 = four_thirds.sqrt();
        n
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::direction::edge_direction::EdgeDirectionTrait;
    use crate::direction::vertex_direction::VertexDirectionTrait;
    use crate::direction::way::DirectionWayTrait;
    use crate::hex::euclidean::HexEuclideanTrait;
    use crate::hex::{Hex, HexTrait};
    use super::{HexRingsCircleTrait, HexRingsTrait};

    /// The plain definitions the tests compare with.
    #[generate_trait]
    impl OracleImpl of OracleTrait {
        fn distinct(hexes: Span<Hex>) -> bool {
            let mut ok = true;
            let mut i = 0;
            while i < hexes.len() {
                let mut j = i + 1;
                while j < hexes.len() {
                    if *hexes.at(i) == *hexes.at(j) {
                        ok = false;
                    }
                    j += 1;
                }
                i += 1;
            }
            ok
        }

        fn contains(hexes: Span<Hex>, hex: Hex) -> bool {
            let mut found = false;
            for h in hexes {
                if *h == hex {
                    found = true;
                }
            }
            found
        }

        /// The radii `0..=r`.
        fn radii(r: u32) -> Span<u32> {
            let mut radii = array![];
            let mut n = 0;
            while n <= r {
                radii.append(n);
                n += 1;
            }
            radii.span()
        }

        /// The smallest `r` with `r² >= s`.
        fn ceil_root(s: i32) -> u32 {
            let mut r: u32 = 0;
            while (r * r).try_into().unwrap() < s {
                r += 1;
            }
            r
        }

        /// The definition of `circular_range_squared`: the hexes of `range(r + r / 6 + 1)` (`r`
        /// the ceiling of the root) at squared Euclidean distance at most `s`, in `range`'s order.
        fn circle(center: Hex, s: i32) -> Span<Hex> {
            let r = Self::ceil_root(s);
            let mut hexes = array![];
            for h in center.range(r + r / 6 + 1) {
                if center.squared_euclidean_distance_to(*h) <= s {
                    hexes.append(*h);
                }
            }
            hexes.span()
        }
    }

    /// The ring of radius 1 starting from the default direction is the neighbours, in order.
    #[test]
    #[available_gas(l2_gas: 104664)]
    fn test_ring_one_is_the_neighbours() {
        let center = HexTrait::new(3, -6);
        let ring = center.ring(1);
        let neighbors = center.all_neighbors();
        assert!(ring == neighbors.span());
        assert!(center.ring(0) == array![center].span());
    }

    /// The oracle of `ring`: the hexes at distance `r`, as a set (`6 r` distinct hexes, all at
    /// distance `r`).
    #[test]
    #[available_gas(l2_gas: 41759193)]
    fn test_ring_oracle() {
        let center = HexTrait::new(3, -6);
        let mut r = 0;
        while r <= 10 {
            let ring = center.ring(r);
            assert!(ring.len() == HexTrait::ring_count(r));
            assert!(OracleTrait::distinct(ring));
            for h in ring {
                assert!(center.unsigned_distance_to(*h) == r);
            }
            r += 1;
        }
    }

    /// The ring of every start direction and sense is the same set, and its first hex is
    /// `center + start_dir * range`.
    #[test]
    #[available_gas(l2_gas: 22422099)]
    fn test_custom_ring_is_the_same_set() {
        let center = HexTrait::new(-5, 4);
        let base = center.ring(3);
        for dir in EdgeDirectionTrait::iter() {
            for clockwise in array![false, true] {
                let ring = center.custom_ring(3, *dir, clockwise);
                assert!(*ring.at(0) == center.const_add(dir.into_hex().mul_scalar(3)));
                assert!(ring.len() == base.len());
                assert!(OracleTrait::distinct(ring));
                for h in ring {
                    assert!(OracleTrait::contains(base, *h));
                }
            }
        }
    }

    /// The oracle of `spiral_range`: the rings `0..=r` as a set are `range(r)`.
    #[test]
    #[available_gas(l2_gas: 48123002)]
    fn test_spiral_range_oracle() {
        let center = HexTrait::new(-5, 4);
        for r in array![0_u32, 1, 3, 6] {
            let spiral = center.spiral_range(OracleTrait::radii(r));
            assert!(spiral.len() == HexTrait::range_count(r));
            assert!(OracleTrait::distinct(spiral));
            for h in spiral {
                assert!(center.unsigned_distance_to(*h) <= r);
            }
        }
    }

    /// The oracle of the wedges: the hexes of `range(r)` whose `diagonal_way_to` from the centre
    /// contains the direction, and the centre.
    #[test]
    #[available_gas(l2_gas: 104664126)]
    fn test_full_wedge_oracle() {
        let center = HexTrait::new(2, -3);
        for vertex in VertexDirectionTrait::iter() {
            let mut r = 0;
            while r <= 6 {
                let wedge = center.full_wedge(r, *vertex);
                assert!(wedge.len() == HexTrait::wedge_count(r));
                assert!(OracleTrait::distinct(wedge));
                let mut expected = 1;
                for h in center.range(r) {
                    if *h != center && center.diagonal_way_to(*h).contains(vertex) {
                        expected += 1;
                        assert!(OracleTrait::contains(wedge, *h));
                    }
                }
                assert!(expected == wedge.len());
                assert!(OracleTrait::contains(wedge, center));
                r += 1;
            }
        }
    }

    /// The oracle of `circular_range_squared` for `s` in `0..=40`: the per-hex filter, in
    /// `range`'s order; and the empty span for a negative one.
    #[test]
    #[available_gas(l2_gas: 124445643)]
    fn test_circular_range_squared_oracle() {
        let center = HexTrait::new(12, -7);
        let mut s = 0;
        while s <= 40 {
            assert!(center.circular_range_squared(s) == OracleTrait::circle(center, s));
            s += 1;
        }
        assert!(center.circular_range_squared(-1).is_empty());
        assert!(center.circular_range_squared(-2147483648).is_empty());
        assert!(center.circular_range_squared(0) == array![center].span());
        assert!(center.circular_range_squared(1).len() == 7);
        assert!(center.circular_range_squared(3).len() == 13);
    }

    /// A hex at hex distance `n` is at squared Euclidean distance at least `3 n² / 4`, checked
    /// on every ring `0..=51`: the radius bound of `circular_range_squared` stands on it.
    #[test]
    #[available_gas(l2_gas: 99693038)]
    fn test_circular_range_squared_inradius() {
        let mut n = 0;
        while n <= 51 {
            for h in HexTrait::ORIGIN.ring(n) {
                assert!(4 * h.squared_euclidean_length() >= 3 * (n * n).try_into().unwrap());
            }
            n += 1;
        }
    }

    /// The radius is the largest `n` with `3 n² <= 4 s`, for every `s` in `0..=1700`: no hex of
    /// a ring beyond it is at squared Euclidean distance `s` or less (with the inradius test).
    #[test]
    #[available_gas(l2_gas: 16190171)]
    fn test_circular_range_squared_radius_bound() {
        let mut s: u32 = 0;
        while s <= 1700 {
            let n = HexRingsCircleTrait::radius(s);
            assert!(3 * n * n <= 4 * s);
            assert!(3 * (n + 1) * (n + 1) > 4 * s);
            s += 1;
        }
    }

    #[test]
    #[available_gas(l2_gas: 7991)]
    #[should_panic]
    fn test_custom_ring_range_leaves_i32() {
        let _ = HexTrait::new(0, 0).custom_ring(2147483648, Default::default(), false);
    }

    // Benchmarks of M2-T4 (LIB-06), 10 repetitions per test, one call per repetition: per call =
    // (test − baseline) / 10. Targets (`L`, `U = ceil(1.25 L)`, the brief's table, from 7,358 per
    // element of a span built by a loop, 1,030 per `i32` operation and 8,080 per
    // `squared_euclidean_distance_to`), written before the first measurement:
    //
    // | function | case | `L` | `U` |
    // |---|---|---|---|
    // | `ring`, `custom_ring` | radius 6 (36 hexes) | 264,888 | 331,110 |
    // | `full_wedge` | radius 6 (28 hexes) | 206,024 | 257,530 |
    // | `spiral_range`, `cached_rings` | radii `0..=6` (127 hexes) | 934,466 | 1,168,083 |
    // | `circular_range_squared` | `range_squared = 36` (169 hexes) | 2,783,092 | 3,478,865 |
    //
    // Items the brief does not list, with the same rule (7,358 per element, one `u32` operation
    // 1,030 per call): `ring_edge`, `custom_ring_edge` at radius 6 (7 hexes) `L` = 51,506, `U` =
    // 64,383; `corner_wedge` at radii `0..=6` (25 hexes, 14 edges) `L` = 183,950, `U` = 229,938.
    // Measured per call (CI, `gas/hexx.snap`): `corner_wedge` 279,227, between `U` and `2U`: each
    // of the 14 edges pays its own start point (`mul_scalar`, `try_into`, `into_hex`), about 6,800
    // more than a hex of a loop.

    const REPS: u8 = 10;

    #[test]
    #[available_gas(l2_gas: 50946)]
    fn bench_hex_rings_baseline() {
        let mut acc: i32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            acc += a.x + a.y;
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 1876077)]
    fn bench_hex_ring() {
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            acc += a.ring(6).len();
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 1898127)]
    fn bench_hex_custom_ring() {
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            acc += a.custom_ring(6, EdgeDirectionTrait::X, true).len();
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 458472)]
    fn bench_hex_ring_edge() {
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            acc += a.ring_edge(6, VertexDirectionTrait::FLAT_RIGHT).len();
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 2068647)]
    fn bench_hex_full_wedge() {
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            acc += a.full_wedge(6, VertexDirectionTrait::FLAT_RIGHT).len();
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 2982830)]
    fn bench_hex_corner_wedge() {
        let radii = OracleTrait::radii(6);
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            acc += a.corner_wedge(radii, EdgeDirectionTrait::X).len();
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 10867595)]
    fn bench_hex_spiral_range() {
        let radii = OracleTrait::radii(6);
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            acc += a.spiral_range(radii).len();
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 7943397)]
    fn bench_hex_cached_rings() {
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            acc += a.cached_rings(7).len();
        }
        assert!(acc != 1);
    }

    #[test]
    #[available_gas(l2_gas: 12602562)]
    fn bench_hex_circular_range_squared() {
        let mut acc: u32 = 0;
        let mut n = REPS;
        while n != 0 {
            n -= 1;
            let a = HexTrait::new(-1 - n.into(), 2 + n.into());
            acc += a.circular_range_squared(36).len();
        }
        assert!(acc != 1);
    }
}
