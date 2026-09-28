//! Equality tests of the `board` extension against the published `origami_hexmap` 1.8.0 it takes
//! over (plan, §5.4). Depends on `origami_hexmap` from the registry: never published alongside
//! `hexx`, which must not carry this dependency (`Scarb.toml`, `publish = false`).
//!
//! Milestone L-M1 (LIB-05) fills this crate with one equality test per taken-over function. For
//! now it proves the dependency resolves and the package builds and tests.

#[cfg(test)]
mod tests {
    use origami_hexmap::{HexMap, HexMapTrait};

    #[test]
    #[available_gas(l2_gas: 17934)]
    fn test_origami_hexmap_new_empty() {
        let map: HexMap = HexMapTrait::new_empty(5, 5, 'hexx-cairo');
        assert(map.width == 5, 'wrong width');
        assert(map.height == 5, 'wrong height');
    }
}
