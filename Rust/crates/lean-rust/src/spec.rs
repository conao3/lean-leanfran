//! Arguments of specs.

use crate::{Int, Nat};

/// A Rust value as the argument of a spec: the spec is a public function generated from Lean,
/// whose parameters are owned values. `&[T]` becomes `Vec<T>`, `&str` becomes `String` and `&T`
/// becomes `T`; other values are cloned.
pub trait SpecArg {
    type Spec;
    fn spec_arg(&self) -> Self::Spec;
}

impl<T: Clone> SpecArg for [T] {
    type Spec = Vec<T>;
    fn spec_arg(&self) -> Vec<T> {
        self.to_vec()
    }
}

impl SpecArg for str {
    type Spec = String;
    fn spec_arg(&self) -> String {
        self.to_string()
    }
}

impl<T: SpecArg + ?Sized> SpecArg for &T {
    type Spec = T::Spec;
    fn spec_arg(&self) -> T::Spec {
        (**self).spec_arg()
    }
}

impl<T: SpecArg + ?Sized> SpecArg for &mut T {
    type Spec = T::Spec;
    fn spec_arg(&self) -> T::Spec {
        (**self).spec_arg()
    }
}

macro_rules! spec_by_clone {
    ($($t:ty),*) => {$(
        impl SpecArg for $t {
            type Spec = $t;
            fn spec_arg(&self) -> $t {
                self.clone()
            }
        }
    )*};
}

spec_by_clone!(
    u8,
    u16,
    u32,
    u64,
    u128,
    usize,
    i8,
    i16,
    i32,
    i64,
    i128,
    isize,
    bool,
    char,
    f32,
    f64,
    (),
    String,
    Nat,
    Int
);

impl<T: Clone> SpecArg for Vec<T> {
    type Spec = Vec<T>;
    fn spec_arg(&self) -> Vec<T> {
        self.clone()
    }
}

impl<T: Clone> SpecArg for Option<T> {
    type Spec = Option<T>;
    fn spec_arg(&self) -> Option<T> {
        self.clone()
    }
}

impl<T: Clone, const N: usize> SpecArg for [T; N] {
    type Spec = [T; N];
    fn spec_arg(&self) -> [T; N] {
        self.clone()
    }
}

impl<A: Clone, B: Clone> SpecArg for (A, B) {
    type Spec = (A, B);
    fn spec_arg(&self) -> (A, B) {
        self.clone()
    }
}

impl<A: Clone, B: Clone, C: Clone> SpecArg for (A, B, C) {
    type Spec = (A, B, C);
    fn spec_arg(&self) -> (A, B, C) {
        self.clone()
    }
}
