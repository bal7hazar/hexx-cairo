//! Tests of `Hex` (`hex.cairo`) against plain oracles and the documented deviations. The golden
//! vectors from the crate are in `crates/hexx/tests/golden_hex.cairo`.

use hexx::hex::HexTrait;

// The oracle: the definition of the hexagonal distance, `max(|dx|, |dy|, |dx + dy|)`, on values
// small enough that nothing overflows, written with no helper of the port.
#[generate_trait]
impl OracleImpl of OracleTrait {
    fn distance(dx: i32, dy: i32) -> u32 {
        let ax: u32 = if dx < 0 {
            (0 - dx).try_into().unwrap()
        } else {
            dx.try_into().unwrap()
        };
        let ay: u32 = if dy < 0 {
            (0 - dy).try_into().unwrap()
        } else {
            dy.try_into().unwrap()
        };
        let sum = dx + dy;
        let az: u32 = if sum < 0 {
            (0 - sum).try_into().unwrap()
        } else {
            sum.try_into().unwrap()
        };
        let mut best = ax;
        if ay > best {
            best = ay;
        }
        if az > best {
            best = az;
        }
        best
    }
}

#[test]
#[available_gas(l2_gas: 356270796)]
fn test_hex_distance_matches_the_oracle() {
    let mut x1: i32 = -4;
    while x1 <= 4 {
        let mut y1: i32 = -4;
        while y1 <= 4 {
            let mut x2: i32 = -4;
            while x2 <= 4 {
                let mut y2: i32 = -4;
                while y2 <= 4 {
                    let a = HexTrait::new(x1, y1);
                    let b = HexTrait::new(x2, y2);
                    let expected = OracleTrait::distance(x1 - x2, y1 - y2);
                    assert(a.unsigned_distance_to(b) == expected, 'unsigned distance');
                    let signed: i32 = expected.try_into().unwrap();
                    assert(a.distance_to(b) == signed, 'distance');
                    assert(a.distance_to(b) == b.distance_to(a), 'symmetric');
                    y2 += 1;
                }
                x2 += 1;
            }
            y1 += 1;
        }
        x1 += 1;
    }
}

#[test]
#[available_gas(l2_gas: 26540997)]
fn test_hex_length_and_cubic_coordinate() {
    let mut x: i32 = -10;
    while x <= 10 {
        let mut y: i32 = -10;
        while y <= 10 {
            let h = HexTrait::new(x, y);
            assert(h.x() == x && h.y() == y, 'accessors');
            assert(h.x == x && h.y == y, 'fields');
            assert(h.x() + h.y() + h.z() == 0, 'cubic sum');
            let length: u32 = h.length().try_into().unwrap();
            assert(length == h.ulength(), 'length is ulength');
            assert(h.ulength() == OracleTrait::distance(x, y), 'length is the distance to zero');
            assert(h.distance_to(HexTrait::ZERO) == h.length(), 'distance to zero');
            y += 1;
        }
        x += 1;
    }
}

#[test]
#[available_gas(l2_gas: 14406)]
fn test_hex_const_sub() {
    let a = HexTrait::new(7, -3);
    let b = HexTrait::new(-2, 5);
    assert(a.const_sub(b) == HexTrait::new(9, -8), 'a - b');
    assert(b.const_sub(a) == HexTrait::new(-9, 8), 'b - a');
    assert(a.const_sub(a) == HexTrait::ZERO, 'a - a');
    assert(HexTrait::ZERO == Default::default(), 'ZERO is the default');
}

#[test]
#[available_gas(l2_gas: 133791)]
fn test_hex_neighbors_coords_are_the_six_unit_steps() {
    let neighbors = HexTrait::NEIGHBORS_COORDS;
    let neighbors = neighbors.span();
    assert(neighbors.len() == 6, 'six neighbours');
    let mut i = 0;
    while i < 6 {
        let n = *neighbors.at(i);
        assert(HexTrait::ZERO.distance_to(n) == 1, 'a neighbour is at distance 1');
        // The opposite neighbour is three places on and cancels it.
        let opposite = *neighbors.at((i + 3) % 6);
        assert(n.const_sub(opposite) == HexTrait::new(2 * n.x, 2 * n.y), 'opposite');
        i += 1;
    }
}

// The deviations: where `hexx` wraps in a release build and panics in a debug build, this port
// panics (plan §3.1). The golden files cover the bounds of every function; these name the
// documented cases.

#[test]
#[available_gas(l2_gas: 16086)]
#[should_panic]
fn test_hex_z_panics_on_negating_min() {
    let _ = HexTrait::new(-2147483648, 0).z();
}

#[test]
#[available_gas(l2_gas: 16086)]
#[should_panic]
fn test_hex_z_panics_when_the_sum_leaves_i32() {
    let _ = HexTrait::new(0, -2147483648).z();
}

#[test]
#[available_gas(l2_gas: 16086)]
#[should_panic]
fn test_hex_const_sub_panics_on_overflow() {
    let _ = HexTrait::new(2147483647, 0).const_sub(HexTrait::new(-1, 0));
}

#[test]
#[available_gas(l2_gas: 16086)]
#[should_panic]
fn test_hex_length_panics_on_min() {
    let _ = HexTrait::new(0, -2147483648).length();
}

#[test]
#[available_gas(l2_gas: 14406)]
fn test_hex_ulength_is_exact_on_min_components() {
    // `y = i32::MIN` with `x = 1` gives `z = i32::MAX`: `|y| = 2^31` has no `i32`, but `ulength`
    // holds it in a `u32`, as `i32::unsigned_abs` does in `hexx`.
    let h = HexTrait::new(1, -2147483648);
    assert(h.z() == 2147483647, 'z');
    assert(h.ulength() == 2147483648, 'ulength');
    assert(h.unsigned_distance_to(HexTrait::ZERO) == 2147483648, 'unsigned distance');
    let h = HexTrait::new(1073741824, -1073741824);
    assert(h.z() == 0, 'z of the diagonal');
    assert(h.ulength() == 1073741824, 'ulength of the diagonal');
    assert(h.length() == 1073741824, 'length of the diagonal');
}
