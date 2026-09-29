//! Gas benchmarks of N-8, the tick of the game as the library sees it (plan §6.9, §7): the
//! window assembled from 4 chunks (two layers, `ox = oy = 7` on an odd chunk row, the worst case
//! of `bench_assembly`), the flood capped at 15 layers (D-127) on the occupancy frozen, then the
//! eight walkers in ascending id order, each `next_step` filtered by the occupancy updated after
//! the previous moves (L-G1 point 5).
//!
//! The cap is the flood's (D-25): `next_step` gives no move to a walker whose inferred distance
//! is greater than the `depth` passed to `Bfs::flood`, so a walker the capped flood did not
//! reach holds its position (D-127) without any call beyond its `next_step`.
//!
//! Each figure is the difference of two tests (the method of the game's SPK-7): the tick is the
//! tick test minus the baseline, which does everything else (the inputs and one assertion); its
//! breakdown is window − baseline, flood = (window and flood) − window, steps = tick −
//! (window and flood). Each selection function alone, on its worst case of §6.9, is a test that
//! calls it twice minus one that calls it once, on the same flood. The figures are in `docs/GAS.md`
//! and the task's report.
//!
//! The inputs come from one opaque call (`Inputs::get`) in every test, so that nothing is folded
//! at compile time.

// Internal imports

use hexx::board::assembly::{AssemblyTrait, Origin};
use hexx::board::bits::Bits;
use hexx::finders::bfs::Bfs;
use hexx::finders::flood::{Flood, FloodTrait};
use hexx::tests::fixtures::{
    CAVE_15X16_8, CAVE_15X16_8_CHUNKS, CAVE_15X16_CHUNKS, CAVE_15X16_RING_CHUNKS,
    CAVE_15X16_RING_WALKERS, CAVE_15X16_WALKERS, SERPENTINE_15X16, SERPENTINE_15X16_8,
    SERPENTINE_15X16_8_CHUNKS, SERPENTINE_15X16_CHUNKS, SERPENTINE_15X16_FROM,
    SERPENTINE_15X16_WALKERS,
};
use hexx::tests::test_flood::{CAVE_15X16, CAVE_15X16_FROM};

/// A window of the tick: its 4 chunks, two layers, and its eight walkers.
#[derive(Copy, Drop)]
struct Window {
    terrain: [Option<felt252>; 4],
    occupied: [Option<felt252>; 4],
    walkers: [u8; 8],
    /// The occupancy after the eight moves.
    after: felt252,
}

/// The inputs of every test.
#[derive(Copy, Drop)]
struct Bench {
    origin: Origin,
    /// The adventurer's tile, `(7, 8)`, in both windows.
    from: u8,
    /// The game's cap, 15 layers (D-127).
    cap: u8,
    cave: Window,
    /// The cave tick with W8 on the ring, `(14, 4)`, at 13.
    cave_ring: Window,
    serpentine: Window,
    /// `SERPENTINE_15X16`, with `(1, 2)` frozen: R-N8-1, 45 layers.
    corridor: felt252,
    frozen: felt252,
    unlimited: u8,
    /// `(1, 2)` of R-N8-1, at 46; its step `(2, 2)`.
    far: u8,
    far_step: Option<u8>,
    far_distance: Option<u8>,
    /// `(4, 8)` of R-N8-6, its two open neighbours blocked.
    near: u8,
    near_blocked: felt252,
    /// The cave of the tick: W1, at 15, and its step.
    cave_grid: felt252,
    cave_walkers: felt252,
    walker: u8,
    walker_step: Option<u8>,
    /// The serpentine with `(0, 8)` open (R-N8-5): the walker on the ring and its step.
    ring_grid: felt252,
    ring: u8,
    ring_step: Option<u8>,
    none: Option<u8>,
    zero: felt252,
}

