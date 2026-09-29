//! N-4: the cut of a board by a mask (plan §6.5, as reversed by §14, D-23).
//!
//! For the game the cut keeps what the mask allows, ring included: the ring of a chunk holds the
//! openings to its neighbours, which the game opens before it cuts by the outline of a zone. So
//! `cut(grid, mask) = grid & mask`, the bits at or above `W · H` cleared. No loop: two ANDs of
//! `u256`, one against the mask and one against the board.

// Internal imports

use hexx::board::bits::Bits;
use hexx::board::layout::LayoutTrait;
use hexx::board::map::{HexMap, HexMapTrait};

#[generate_trait]
pub impl CutImpl of CutTrait {
    /// Cut a board by a mask: every tile keeps its state iff its bit is set in the mask.
    /// # Arguments
    /// * `self` - The map, of valid dimensions
    /// * `mask` - The tiles to keep; its bits at or above `W · H` have no effect
    /// # Returns
    /// * The map whose grid is `grid & mask`, the bits at or above `W · H` cleared; the
    ///   dimensions and the seed are unchanged
    ///
    /// Mirrors nothing in `hexx`: an extension (N-4). Unlike the plan's §6.5 it does not clear
    /// the ring (§14, D-23): an open edge tile inside the mask stays open.
    #[inline]
    fn cut(self: HexMap, mask: felt252) -> HexMap {
        // [Compute] The mask restricted to the board, then the grid restricted to the mask
        let board: u256 = LayoutTrait::board(self.width, self.height).into();
        let keep = Bits::and(mask.into(), board);
        let grid = Bits::to_felt(Bits::and(self.grid.into(), keep));
        // [Return] Dimensions and seed unchanged
        HexMapTrait::new(grid, self.width, self.height, self.seed)
    }
}
