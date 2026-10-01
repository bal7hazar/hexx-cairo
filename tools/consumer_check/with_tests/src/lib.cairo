#[cfg(test)]
mod tests {
    use hexx::HexTrait;

    #[test]
    fn calls_hexx() {
        let a = HexTrait::new(2, -3);
        let b = HexTrait::new(-1, 1);
        assert_eq!(a.unsigned_distance_to(b), 4);
    }
}
