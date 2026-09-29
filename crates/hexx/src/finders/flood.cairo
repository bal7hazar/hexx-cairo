//! N-8: the flood of the tick (plan §6.9, decided by L-G1 point 5 and D-127).
//!
//! One flood per tick, shared by every walker: from the adventurer's tile, on the board without
//! the obstacles frozen at the start of the tick, the layers of path distance up to a `depth`.
//! `Bfs::flood` computes it with the layer step of the engine (`BfsInternal::layer`, the hex
//! dilation of `Bfs`), and stores every layer.
//!
//! The layers hold interior tiles only, except layer 0, which is the source even when it is an
//! open edge tile (D-32, plan §14): an edge source is seeded by its open interior neighbours, as
//! `Bfs::search` does, and an open edge tile other than the source is never in a layer.
//!
//! Each walker then selects its step from the layers (M1-T9b): `next_step` towards the source,
//! `next_step_away` away from it, and `distance`, the layer of a tile or the one inferred from its
//! neighbours (D-26). The caller filters the candidates by `blocked`, the current occupancy, and
//! runs the walkers in ascending id order (L-G1 point 5): the flood is not recomputed. Every tie
//! is broken by the lowest tile index. A walker is any tile of the board, the ring included; a
//! step is the source or an interior tile, never an open edge tile other than the source (D-32).

// Internal imports

use hexx::board::bits::{Bits, TWO_POW_128};
use hexx::board::layout::Dilation;
use hexx::finders::bfs::{ArrayStore, Back, BfsInternal, Endpoint};

// Constants

/// 1/2 in the field.
const INV_2: felt252 = 0x400000000000008800000000000000000000000000000000000000000000001;

/// Errors module.
pub mod errors {
    /// The error of `Bfs` for a start that cannot be walked on (plan §6.9).
    pub const FLOOD_POSITION_NOT_WALKABLE: felt252 = 'Bfs: position not walkable';
}

/// The layers of path distance from a source, up to a depth (`Bfs::flood`).
#[derive(Drop)]
pub struct Flood {
    /// The width of the board.
    pub(crate) width: u8,
    /// The height of the board.
    pub(crate) height: u8,
    /// The `depth` requested from `Bfs::flood`: a walker whose inferred distance is greater is
    /// not reached and gets no step (D-25).
    pub(crate) cap: u8,
    /// `layers[k]`: the tiles at path distance `k` from the source, every one non-empty;
    /// `layers[0]` is the source.
    pub(crate) layers: Span<u256>,
}

#[generate_trait]
pub impl FloodImpl of FloodTrait {
    /// The number of layers computed after layer 0: the smaller of the `depth` of the flood and
    /// the largest path distance from the source.
    /// # Arguments
    /// * `self` - The flood
    /// # Returns
    /// * The largest distance held by a layer
    #[inline]
    fn depth(self: @Flood) -> u8 {
        // At most 1 + (W − 2)(H − 2) layers, below 256
        ((*self.layers).len() - 1).try_into().unwrap()
    }

    /// The step of a walker towards the source: its neighbour in the least layer that touches
    /// its neighbourhood, lowest index first, among those not `blocked`; when all of them are
    /// blocked, its free neighbour in the next layer, lowest index first (the walker's own layer,
    /// L-G1 point 5). A walker whose inferred distance (`distance`) is greater than the `depth`
    /// requested from `Bfs::flood` was not reached and gets no step (D-25): the least layer it
    /// touches is then the last one, at that depth, decided in the same scan.
    /// # Arguments
    /// * `self` - The flood
    /// * `position` - The walker, any tile of the board (the ring included)
    /// * `blocked` - The tiles it may not step on: the current occupancy
    /// # Returns
    /// * The step, `None` outside the board, when the walker is beyond the requested `depth`
    ///   (its inferred distance is greater, or no neighbour is in a layer) or cut off, or when
    ///   every candidate is blocked
    fn next_step(self: @Flood, position: u8, blocked: felt252) -> Option<u8> {
        let (back, walker) = FloodInternal::walker(self, position)?;
        let around: u256 = walker.around.into();
        let mut layers = *self.layers;
        // [Compute] The neighbours in the least layer that touches the neighbourhood
        let hit = FloodInternal::first(ref layers, around)?;
        // [Check] Reached: the least layer is not the last one at the cap (D-25), or the walker
        // is the source
        if layers.len() == 0
            && FloodInternal::capped(self)
            && !FloodInternal::source(self, @walker) {
            return Option::None;
        }
        // [Compute] The free ones, else the free neighbours in the next layer
        let blocked: u256 = blocked.into();
        let free = FloodInternal::without(hit, blocked);
        let free = if free.low != 0 || free.high != 0 {
            free
        } else {
            let next = *layers.pop_front()?;
            let free = FloodInternal::without(Bits::and(next, around), blocked);
            if free.low == 0 && free.high == 0 {
                return Option::None;
            }
            free
        };
        Option::Some(FloodInternal::lowest(back, @walker, free))
    }

