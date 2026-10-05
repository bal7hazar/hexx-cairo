//! `DirectionWay`: the result of `Hex::way_to` and `Hex::diagonal_way_to` (M2-T2), the mirror of
//! `hexx::DirectionWay` (`src/direction/way.rs`): one direction, or a tie between two adjacent
//! ones.

use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
use crate::direction::vertex_direction::{VertexDirection, VertexDirectionTrait};

/// A direction, or a tie between two adjacent directions.
///
/// Mirrors `hexx::DirectionWay` (`src/direction/way.rs:30`), an `enum DirectionWay<T>`.
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// `Tie([T; 2])` is `Tie: [T; 2]` (a fixed-size array, plan §3.2). `Drop` is derived, and
/// `Copy` (when `T: Copy`) and `Debug`: `hexx`'s `DirectionWay` derives `Debug` only and is neither
/// `Clone` nor `Copy`. Cairo needs `Drop`, and `Copy` lets a way be read more than once. There is
/// no `PartialEq` between a way and its direction: `PartialEq` is homogeneous in Cairo, and
/// `hexx`'s `PartialEq<T> for DirectionWay<T>` is `contains`
/// (`src/direction/way.rs:42`), which `DirectionWayTrait::contains` is.
///
/// `Debug` is Cairo's derived one, which differs from `hexx`'s derived one
/// (`src/direction/way.rs:29`) by the type prefix of the variant: this port prints
/// `DirectionWay::Single(EdgeDirection { index: 0, x: 1, y: 0, z: -1 })` and
/// `DirectionWay::Tie([…, …])` where `hexx` prints
/// `Single(EdgeDirection { index: 0, x: 1, y: 0, z: -1 })` and `Tie([…, …])`; the directions
/// inside print as in `hexx`.
#[derive(Copy, Drop, Debug)]
pub enum DirectionWay<T> {
    Single: T,
    Tie: [T; 2],
}

/// The items of `impl<T> DirectionWay<T>` (`src/direction/way.rs:48`).
pub trait DirectionWayTrait<T> {
    /// The first direction of the way: the direction itself for `Single`, the first of the two
    /// for `Tie`.
    ///
    /// Mirrors `DirectionWay::unwrap` (`src/direction/way.rs:53`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// None.
    fn unwrap<+Drop<T>>(self: DirectionWay<T>) -> T;

    /// `true` when `dir` is the direction of the way, or one of the two of a tie. The body of
    /// `hexx`'s `PartialEq<T> for DirectionWay<T>`.
    ///
    /// Mirrors `DirectionWay::contains` (`src/direction/way.rs:62`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// Requires `T: Copy + Drop + PartialEq` where `hexx` requires `T: PartialEq` only: the
    /// directions are copied out of the snapshot to be compared. Both direction types are `Copy`
    /// and `Drop`.
    fn contains<+Copy<T>, +Drop<T>, +PartialEq<T>>(self: @DirectionWay<T>, dir: @T) -> bool;

    /// Applies `func` to the direction, or to both directions of a tie, first then second.
    ///
    /// Mirrors `DirectionWay::map` (`src/direction/way.rs:75`).
    ///
    /// #### Panics
    ///
    /// None.
    ///
    /// #### Deviations
    ///
    /// `func` is a closure bound by `Fn`, where `hexx`'s bound is `FnMut`
    /// (`mut func: impl FnMut(T) -> U`, `src/direction/way.rs:75`). Cairo's corelib has `FnOnce`
    /// and `Fn` but no `FnMut`, and `FnOnce` (the bound of corelib's `Option::map`) cannot serve a
    /// tie, which calls `func` twice. So a closure that `hexx` accepts only as `FnMut`, one that
    /// changes its captured state from one call to the next, has no counterpart here: each call of
    /// a tie sees the same captures. The bound is spelled `impl Func: Fn<F, (T,)>`, with
    /// `Func::Output` for the result: the constraint form `Fn<F, (T,)>[Output: U]` needs the
    /// experimental feature `associated_item_constraints`, which the manifest of this package does
    /// not enable.
    ///
    /// **Cost to the consumer: a closure in a library function puts a closure type into every
    /// consumer class that calls `DirectionWay::map`, so the class hash of such a class depends on
    /// the build path until the upstream compiler issue 10359 ships in a Scarb** (the code and its
    /// gas do not depend on it). A class that does not call `map` is unaffected.
    fn map<F, +Drop<F>, +Drop<T>, impl Func: core::ops::Fn<F, (T,)>, +Drop<Func::Output>>(
        self: DirectionWay<T>, func: F,
    ) -> DirectionWay<Func::Output>;
}

