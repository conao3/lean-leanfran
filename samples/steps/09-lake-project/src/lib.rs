//! Step 9: a lake project compiled to Rust modules (`src/generated/`, committed; building needs
//! no Lean).

pub mod generated;

pub use generated::{stats_mean, stats_median};

#[cfg(test)]
mod tests {
    use super::{stats_mean, stats_median};
    use lean_rust::Nat;

    fn ns(xs: &[u64]) -> Vec<Nat> {
        xs.iter().map(|&x| Nat::from(x)).collect()
    }

    #[test]
    fn mean() {
        assert_eq!(stats_mean::stats_mean(ns(&[1, 2, 6])), Nat::from(3u64));
        assert_eq!(stats_mean::stats_mean(vec![]), Nat::from(0u64));
    }

    #[test]
    fn median() {
        assert_eq!(
            stats_median::stats_median(ns(&[9, 1, 5])),
            Some(Nat::from(5u64))
        );
        assert_eq!(stats_median::stats_median(vec![]), None);
    }
}
