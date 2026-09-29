//! Gas benchmarks of N-8, the flood of the tick (plan §6.9, §7), on its worst cases: the pinned
//! corridor `SERPENTINE_15X16` (one frontier tile or two per layer, every layer a full dilation on
//! two limbs) at `depth` 10, 15, 20 and without a limit (D-127), the eight frozen walkers of
//! `SERPENTINE_15X16_8`, and a cave window of 15 × 16 at the game's 15 layers. Each figure is the
//! difference between a test that floods and the baseline test, which does everything else (the
//! method of the game's SPK-7); the cost per layer and the fixed cost are differences of two
//! floods. The figures are in `docs/GAS.md` and the task's report.
//!
//! The inputs come from one opaque call (`Inputs::get`) in every test, so that no flood is folded
//! at compile time.

// Internal imports

use hexx::finders::bfs::Bfs;
use hexx::finders::flood::FloodTrait;
use hexx::tests::fixtures::{SERPENTINE_15X16, SERPENTINE_15X16_8, SERPENTINE_15X16_FROM};
use hexx::tests::test_flood::{CAVE_15X16, CAVE_15X16_FROM};

/// The inputs of every test.
#[derive(Copy, Drop)]
struct Bench {
    serpentine: felt252,
    /// `(1, 2)` frozen: R-N8-1, 45 layers.
    frozen: felt252,
    /// The eight walkers of `SERPENTINE_15X16_8`: 41 layers.
    walkers: felt252,
    /// The source of both boards, `(7, 8)`.
    from: u8,
    cave: felt252,
    cave_from: u8,
    /// The depths: none, 10, 15 (the game's, D-127), 20 and no limit.
    zero: u8,
    ten: u8,
    fifteen: u8,
    twenty: u8,
    unlimited: u8,
}

#[generate_trait]
impl Inputs of InputsTrait {
    /// The inputs, opaque to the compiler (`#[inline(never)]`, as in `bench_assembly`).
    #[inline(never)]
    fn get() -> Bench {
        Bench {
            serpentine: SERPENTINE_15X16,
            frozen: 0x80000000,
            walkers: SERPENTINE_15X16_8,
            from: SERPENTINE_15X16_FROM,
            cave: CAVE_15X16,
            cave_from: CAVE_15X16_FROM,
            zero: 0,
            ten: 10,
            fifteen: 15,
            twenty: 20,
            unlimited: 255,
        }
    }
}

// The baseline: the inputs and an assertion, no flood

#[test]
#[inline(never)]
#[available_gas(l2_gas: 17052)]
fn bench_flood_baseline() {
    let bench = Inputs::get();
    assert!(bench.from == 127);
}

// `SERPENTINE_15X16`, R-N8-1: `(1, 2)` frozen

#[test]
#[inline(never)]
#[available_gas(l2_gas: 53941)]
fn bench_flood_serpentine_0() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.serpentine, 15, 16, bench.from, bench.frozen, bench.zero);
    assert!(flood.depth() == 0);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 280758)]
fn bench_flood_serpentine_10() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.serpentine, 15, 16, bench.from, bench.frozen, bench.ten);
    assert!(flood.depth() == 10);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 400174)]
fn bench_flood_serpentine_15() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.serpentine, 15, 16, bench.from, bench.frozen, bench.fifteen);
    assert!(flood.depth() == 15);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 519591)]
fn bench_flood_serpentine_20() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.serpentine, 15, 16, bench.from, bench.frozen, bench.twenty);
    assert!(flood.depth() == 20);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1097013)]
fn bench_flood_serpentine_unlimited() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.serpentine, 15, 16, bench.from, bench.frozen, bench.unlimited);
    assert!(flood.depth() == 45);
}

// `SERPENTINE_15X16_8`: the eight walkers frozen

#[test]
#[inline(never)]
#[available_gas(l2_gas: 998991)]
fn bench_flood_serpentine_8() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.serpentine, 15, 16, bench.from, bench.walkers, bench.unlimited);
    assert!(flood.depth() == 41);
}

// `FloodTrait::depth`: the difference of the two tests is one call

#[test]
#[inline(never)]
#[available_gas(l2_gas: 281356)]
fn bench_flood_depth_once() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.serpentine, 15, 16, bench.from, bench.frozen, bench.ten);
    assert!(flood.depth() + bench.ten == 20);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 282060)]
fn bench_flood_depth_twice() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.serpentine, 15, 16, bench.from, bench.frozen, bench.ten);
    assert!(flood.depth() + flood.depth() == 20);
}

// The cave window, from the adventurer's tile

#[test]
#[inline(never)]
#[available_gas(l2_gas: 392709)]
fn bench_flood_cave_15() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.cave, 15, 16, bench.cave_from, 0, bench.fifteen);
    assert!(flood.depth() == 15);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 433430)]
fn bench_flood_cave_unlimited() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.cave, 15, 16, bench.cave_from, 0, bench.unlimited);
    assert!(flood.depth() == 16);
}
