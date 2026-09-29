//! Band tables of the chunks of 15 × 15 (plan §6.4): the columns and the rows of a rectangle of a
//! chunk, one entry per start or end, so that a rectangle is the product of two entries.
//!
//! Tables of constants: they are free constants of the module for that reason (D-143).
//!
//! A column band is a mask of row 0 (bits `0..15`); a row band is a mask of column 0 (bits
//! `15·j`). Their product is the rectangle, exact since the bits of the two operands never meet
//! (below 2^225).

/// `COL_FROM[k]`: the columns `[k, 15)` of row 0, `(2^(15 − k) − 1)·2^k`; entry 15 is 0.
pub const COL_FROM: [felt252; 16] = [
    0x7fff, 0x7ffe, 0x7ffc, 0x7ff8, 0x7ff0, 0x7fe0, 0x7fc0, 0x7f80, 0x7f00, 0x7e00, 0x7c00, 0x7800,
    0x7000, 0x6000, 0x4000, 0x0,
];

/// `COL_TO[k]`: the columns `[0, k)` of row 0, `2^k − 1`; entry 15 is the full row.
pub const COL_TO: [felt252; 16] = [
    0x0, 0x1, 0x3, 0x7, 0xf, 0x1f, 0x3f, 0x7f, 0xff, 0x1ff, 0x3ff, 0x7ff, 0xfff, 0x1fff, 0x3fff,
    0x7fff,
];

/// `ROW_FROM_15[k]`: the rows `[k, 15)` of a chunk at column 0, `Σ_{j=k}^{14} 2^(15j)`; entry 15
/// is 0.
pub const ROW_FROM_15: [felt252; 16] = [
    0x40008001000200040008001000200040008001000200040008001,
    0x40008001000200040008001000200040008001000200040008000,
    0x40008001000200040008001000200040008001000200040000000,
    0x40008001000200040008001000200040008001000200000000000,
    0x40008001000200040008001000200040008001000000000000000,
    0x40008001000200040008001000200040008000000000000000000,
    0x40008001000200040008001000200040000000000000000000000,
    0x40008001000200040008001000200000000000000000000000000,
    0x40008001000200040008001000000000000000000000000000000,
    0x40008001000200040008000000000000000000000000000000000,
    0x40008001000200040000000000000000000000000000000000000,
    0x40008001000200000000000000000000000000000000000000000,
    0x40008001000000000000000000000000000000000000000000000,
    0x40008000000000000000000000000000000000000000000000000,
    0x40000000000000000000000000000000000000000000000000000, 0x0,
];

/// `ROW_TO_15[k]`: the rows `[0, k)` of a chunk at column 0, `Σ_{j<k} 2^(15j)`; entry 15 is
/// every row.
pub const ROW_TO_15: [felt252; 16] = [
    0x0, 0x1, 0x8001, 0x40008001, 0x200040008001, 0x1000200040008001, 0x8001000200040008001,
    0x40008001000200040008001, 0x200040008001000200040008001, 0x1000200040008001000200040008001,
    0x8001000200040008001000200040008001, 0x40008001000200040008001000200040008001,
    0x200040008001000200040008001000200040008001, 0x1000200040008001000200040008001000200040008001,
    0x8001000200040008001000200040008001000200040008001,
    0x40008001000200040008001000200040008001000200040008001,
];

#[cfg(test)]
mod tests {
    // Local imports

    use super::{COL_FROM, COL_TO, ROW_FROM_15, ROW_TO_15};

    /// Every entry against its definition, bit by bit.
    #[test]
    #[available_gas(l2_gas: 948161)]
    fn test_tables_bands() {
        let mut k: u32 = 0;
        while k != 16 {
            let mut col_from: felt252 = 0;
            let mut col_to: felt252 = 0;
            let mut row_from: felt252 = 0;
            let mut row_to: felt252 = 0;
            let mut bit: felt252 = 1;
            let mut row: felt252 = 1;
            let mut j: u32 = 0;
            while j != 15 {
                if j >= k {
                    col_from += bit;
                    row_from += row;
                } else {
                    col_to += bit;
                    row_to += row;
                }
                bit *= 2;
                row *= 0x8000;
                j += 1;
            }
            assert!(*COL_FROM.span().at(k) == col_from);
            assert!(*COL_TO.span().at(k) == col_to);
            assert!(*ROW_FROM_15.span().at(k) == row_from);
            assert!(*ROW_TO_15.span().at(k) == row_to);
            k += 1;
        }
    }
}