    /// The step of a walker away from the source (kiting): its free neighbour in the greatest
    /// layer, lowest index first. A walker whose inferred distance is greater than the `depth`
    /// requested from `Bfs::flood` was not reached and gets no step (D-25), as for `next_step`.
    /// # Arguments
    /// * `self` - The flood
    /// * `position` - The walker, any tile of the board (the ring included)
    /// * `blocked` - The tiles it may not step on: the current occupancy
    /// # Returns
    /// * The step, `None` outside the board, when the walker is beyond the requested `depth` or
    ///   when no free neighbour is in a layer
    fn next_step_away(self: @Flood, position: u8, blocked: felt252) -> Option<u8> {
        let (back, walker) = FloodInternal::walker(self, position)?;
        let around: u256 = walker.around.into();
        let blocked: u256 = blocked.into();
        let free = FloodInternal::without(around, blocked);
        if free.low == 0 && free.high == 0 {
            return Option::None;
        }
        let mut layers = *self.layers;
        // [Check] At the cap, a free neighbour in the last layer is the step only when the walker
        // is reached (D-25): it touches a lower layer, or it is the source
        if FloodInternal::capped(self) {
            let top = Bits::and(*layers.pop_back().unwrap(), free);
            if top.low != 0 || top.high != 0 {
                if FloodInternal::source(self, @walker)
                    || FloodInternal::last(ref layers, around).is_some() {
                    return Option::Some(FloodInternal::lowest(back, @walker, top));
                }
                return Option::None;
            }
        }
        // [Compute] The free neighbours in the greatest layer that holds one: below the cap, the
        // walker is reached
        let hit = FloodInternal::last(ref layers, free)?;
        Option::Some(FloodInternal::lowest(back, @walker, hit))
    }

    /// The path distance of a tile from the source: its layer; for a tile in no layer, the least
    /// layer of its neighbours plus one (D-26), which is the distance of an obstacle or a walker
    /// frozen by the flood.
    /// # Arguments
    /// * `self` - The flood
    /// * `position` - The tile, any tile of the board (the ring included)
    /// # Returns
    /// * The distance, `None` outside the board or when neither the tile nor a neighbour is in a
    ///   layer
    fn distance(self: @Flood, position: u8) -> Option<u8> {
        let (_, walker) = FloodInternal::walker(self, position)?;
        let mut layers = *self.layers;
        // [Check] The source, layer 0
        if FloodInternal::source(self, @walker) {
            return Option::Some(0);
        }
        // [Compute] A tile in layer k ≥ 1 has a neighbour in layer k − 1 and none below it: the
        // least layer touching the neighbourhood, plus one, is the layer or the inferred distance
        FloodInternal::first(ref layers, walker.around.into())?;
        // At most 1 + (W − 2)(H − 2) layers, below 256
        Option::Some(((*self.layers).len() - layers.len()).try_into().unwrap())
    }
}

#[generate_trait]
pub impl FloodAssert of FloodAssertTrait {
    /// Assert that the source of a flood is not an obstacle.
    /// # Arguments
    /// * `obstacles` - The obstacles
    /// * `from` - The source, inside the board
    /// # Panics
    /// * `'Bfs: position not walkable'` when `from` is an obstacle
    #[inline]
    fn assert_free(obstacles: u256, from: u8) {
        assert(!Bits::get(obstacles, from), errors::FLOOD_POSITION_NOT_WALKABLE);
    }
}

#[generate_trait]
pub(crate) impl FloodInternal of FloodInternalTrait {
    /// Store the layers from layer 1, at most `count` of them, until the frontier is empty: the
    /// layer step of `Bfs` (`BfsInternal::layer`), `count − 1` times at most, and no layer beyond
    /// the last one stored.
    /// # Arguments
    /// * `step` - The layer constants
    /// * `low`, `high` - Layer 1
    /// * `free_low`, `free_high` - The walkable interior tiles not yet reached
    /// * `count` - The largest number of layers to store, at least 1
    /// * `store` - The layers
    #[inline]
    fn spread(
        step: @Dilation,
        low: u128,
        high: u128,
        free_low: u128,
        free_high: u128,
        count: u8,
        ref store: Array<u256>,
    ) {
        let mut low = low;
        let mut high = high;
        let mut free_low = free_low;
        let mut free_high = free_high;
        let mut count: felt252 = count.into();
        loop {
            count -= 1;
            if count == 0 {
                // The last layer allowed: stored when not empty, never expanded
                if low != 0 || high != 0 {
                    ArrayStore::push(ref store, low, high);
                }
                break;
            }
            let (layer_low, layer_high) = (low, high);
            if !BfsInternal::layer(step, ref low, ref high, ref free_low, ref free_high) {
                break;
            }
            ArrayStore::push(ref store, layer_low, layer_high);
        }
    }