pub impl DirectionWayImpl<T> of DirectionWayTrait<T> {
    #[inline]
    fn unwrap<+Drop<T>>(self: DirectionWay<T>) -> T {
        match self {
            DirectionWay::Single(v) => v,
            DirectionWay::Tie(pair) => {
                let [v, _] = pair;
                v
            },
        }
    }

    #[inline]
    fn contains<+Copy<T>, +Drop<T>, +PartialEq<T>>(self: @DirectionWay<T>, dir: @T) -> bool {
        match *self {
            DirectionWay::Single(d) => d == *dir,
            DirectionWay::Tie(pair) => {
                let [a, b] = pair;
                a == *dir || b == *dir
            },
        }
    }

    #[inline]
    fn map<F, +Drop<F>, +Drop<T>, impl Func: core::ops::Fn<F, (T,)>, +Drop<Func::Output>>(
        self: DirectionWay<T>, func: F,
    ) -> DirectionWay<Func::Output> {
        match self {
            DirectionWay::Single(v) => DirectionWay::Single(func(v)),
            DirectionWay::Tie(pair) => {
                let [a, b] = pair;
                DirectionWay::Tie([func(a), func(b)])
            },
        }
    }
}

/// `From<T> for DirectionWay<T>` (`src/direction/way.rs:95`): a single direction.
///
/// Mirrors `impl<T> From<T> for DirectionWay<T>`: Cairo writes it `Into<T, DirectionWay<T>>`.
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The impl is `Into`, not `From`: Cairo's `From` does not exist in the corelib, `Into` is the
/// conversion trait.
pub impl DirectionWayFromSingle<T> of Into<T, DirectionWay<T>> {
    #[inline]
    fn into(self: T) -> DirectionWay<T> {
        DirectionWay::Single(self)
    }
}

/// `From<[T; 2]> for DirectionWay<T>` (`src/direction/way.rs:102`): a tie.
///
/// Mirrors `impl<T> From<[T; 2]> for DirectionWay<T>`: Cairo writes it
/// `Into<[T; 2], DirectionWay<T>>`.
///
/// #### Panics
///
/// None.
///
/// #### Deviations
///
/// The impl is `Into`, not `From`: Cairo's `From` does not exist in the corelib, `Into` is the
/// conversion trait.
pub impl DirectionWayFromTie<T> of Into<[T; 2], DirectionWay<T>> {
    #[inline]
    fn into(self: [T; 2]) -> DirectionWay<T> {
        DirectionWay::Tie(self)
    }
}

/// `hexx`'s private trait `Way` (`src/direction/way.rs:37`): what `way_from` needs of a direction
/// type. Crate-private, outside the parity table (the trait is not public in `hexx`).
pub(crate) trait WayTrait<T> {
    fn neg(self: T) -> T;
    fn ccw(self: T) -> T;
    fn cw(self: T) -> T;
}

impl EdgeDirectionWay of WayTrait<EdgeDirection> {
    #[inline]
    fn neg(self: EdgeDirection) -> EdgeDirection {
        self.const_neg()
    }

    #[inline]
    fn ccw(self: EdgeDirection) -> EdgeDirection {
        self.counter_clockwise()
    }

    #[inline]
    fn cw(self: EdgeDirection) -> EdgeDirection {
        self.clockwise()
    }
}

impl VertexDirectionWay of WayTrait<VertexDirection> {
    #[inline]
    fn neg(self: VertexDirection) -> VertexDirection {
        self.const_neg()
    }

    #[inline]
    fn ccw(self: VertexDirection) -> VertexDirection {
        self.counter_clockwise()
    }

    #[inline]
    fn cw(self: VertexDirection) -> VertexDirection {
        self.clockwise()
    }
}

/// `DirectionWay::way_from` (`src/direction/way.rs:85`), `pub(crate)` in `hexx`: what `Hex::way_to`
/// and `Hex::diagonal_way_to` (M2-T2) call. Crate-private here too, outside the parity table and
/// the public documentation template. `dir` is negated when `is_neg`; then a tie with its
/// counter-clockwise neighbour when `eq_left`, else with its clockwise neighbour when `eq_right`,
/// else the single direction.
#[generate_trait]
pub(crate) impl DirectionWayFromImpl<
    T, +Copy<T>, +Drop<T>, +WayTrait<T>,
