//! Unpublished fixture: a minimal Starknet contract that consumes `hexx`, so that
//! `scripts/bytecode_size.py` can track class size against the Starknet limits (plan, R-11).
//! Not part of what `hexx` publishes; depends on `starknet`, which `hexx` itself never does.

#[starknet::contract]
pub mod HexxSink {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn mirrored_hexx_version(self: @ContractState) -> felt252 {
        hexx::mirrored_hexx_version()
    }
}
