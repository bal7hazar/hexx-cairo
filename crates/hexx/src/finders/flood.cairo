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
//! The selection of each walker's step (`next_step`, `next_step_away`, `distance`) is M1-T9b.

// Internal imports

use hexx::board::bits::Bits;
use hexx::board::layout::Dilation;
use hexx::finders::bfs::{ArrayStore, BfsInternal};

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
}
