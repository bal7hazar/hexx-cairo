//! `hexx`: the port of [`hexx`](https://github.com/ManevilleF/hexx) 0.25.0 to Cairo, extended
//! with a bitmap board engine for Starknet (plan: `docs/research/LIB-03-porting-plan.md` of
//! `bal7hazar/hexx-cairo`).
//!
//! Placeholder crate: milestone L-M1 (LIB-05) is the first task that ports a mirror item or an
//! extension. This file exists so that every tool of the workspace (format, lint, build, test,
//! parity, gas, class size, packaging) has something to run on; see `README.md`,
//! `docs/API_PARITY.md`, `docs/EXTENSIONS.md`.

/// The version of `hexx` this package mirrors, until the port carries its own numbered items.
/// Mirrors nothing in particular: a placeholder public item (plan, LIB-04 scope).
pub fn mirrored_hexx_version() -> felt252 {
    '0.25.0'
}

#[cfg(test)]
mod tests {
    use super::mirrored_hexx_version;

    #[test]
    #[available_gas(l2_gas: 14406)]
    fn test_mirrored_hexx_version() {
        assert(mirrored_hexx_version() == '0.25.0', 'wrong hexx version');
    }
}