    /// `spread` on a single limb, with `BfsInternal::layer_small`; the layers are widened, so
    /// that both paths build one `Flood`.
    #[inline]
    fn spread_small(step: @Dilation, layer: u128, free: u128, count: u8, ref store: Array<u256>) {
        let mut layer = layer;
        let mut free = free;
        let mut count: felt252 = count.into();
        loop {
            count -= 1;
            if count == 0 {
                if layer != 0 {
                    store.append(u256 { low: layer, high: 0 });
                }
                break;
            }
            let current = layer;
            if !BfsInternal::layer_small(step, ref layer, ref free) {
                break;
            }
            store.append(u256 { low: current, high: 0 });
        }
    }

    /// Describe a walker: its tile, its row parity and the bits of its board neighbours, with
    /// the constants that identify a neighbour from its bit (`BfsInternal::identify`).
    /// # Arguments
    /// * `self` - The flood
    /// * `position` - The walker
    /// # Returns
    /// * The constants and the walker, `None` outside the board
    #[inline(always)]
    fn walker(self: @Flood, position: u8) -> Option<(Back, Endpoint)> {
        let width = *self.width;
        let height = *self.height;
        if position >= width * height {
            return Option::None;
        }
        // 2^(W − 1) and 2^−(W + 1), the shifts of an even row
        let back = BfsInternal::back_constants(width, Bits::pow(width - 1), Bits::inv(width + 1));
        // [Compute] Column and row, one division by 2W (as `BfsInternal::endpoint`)
        let (half, rem) = DivRem::div_rem(position, (2 * width).try_into().unwrap());
        let (x, y, odd) = if rem < width {
            (rem, 2 * half, false)
        } else {
            (rem - width, 2 * half + 1, true)
        };
        let power = Bits::pow(position);
        // [Compute] The neighbour bits: `2^i` times the offsets that stay on the board
        let lower = x != 0;
        let upper = x != width - 1;
        let below = y != 0;
        let above = y != height - 1;
        let interior = lower && upper && below && above;
        let offsets = if interior {
            if odd {
                back.around_odd
            } else {
                back.around_even
            }
        } else {
            Self::edge(@back, odd, lower, upper, below, above)
        };
        let around = power * offsets;
        Option::Some((back, Endpoint { position, power, interior, odd, x, y, half, around }))
    }

    /// The relative offsets of the board neighbours of a ring tile, as a field sum, without the
    /// per-direction loop of `LayoutTrait::edge_neighbours`: `2^-1` and `2` for the tiles of the
    /// same row, `2^-W · r` and `2^W · r` for the rows below and above, where `r` is the pair of
    /// columns of that row, `{x, x + 1}` on an odd row (`1 + 2`) and `{x − 1, x}` on an even
    /// row (`2^-1 + 1`), each offset kept only when its tile lies on the board.
    /// # Arguments
    /// * `back` - The constants
    /// * `odd` - Whether the row is odd
    /// * `lower`, `upper` - Whether the columns `x − 1`, `x + 1` exist
    /// * `below`, `above` - Whether the rows `y − 1`, `y + 1` exist
    /// # Returns
    /// * The offsets, exact: every kept neighbour is a bit of the board
    #[inline]
    fn edge(back: @Back, odd: bool, lower: bool, upper: bool, below: bool, above: bool) -> felt252 {
        let back = *back;
        // [Compute] The columns of the rows below and above
        let row = if odd {
            if upper {
                3
            } else {
                1
            }
        } else if lower {
            1 + INV_2
        } else {
            1
        };
        let mut offsets: felt252 = 0;
        if lower {
            offsets += INV_2;
        }
        if upper {
            offsets += 2;
        }
        if below {
            offsets += back.down_odd * row;
        }
        if above {
            offsets += back.up_odd * row;
        }
        offsets
    }

    /// Whether the flood stopped at the requested `depth`: its last layer is at the cap.
    #[inline(always)]
    fn capped(self: @Flood) -> bool {
        (*self.layers).len() == (*self.cap).into() + 1
    }

    /// Whether a walker stands on the source, layer 0.
    #[inline(always)]
    fn source(self: @Flood, walker: @Endpoint) -> bool {
        let source = *(*self.layers)[0];
        source.low.into() + source.high.into() * TWO_POW_128 == *walker.power
    }