#[generate_trait]
impl Inputs of InputsTrait {
    /// The inputs, opaque to the compiler (`#[inline(never)]`, as in `bench_assembly`).
    #[inline(never)]
    fn get() -> Bench {
        let [c0, c1, c2, c3] = CAVE_15X16_CHUNKS;
        let [d0, d1, d2, d3] = CAVE_15X16_8_CHUNKS;
        let [r0, r1, r2, r3] = CAVE_15X16_RING_CHUNKS;
        let [s0, s1, s2, s3] = SERPENTINE_15X16_CHUNKS;
        let [t0, t1, t2, t3] = SERPENTINE_15X16_8_CHUNKS;
        Bench {
            origin: Origin { cx: 3, cy: 5, ox: 7, oy: 7 },
            from: SERPENTINE_15X16_FROM,
            cap: 15,
            cave: Window {
                terrain: [Option::Some(c0), Option::Some(c1), Option::Some(c2), Option::Some(c3)],
                occupied: [Option::Some(d0), Option::Some(d1), Option::Some(d2), Option::Some(d3)],
                walkers: CAVE_15X16_WALKERS,
                after: 0x41004002800280040000000000,
            },
            cave_ring: Window {
                terrain: [Option::Some(c0), Option::Some(c1), Option::Some(c2), Option::Some(c3)],
                occupied: [Option::Some(r0), Option::Some(r1), Option::Some(r2), Option::Some(r3)],
                walkers: CAVE_15X16_RING_WALKERS,
                after: 0x1014002800280040000000000,
            },
            serpentine: Window {
                terrain: [Option::Some(s0), Option::Some(s1), Option::Some(s2), Option::Some(s3)],
                occupied: [Option::Some(t0), Option::Some(t1), Option::Some(t2), Option::Some(t3)],
                walkers: SERPENTINE_15X16_WALKERS,
                after: SERPENTINE_15X16_8,
            },
            corridor: SERPENTINE_15X16,
            frozen: 0x80000000,
            unlimited: 182,
            far: 31,
            far_step: Option::Some(32),
            far_distance: Option::Some(46),
            near: 124,
            near_blocked: Bits::pow(123) + Bits::pow(125),
            cave_grid: CAVE_15X16,
            cave_walkers: CAVE_15X16_8,
            walker: 40,
            walker_step: Option::Some(55),
            ring_grid: SERPENTINE_15X16 + Bits::pow(120),
            ring: 120,
            ring_step: Option::Some(121),
            none: Option::None,
            zero: 0,
        }
    }
}

#[generate_trait]
impl Tick of TickTrait {
    /// The window of a tick, from its chunks: the terrain and the occupancy.
    #[inline(always)]
    fn window(window: @Window, origin: @Origin) -> (felt252, felt252) {
        let (map, occupied) = AssemblyTrait::window(*window.terrain, *window.occupied, origin, 0);
        (map.grid, occupied)
    }

    /// The flood of a tick on its window, the occupancy frozen, capped.
    #[inline(always)]
    fn flood(bench: @Bench, window: @Window) -> (Flood, felt252) {
        let (grid, occupied) = Self::window(window, bench.origin);
        (Bfs::flood(grid, 15, 16, *bench.from, occupied, *bench.cap), occupied)
    }

    /// The eight walkers in ascending id order, each filtered by the current occupancy, which
    /// is updated after each move: the tile left is freed, the tile entered occupied. A walker
    /// that gets `None` holds its position: among them, the walkers the flood did not reach,
    /// whose inferred distance is greater than the cap (D-25, D-127).
    #[inline(always)]
    fn steps(flood: @Flood, walkers: [u8; 8], occupied: felt252) -> felt252 {
        let mut occupied = occupied;
        for walker in walkers.span() {
            if let Option::Some(step) = flood.next_step(*walker, occupied) {
                occupied = occupied - Bits::pow(*walker) + Bits::pow(step);
            }
        }
        occupied
    }
}

// The baseline: the inputs and an assertion, nothing else

#[test]
#[inline(never)]
#[available_gas(l2_gas: 31763)]
fn bench_tick_baseline() {
    let bench = Inputs::get();
    assert!(bench.from == 127);
}

// The cave of the tick

#[test]
#[inline(never)]
#[available_gas(l2_gas: 99198)]
fn bench_tick_cave_window() {
    let bench = Inputs::get();
    let (_, occupied) = Tick::window(@bench.cave, @bench.origin);
    assert!(occupied == bench.cave_walkers);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 474435)]
fn bench_tick_cave_flood() {
    let bench = Inputs::get();
    let (flood, _) = Tick::flood(@bench, @bench.cave);
    assert!(flood.depth() == bench.cap);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1149182)]
fn bench_tick_cave() {
    let bench = Inputs::get();
    let (flood, occupied) = Tick::flood(@bench, @bench.cave);
    assert!(Tick::steps(@flood, bench.cave.walkers, occupied) == bench.cave.after);
}

// The cave of the tick, W8 on the ring

