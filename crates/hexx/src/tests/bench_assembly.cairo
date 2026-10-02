//! Gas benchmarks of N-3, the assembly of the window (plan §6.4, §7), on the worst case of the
//! domain: 4 chunks, `ox = oy = 7`, odd chunk row. Each figure is the difference between a test
//! that calls twice and one that calls once, the method of the game's SPK-7 (whose baseline
//! difference was not stable); the second call takes other inputs of the same shape, so that it
//! is not the same computation. The figures are in `docs/GAS.md` and the task's report.
//!
//! The inputs of both calls come from one opaque call (`Inputs::get`) in both tests, so that the
//! difference holds the second call only. Without it the calls on constant inputs are folded at
//! compile time (a first run measured `origin` at the cost of an empty test).

// Internal imports

use hexx::board::assembly::{AssemblyTrait, Origin};

// Constants

const T0: felt252 = 0x5a3c1f0e7d2b4968a1c3e5f7092b4d6f8a1c3e5f7092b4d6f8a1c3e5f7092b4;
const T1: felt252 = 0x2f7e4d1c9b8a7f6e5d4c3b2a19087f6e5d4c3b2a19087f6e5d4c3b2a1908;
const T2: felt252 = 0x6c5b4a39281706f5e4d3c2b1a09f8e7d6c5b4a39281706f5e4d3c2b1a09f8;
const T3: felt252 = 0x13579bdf02468ace13579bdf02468ace13579bdf02468ace13579bdf02468a;
const O0: felt252 = 0x1111111111111111111111111111111111111111111111111111111111111;
const O1: felt252 = 0x2222222222222222222222222222222222222222222222222222222222222;
const O2: felt252 = 0x4444444444444444444444444444444444444444444444444444444444444;
const O3: felt252 = 0x0888888888888888888888888888888888888888888888888888888888888;

/// The inputs of both calls.
#[derive(Copy, Drop)]
struct Bench {
    terrain: [Option<felt252>; 4],
    occupied: [Option<felt252>; 4],
    /// `ox = oy = 7` on an odd chunk row: the worst case.
    origin: Origin,
    /// `ox = 0`: two chunks.
    origin_two: Origin,
    /// The adventurers of `origin` (the worst case of its branches, `x = 0`, even `y`).
    first: (u8, u8),
    second: (u8, u8),
    /// Tiles of the window of `origin`.
    near: (u8, u8),
    far: (u8, u8),
}

#[generate_trait]
impl Inputs of InputsTrait {
    /// The inputs, opaque to the compiler (`#[inline(never)]`, as the `black_box` of the house:
    /// `simba`, `nalgebra`).
    #[inline(never)]
    fn get() -> Bench {
        Bench {
            terrain: [Option::Some(T0), Option::Some(T1), Option::Some(T2), Option::Some(T3)],
            occupied: [Option::Some(O0), Option::Some(O1), Option::Some(O2), Option::Some(O3)],
            origin: Origin { cx: 3, cy: 5, ox: 7, oy: 7 },
            origin_two: Origin { cx: 3, cy: 5, ox: 0, oy: 7 },
            first: (0, 0),
            second: (15, 30),
            near: (60, 90),
            far: (61, 89),
        }
    }
}

// `assemble`, one layer, 4 chunks

#[test]
#[inline(never)]
#[available_gas(l2_gas: 53061)]
fn bench_assembly_assemble_once() {
    let bench = Inputs::get();
    let Origin { cx: _, cy: _, ox, oy } = bench.origin;
    assert!(AssemblyTrait::assemble(bench.terrain, ox, oy, true) != 0);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 94467)]
fn bench_assembly_assemble_twice() {
    let bench = Inputs::get();
    let Origin { cx: _, cy: _, ox, oy } = bench.origin;
    assert!(AssemblyTrait::assemble(bench.terrain, ox, oy, true) != 0);
    assert!(AssemblyTrait::assemble(bench.occupied, ox, oy, true) != 0);
}

// `window`, two layers, 4 chunks

#[test]
#[inline(never)]
#[available_gas(l2_gas: 79101)]
fn bench_assembly_window_once() {
    let bench = Inputs::get();
    let (map, occupied) = AssemblyTrait::window(bench.terrain, bench.occupied, @bench.origin, 0);
    assert!(map.grid != 0 && occupied != 0);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 146547)]
fn bench_assembly_window_twice() {
    let bench = Inputs::get();
    let (map, occupied) = AssemblyTrait::window(bench.terrain, bench.occupied, @bench.origin, 0);
    assert!(map.grid != 0 && occupied != 0);
    let (map, occupied) = AssemblyTrait::window(bench.occupied, bench.terrain, @bench.origin, 1);
    assert!(map.grid != 0 && occupied != 0);
}

// `window`, two layers, 2 chunks

#[test]
#[inline(never)]
#[available_gas(l2_gas: 79101)]
fn bench_assembly_window_two_chunks_once() {
    let bench = Inputs::get();
    let (map, occupied) = AssemblyTrait::window(
        bench.terrain, bench.occupied, @bench.origin_two, 0,
    );
    assert!(map.grid != 0 && occupied != 0);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 146547)]
fn bench_assembly_window_two_chunks_twice() {
    let bench = Inputs::get();
    let (map, occupied) = AssemblyTrait::window(
        bench.terrain, bench.occupied, @bench.origin_two, 0,
    );
    assert!(map.grid != 0 && occupied != 0);
    let (map, occupied) = AssemblyTrait::window(
        bench.occupied, bench.terrain, @bench.origin_two, 1,
    );
    assert!(map.grid != 0 && occupied != 0);
}

// `origin` and `local`

#[test]
#[inline(never)]
#[available_gas(l2_gas: 14532)]
fn bench_assembly_origin_once() {
    let bench = Inputs::get();
    let (x, y) = bench.first;
    assert!(AssemblyTrait::origin(x, y).ox == 8);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 18344)]
fn bench_assembly_origin_twice() {
    let bench = Inputs::get();
    let (x, y) = bench.first;
    assert!(AssemblyTrait::origin(x, y).ox == 8);
    let (x, y) = bench.second;
    assert!(AssemblyTrait::origin(x, y).ox == 8);
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 13955)]
fn bench_assembly_local_once() {
    let bench = Inputs::get();
    let (x, y) = bench.near;
    assert!(bench.origin.local(x, y) == Option::Some(128));
}

#[test]
#[inline(never)]
#[available_gas(l2_gas: 17189)]
fn bench_assembly_local_twice() {
    let bench = Inputs::get();
    let (x, y) = bench.near;
    assert!(bench.origin.local(x, y) == Option::Some(128));
    let (x, y) = bench.far;
    assert!(bench.origin.local(x, y) == Option::Some(114));
}