> of DirectionWayFromTrait<T> {
    #[inline]
    fn way_from(is_neg: bool, eq_left: bool, eq_right: bool, dir: T) -> DirectionWay<T> {
        let dir = if is_neg {
            WayTrait::neg(dir)
        } else {
            dir
        };
        if eq_left {
            DirectionWay::Tie([dir, WayTrait::ccw(dir)])
        } else if eq_right {
            DirectionWay::Tie([dir, WayTrait::cw(dir)])
        } else {
            DirectionWay::Single(dir)
        }
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use crate::direction::edge_direction::{EdgeDirection, EdgeDirectionTrait};
    use crate::direction::vertex_direction::{VertexDirection, VertexDirectionTrait};
    use super::{DirectionWay, DirectionWayFromTrait, DirectionWayTrait};

    #[generate_trait]
    impl Shape of ShapeTrait {
        /// `(kind, first, second)` of a way of indices: kind 0 for `Single`, 1 for `Tie`.
        fn shape(way: DirectionWay<u8>) -> (u8, u8, u8) {
            match way {
                DirectionWay::Single(v) => (0, v, 0),
                DirectionWay::Tie(pair) => {
                    let [a, b] = pair;
                    (1, a, b)
                },
            }
        }
    }

    /// The oracle of `way_from` (`src/direction/way.rs:85`), on its whole domain (2 × 2 × 2 flags
    /// × 6 directions, both types), written plainly on indices: `dir` negated is `(i + 3) % 6`;
    /// a tie with `(i + 5) % 6` when `eq_left`, else with `(i + 1) % 6` when `eq_right`.
    /// `way_from` is `pub(crate)` in `hexx`: it has no vector from the crate, `way_to` (M2-T2) is
    /// its end-to-end test.
    #[test]
    #[available_gas(l2_gas: 864014)]
    fn test_direction_way_from_oracle() {
        let edges = EdgeDirectionTrait::iter();
        let vertices = VertexDirectionTrait::iter();
        let mut mask: u8 = 0;
        while mask < 8 {
            let is_neg = mask % 2 == 1;
            let eq_left = (mask / 2) % 2 == 1;
            let eq_right = mask / 4 == 1;
            let mut i: u8 = 0;
            while i < 6 {
                let base = if is_neg {
                    (i + 3) % 6
                } else {
                    i
                };
                let expected = if eq_left {
                    (1, base, (base + 5) % 6)
                } else if eq_right {
                    (1, base, (base + 1) % 6)
                } else {
                    (0, base, 0)
                };
                let e = DirectionWayFromTrait::way_from(
                    is_neg, eq_left, eq_right, *edges.at(i.into()),
                );
                assert(ShapeTrait::shape(e.map(|d: EdgeDirection| d.index())) == expected, 'edge');
                let v = DirectionWayFromTrait::way_from(
                    is_neg, eq_left, eq_right, *vertices.at(i.into()),
                );
                assert(
                    ShapeTrait::shape(v.map(|d: VertexDirection| d.index())) == expected, 'vertex',
                );
                i += 1;
            }
            mask += 1;
        }
    }

    /// The two `Into` impls build the two variants.
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_direction_way_into() {
        let single: DirectionWay<EdgeDirection> = EdgeDirectionTrait::Y.into();
        let tie: DirectionWay<EdgeDirection> = [EdgeDirectionTrait::Y, EdgeDirectionTrait::NEG_Y]
            .into();
        assert(ShapeTrait::shape(single.map(|d: EdgeDirection| d.index())) == (0, 1, 0), 'single');
        assert(ShapeTrait::shape(tie.map(|d: EdgeDirection| d.index())) == (1, 1, 4), 'tie');
    }

    /// The printed form of the two variants, as the `#### Deviations` of `DirectionWay` states it:
    /// the type prefix of the variant, the directions as in `hexx`.
    #[test]
    #[available_gas(l2_gas: 5000000)]
    fn test_direction_way_debug() {
        let single: DirectionWay<EdgeDirection> = EdgeDirectionTrait::X.into();
        assert!(
            format!(
                "{:?}", single,
            ) == "DirectionWay::Single(EdgeDirection { index: 0, x: 1, y: 0, z: -1 })",
        );
        let tie: DirectionWay<EdgeDirection> = [EdgeDirectionTrait::X, EdgeDirectionTrait::Y]
            .into();
        assert!(
            format!(
                "{:?}", tie,
            ) == "DirectionWay::Tie([EdgeDirection { index: 0, x: 1, y: 0, z: -1 }, EdgeDirection { index: 1, x: 0, y: 1, z: -1 }])",
        );
    }

    /// A closure that captures: `map` is `Fn`, called once for `Single` and twice for `Tie`.
    #[test]
    #[available_gas(l2_gas: 6311)]
    fn test_direction_way_map_captures() {
        let offset: u8 = 10;
        let tie: DirectionWay<EdgeDirection> = [EdgeDirectionTrait::X, EdgeDirectionTrait::Y]
            .into();
        let shifted = tie.map(|d: EdgeDirection| d.index() + offset);
        assert(ShapeTrait::shape(shifted) == (1, 10, 11), 'tie');
        let single: DirectionWay<VertexDirection> = VertexDirectionTrait::X_Y.into();
        let shifted = single.map(|d: VertexDirection| d.index() + offset);
        assert(ShapeTrait::shape(shifted) == (0, 11, 0), 'single');
    }

    // Benchmarks of M2-T1 (LIB-06), 17 repetitions of the six directions per test (102 calls),
    // per call = (test − `bench_direction_way_baseline`) / 102. Targets (`L`, `U = ceil(1.25
    // L)`), written before the first measurement:
    //
    // | function | `L` (derivation) | `U` |
    // |---|---|---|
    // | `contains`, `Tie`, absent | 2,060 (two comparisons, 1,030 each) | 2,575 |
    // | `way_from`, `Tie` | 4,683 (`const_neg` 1,785 + `counter_clockwise` 1,868 + 1,030) | 5,854 |
    // | `unwrap`, `Tie` | 1,030 (one array destructuring and a move) | 1,288 |
    // | `map`, `Tie`, closure of one operation | 2,060 (two closure calls) | 2,575 |

    #[test]
    #[available_gas(l2_gas: 538390)]
    fn bench_direction_way_baseline() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                let way: DirectionWay<EdgeDirection> = DirectionWay::Tie([d, d]);
                acc = acc ^ d.index() ^ offset;
                let _ = way;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 941943)]
    fn bench_direction_way_contains() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                let way: DirectionWay<EdgeDirection> = DirectionWay::Tie([d, d]);
                // Absent: the third direction away from `d`.
                let absent = d.rotate_cw(3);
                let found = way.contains(@absent);
                acc = acc ^ d.index() ^ offset ^ if found {
                    1
                } else {
                    0
                };
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 824133)]
    fn bench_direction_way_baseline_absent() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                let way: DirectionWay<EdgeDirection> = DirectionWay::Tie([d, d]);
                let absent = d.rotate_cw(3);
                acc = acc ^ d.index() ^ offset ^ absent.index();
                let _ = way;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 938623)]
    fn bench_direction_way_from() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                // `is_neg` and `eq_left`: the longest branch, a negation and a tie.
                let way = DirectionWayFromTrait::way_from(offset != 0, offset != 1, false, d);
                acc = acc ^ way.unwrap().index();
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 714124)]
    fn bench_direction_way_from_baseline() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                let way: DirectionWay<EdgeDirection> = DirectionWay::Tie([d, d]);
                acc = acc
                    ^ way.unwrap().index()
                    ^ if offset != 0 {
                        1
                    } else {
                        0
                    }
                    ^ if offset != 1 {
                        1
                    } else {
                        0
                    };
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 538390)]
    fn bench_direction_way_unwrap() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                let way: DirectionWay<EdgeDirection> = DirectionWay::Tie([d, d]);
                acc = acc ^ way.unwrap().index() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }

    #[test]
    #[available_gas(l2_gas: 538390)]
    fn bench_direction_way_map() {
        let mut acc: u8 = 0;
        let mut rep: u8 = 0;
        while rep != 17 {
            let offset: u8 = 255 - rep;
            let mut all = EdgeDirectionTrait::iter();
            while let Some(d) = all.pop_front() {
                let d = *d;
                let way: DirectionWay<EdgeDirection> = DirectionWay::Tie([d, d]);
                let mapped = way.map(|d: EdgeDirection| d.index());
                acc = acc ^ mapped.unwrap() ^ offset;
            }
            rep += 1;
        }
        assert!(acc != 200);
    }
}