#[test]
#[inline(never)]
#[available_gas(l2_gas: 474435)]
fn bench_tick_cave_ring_flood() {
    let bench = Inputs::get();
    let (flood, _) = Tick::flood(@bench, @bench.cave_ring);
    assert!(flood.depth() == bench.cap);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1154226)]
fn bench_tick_cave_ring() {
    let bench = Inputs::get();
    let (flood, occupied) = Tick::flood(@bench, @bench.cave_ring);
    assert!(Tick::steps(@flood, bench.cave_ring.walkers, occupied) == bench.cave_ring.after);
}

// The serpentine

#[test]
#[inline(never)]
#[available_gas(l2_gas: 99198)]
fn bench_tick_serpentine_window() {
    let bench = Inputs::get();
    let (_, occupied) = Tick::window(@bench.serpentine, @bench.origin);
    assert!(occupied == bench.serpentine.after);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 482730)]
fn bench_tick_serpentine_flood() {
    let bench = Inputs::get();
    let (flood, _) = Tick::flood(@bench, @bench.serpentine);
    assert!(flood.depth() == bench.cap);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1193762)]
fn bench_tick_serpentine() {
    let bench = Inputs::get();
    let (flood, occupied) = Tick::flood(@bench, @bench.serpentine);
    assert!(Tick::steps(@flood, bench.serpentine.walkers, occupied) == bench.serpentine.after);
}

// `next_step`, `s = 15`: W1 of the cave tick, on its flood (the window given)

#[test]
#[inline(never)]
#[available_gas(l2_gas: 492915)]
fn bench_tick_next_step_15_once() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.cave_grid, 15, 16, bench.from, bench.cave_walkers, bench.cap);
    assert!(flood.next_step(bench.walker, bench.cave_walkers) == bench.walker_step);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 578798)]
fn bench_tick_next_step_15_twice() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.cave_grid, 15, 16, bench.from, bench.cave_walkers, bench.cap);
    assert!(
        flood
            .next_step(bench.walker, bench.cave_walkers) == flood
            .next_step(bench.walker, bench.cave_walkers),
    );
}

// `next_step`, `s = 46`: `(1, 2)` of R-N8-1

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1309803)]
fn bench_tick_next_step_46_once() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.corridor, 15, 16, bench.from, bench.frozen, bench.unlimited);
    assert!(flood.next_step(bench.far, bench.zero) == bench.far_step);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1508271)]
fn bench_tick_next_step_46_twice() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.corridor, 15, 16, bench.from, bench.frozen, bench.unlimited);
    assert!(flood.next_step(bench.far, bench.zero) == flood.next_step(bench.far, bench.zero));
}

// `next_step` on the ring, `s = 7`: `(0, 8)` of R-N8-5

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1201643)]
fn bench_tick_next_step_ring_once() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.ring_grid, 15, 16, bench.from, bench.zero, bench.unlimited);
    assert!(flood.next_step(bench.ring, bench.zero) == bench.ring_step);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1271385)]
fn bench_tick_next_step_ring_twice() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.ring_grid, 15, 16, bench.from, bench.zero, bench.unlimited);
    assert!(flood.next_step(bench.ring, bench.zero) == flood.next_step(bench.ring, bench.zero));
}

// `distance`, `s = 46`: `(1, 2)` of R-N8-1

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1299850)]
fn bench_tick_distance_46_once() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.corridor, 15, 16, bench.from, bench.frozen, bench.unlimited);
    assert!(flood.distance(bench.far) == bench.far_distance);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1488470)]
fn bench_tick_distance_46_twice() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.corridor, 15, 16, bench.from, bench.frozen, bench.unlimited);
    assert!(flood.distance(bench.far) == flood.distance(bench.far));
}

// `next_step_away`, every candidate blocked, 46 layers scanned: R-N8-6

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1384873)]
fn bench_tick_next_step_away_46_once() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.corridor, 15, 16, bench.from, bench.frozen, bench.unlimited);
    assert!(flood.next_step_away(bench.near, bench.near_blocked) == bench.none);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 1658715)]
fn bench_tick_next_step_away_46_twice() {
    let bench = Inputs::get();
    let flood = Bfs::flood(bench.corridor, 15, 16, bench.from, bench.frozen, bench.unlimited);
    assert!(
        flood
            .next_step_away(bench.near, bench.near_blocked) == flood
            .next_step_away(bench.near, bench.near_blocked),
    );
}
