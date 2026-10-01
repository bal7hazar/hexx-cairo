use hexx::HexTrait;

/// Calls a public item of `hexx` so that the build compiles it from the registry package.
pub fn distance_from_origin(x: i32, y: i32) -> u32 {
    HexTrait::new(x, y).ulength()
}