    /// The least layer that touches a set, scanned from layer 0; the layers up to it are popped.
    /// # Arguments
    /// * `layers` - The layers left to scan
    /// * `set` - The set
    /// # Returns
    /// * The tiles of the set in that layer, `None` when no layer touches it
    #[inline(always)]
    fn first(ref layers: Span<u256>, set: u256) -> Option<u256> {
        if set.high == 0 {
            Self::up(ref layers, Low { mask: set.low })
        } else if set.low == 0 {
            Self::up(ref layers, High { mask: set.high })
        } else {
            Self::up(ref layers, set)
        }
    }

    /// The greatest layer that touches a set, scanned from the last layer; the layers from it
    /// are popped.
    /// # Arguments
    /// * `layers` - The layers left to scan
    /// * `set` - The set
    /// # Returns
    /// * The tiles of the set in that layer, `None` when no layer touches it
    #[inline(always)]
    fn last(ref layers: Span<u256>, set: u256) -> Option<u256> {
        if set.high == 0 {
            Self::down(ref layers, Low { mask: set.low })
        } else if set.low == 0 {
            Self::down(ref layers, High { mask: set.high })
        } else {
            Self::down(ref layers, set)
        }
    }

    /// Scan the layers from the first one left for the first that touches a set, on the limbs
    /// that hold it.
    /// # Arguments
    /// * `layers` - The layers left to scan
    /// * `set` - The set
    /// # Returns
    /// * The tiles of the set in that layer, `None` when no layer touches it
    #[inline]
    fn up<M, +Touch<M>, +Copy<M>, +Drop<M>>(ref layers: Span<u256>, set: M) -> Option<u256> {
        while let Option::Some(layer) = layers.pop_front() {
            let hit = set.touch(*layer);
            if hit.low != 0 || hit.high != 0 {
                return Option::Some(hit);
            }
        }
        Option::None
    }

    /// `up` from the last layer left, downward.
    #[inline]
    fn down<M, +Touch<M>, +Copy<M>, +Drop<M>>(ref layers: Span<u256>, set: M) -> Option<u256> {
        while let Option::Some(layer) = layers.pop_back() {
            let hit = set.touch(*layer);
            if hit.low != 0 || hit.high != 0 {
                return Option::Some(hit);
            }
        }
        Option::None
    }

    /// The tiles of a set that are not blocked.
    /// # Arguments
    /// * `set` - The set
    /// * `blocked` - The blocked tiles
    /// # Returns
    /// * `set & ~blocked`
    #[inline(always)]
    fn without(set: u256, blocked: u256) -> u256 {
        let (low, _, _) = Bits::bitwise(set.low, blocked.low);
        let (high, _, _) = Bits::bitwise(set.high, blocked.high);
        u256 { low: set.low - low, high: set.high - high }
    }

    /// The lowest neighbour of a walker in a set of its neighbours: the lowest set bit,
    /// identified among the 6 offsets (`BfsInternal::identify`).
    /// # Arguments
    /// * `back` - The constants
    /// * `walker` - The walker
    /// * `set` - Neighbours of the walker, not empty
    /// # Returns
    /// * The tile of the lowest one
    #[inline(always)]
    fn lowest(back: Back, walker: @Endpoint, set: u256) -> u8 {
        let lowest: felt252 = if set.low != 0 {
            let (rest, _, _) = Bits::bitwise(set.low, set.low - 1);
            (set.low - rest).into()
        } else {
            let (rest, _, _) = Bits::bitwise(set.high, set.high - 1);
            (set.high - rest).into() * TWO_POW_128
        };
        let walker = *walker;
        let (tile, _, _) = BfsInternal::identify(
            BoxTrait::new(back), walker.position, walker.power, walker.odd, lowest,
        );
        tile
    }
}

/// The part of a set that a layer holds, computed on the limbs of the set only.
trait Touch<M> {
    fn touch(self: M, layer: u256) -> u256;
}

/// A set in the low limb.
#[derive(Copy, Drop)]
struct Low {
    mask: u128,
}

/// A set in the high limb.
#[derive(Copy, Drop)]
struct High {
    mask: u128,
}

impl LowTouch of Touch<Low> {
    #[inline(always)]
    fn touch(self: Low, layer: u256) -> u256 {
        let (low, _, _) = Bits::bitwise(layer.low, self.mask);
        u256 { low, high: 0 }
    }
}

impl HighTouch of Touch<High> {
    #[inline(always)]
    fn touch(self: High, layer: u256) -> u256 {
        let (high, _, _) = Bits::bitwise(layer.high, self.mask);
        u256 { low: 0, high }
    }
}

impl WideTouch of Touch<u256> {
    #[inline(always)]
    fn touch(self: u256, layer: u256) -> u256 {
        Bits::and(layer, self)
    }
}
