//! Handles of Lean values: [`Lean<L>`] keeps a value as the Lean object, without converting it
//! to a Rust value.
//!
//! The type argument `L` names the Lean type by the Rust type of the public functions
//! (`u64`, `String`, `Option<T>`, `Result<T, E>`, `(A, B)`, generated structs and enums); a
//! Lean `List α` is [`List<T>`] and an `Array α` is [`Array<T>`], since both are `Vec<T>` in
//! Rust. [`LeanRepr::Value`] is the Rust value of `L`.
//!
//! The object of a handle is shared between threads: creating the handle marks every object
//! reachable from it with [`lean_mark_mt`], so that its reference counts are updated atomically.
//! Lean functions that receive such an object build new objects instead of updating it in place.
//!
//! [`Local<L>`] is the handle that stays on the thread that made it: its objects keep the
//! reference counts of one thread, so a Lean function that receives the only reference to an
//! object updates it in place.

use crate::marshal::*;
use crate::object::*;
use core::fmt;
use core::marker::PhantomData;

/// A Rust type that names a Lean type whose values a [`Lean`] handle can hold.
///
/// # Safety
///
/// `to_obj` must return an owned object of the Lean type and `from_obj` must read one without
/// taking ownership; the type must be data (no closures, thunks, tasks or references), since
/// handles of it are shared between threads. Generated modules implement it for their types.
pub unsafe trait LeanRepr {
    /// The Rust value of the Lean type.
    type Value;

    /// The owned boxed object of `value`.
    ///
    /// # Safety
    ///
    /// The result is an owned Lean object that must be released with `lean_dec` or passed on.
    #[doc(hidden)]
    unsafe fn to_obj(value: Self::Value) -> Obj;

    /// The Rust value of the borrowed boxed object `o`.
    ///
    /// # Safety
    ///
    /// `o` must be a valid Lean value of the type `Self` names.
    #[doc(hidden)]
    unsafe fn from_obj(o: Obj) -> Self::Value;
}

/// The Lean type `List α`; its Rust value is `Vec<T::Value>`.
pub struct List<T>(PhantomData<fn() -> T>);

/// The Lean type `Array α`; its Rust value is `Vec<T::Value>`.
pub struct Array<T>(PhantomData<fn() -> T>);

/// The Lean type `Fin N`; its Rust value is `usize`.
pub struct Fin<const N: u64>;

/// A Lean value of the type named by `L`, kept as the Lean object.
///
/// `Lean::new` converts a Rust value once and `get` converts it back. The functions of the
/// `lean` module of a generated module take handles and return them without converting.
/// Cloning a handle adds a reference to the same object.
pub struct Lean<L: LeanRepr> {
    obj: Obj,
    ty: PhantomData<fn() -> L>,
}

// SAFETY: the object and everything it reaches is shared between threads (`lean_mark_mt`) or
// persistent, so its reference counts are atomic or never written, and such objects are never
// updated in place. The types `L` are data: no closures, thunks, tasks or references.
unsafe impl<L: LeanRepr> Send for Lean<L> {}
unsafe impl<L: LeanRepr> Sync for Lean<L> {}

impl<L: LeanRepr> Lean<L> {
    /// The handle of the Lean value of `value`.
    pub fn new(value: L::Value) -> Self {
        unsafe { Self::from_owned(L::to_obj(value)) }
    }

    /// The Rust value of the handle.
    pub fn get(&self) -> L::Value {
        unsafe { L::from_obj(self.obj) }
    }

    /// The handle that owns `obj`.
    ///
    /// # Safety
    ///
    /// `obj` must be an owned Lean value of the type `L` names, and no other thread may reach
    /// the objects under it that are still owned by one thread.
    #[doc(hidden)]
    pub unsafe fn from_owned(obj: Obj) -> Self {
        lean_mark_mt(obj);
        Lean {
            obj,
            ty: PhantomData,
        }
    }

    /// The object of the handle, borrowed.
    #[doc(hidden)]
    pub fn as_obj(&self) -> Obj {
        self.obj
    }
}

impl<L: LeanRepr> Lean<L> {
    /// A handle of the same object for this thread. The object stays shared between threads,
    /// so Lean functions do not update it in place.
    pub fn to_local(&self) -> Local<L> {
        unsafe { lean_inc(self.obj) };
        Local {
            obj: self.obj,
            ty: PhantomData,
            thread: PhantomData,
        }
    }
}

impl<L: LeanRepr> Clone for Lean<L> {
    fn clone(&self) -> Self {
        unsafe { lean_inc(self.obj) };
        Lean {
            obj: self.obj,
            ty: PhantomData,
        }
    }
}

impl<L: LeanRepr> Drop for Lean<L> {
    fn drop(&mut self) {
        unsafe { lean_dec(self.obj) };
    }
}

impl<L: LeanRepr> fmt::Debug for Lean<L>
where
    L::Value: fmt::Debug,
{
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_tuple("Lean").field(&self.get()).finish()
    }
}

/// A Lean value of the type named by `L`, kept as the Lean object on the thread that made it.
///
/// The functions of the `local` module of a generated module return this handle. Its objects
/// keep the reference counts of one thread: passing the only handle of a value by value lets
/// the Lean function update the value in place, where a [`Lean`] handle makes it build new
/// objects. A `Local` cannot be sent to or shared with another thread; [`Local::share`] turns
/// it into a [`Lean`] that can.
///
/// ```compile_fail,E0277
/// let local = leanfran_runtime::Local::<u8>::new(1);
/// std::thread::spawn(move || drop(local));
/// ```
///
/// ```compile_fail,E0277
/// let local = leanfran_runtime::Local::<u8>::new(1);
/// std::thread::scope(|s| {
///     s.spawn(|| local.get());
/// });
/// ```
pub struct Local<L: LeanRepr> {
    obj: Obj,
    ty: PhantomData<fn() -> L>,
    thread: PhantomData<*mut ()>,
}

impl<L: LeanRepr> Local<L> {
    /// The handle of the Lean value of `value`.
    pub fn new(value: L::Value) -> Self {
        unsafe { Self::from_owned(L::to_obj(value)) }
    }

    /// The Rust value of the handle.
    pub fn get(&self) -> L::Value {
        unsafe { L::from_obj(self.obj) }
    }

    /// The handle that can be sent to and shared with other threads. It marks the objects of
    /// the value as shared, at a cost in proportion to the objects not yet shared.
    pub fn share(self) -> Lean<L> {
        let obj = self.obj;
        core::mem::forget(self);
        unsafe { Lean::from_owned(obj) }
    }

    /// The handle that owns `obj`.
    ///
    /// # Safety
    ///
    /// `obj` must be an owned Lean value of the type `L` names, made on this thread.
    #[doc(hidden)]
    pub unsafe fn from_owned(obj: Obj) -> Self {
        Local {
            obj,
            ty: PhantomData,
            thread: PhantomData,
        }
    }

    /// The object of the handle, borrowed.
    #[doc(hidden)]
    pub fn as_obj(&self) -> Obj {
        self.obj
    }
}

impl<L: LeanRepr> Clone for Local<L> {
    fn clone(&self) -> Self {
        unsafe { lean_inc(self.obj) };
        Local {
            obj: self.obj,
            ty: PhantomData,
            thread: PhantomData,
        }
    }
}

impl<L: LeanRepr> Drop for Local<L> {
    fn drop(&mut self) {
        unsafe { lean_dec(self.obj) };
    }
}

impl<L: LeanRepr> fmt::Debug for Local<L>
where
    L::Value: fmt::Debug,
{
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_tuple("Local").field(&self.get()).finish()
    }
}

/// An argument of a function of the `lean` or `local` module of a generated module: the Rust
/// value of `L` (converted for the call), a `&Lean<L>`, a `Lean<L>`, a `&Local<L>` or a
/// `Local<L>`.
///
/// # Safety
///
/// `into_obj` must return an owned object of the Lean type `L` names.
pub unsafe trait IntoLean<L: LeanRepr> {
    /// The owned boxed object of the argument.
    ///
    /// # Safety
    ///
    /// The result is an owned Lean object that must be released with `lean_dec` or passed on.
    #[doc(hidden)]
    unsafe fn into_obj(self) -> Obj;
}

unsafe impl<L: LeanRepr> IntoLean<L> for Lean<L> {
    unsafe fn into_obj(self) -> Obj {
        let obj = self.obj;
        core::mem::forget(self);
        obj
    }
}

unsafe impl<L: LeanRepr> IntoLean<L> for &Lean<L> {
    unsafe fn into_obj(self) -> Obj {
        lean_inc(self.obj);
        self.obj
    }
}

unsafe impl<L: LeanRepr> IntoLean<L> for Local<L> {
    unsafe fn into_obj(self) -> Obj {
        let obj = self.obj;
        core::mem::forget(self);
        obj
    }
}

unsafe impl<L: LeanRepr> IntoLean<L> for &Local<L> {
    unsafe fn into_obj(self) -> Obj {
        lean_inc(self.obj);
        self.obj
    }
}

macro_rules! prim_repr {
    ($($t:ty),*) => {$(
        unsafe impl LeanRepr for $t {
            type Value = $t;
            unsafe fn to_obj(value: $t) -> Obj {
                ToLean::to_lean(value)
            }
            unsafe fn from_obj(o: Obj) -> $t {
                <$t as FromLean>::from_lean(o)
            }
        }
        unsafe impl IntoLean<$t> for $t {
            unsafe fn into_obj(self) -> Obj {
                ToLean::to_lean(self)
            }
        }
    )*};
}

prim_repr!(
    Nat,
    Int,
    bool,
    char,
    String,
    u8,
    u16,
    u32,
    u64,
    usize,
    i8,
    i16,
    i32,
    i64,
    isize,
    f64,
    f32,
    ()
);

unsafe impl IntoLean<String> for &str {
    unsafe fn into_obj(self) -> Obj {
        ToLean::to_lean(self)
    }
}

unsafe impl IntoLean<String> for &String {
    unsafe fn into_obj(self) -> Obj {
        ToLean::to_lean(self.as_str())
    }
}

unsafe impl<T: LeanRepr> LeanRepr for List<T> {
    type Value = Vec<T::Value>;
    unsafe fn to_obj(value: Self::Value) -> Obj {
        list_to_lean(value, |v| T::to_obj(v))
    }
    unsafe fn from_obj(o: Obj) -> Self::Value {
        list_from_lean(o, |v| T::from_obj(v))
    }
}

unsafe impl<T: LeanRepr> IntoLean<List<T>> for Vec<T::Value> {
    unsafe fn into_obj(self) -> Obj {
        List::<T>::to_obj(self)
    }
}

unsafe impl<T: LeanRepr> LeanRepr for Array<T> {
    type Value = Vec<T::Value>;
    unsafe fn to_obj(value: Self::Value) -> Obj {
        array_to_lean(value, |v| T::to_obj(v))
    }
    unsafe fn from_obj(o: Obj) -> Self::Value {
        array_from_lean(o, |v| T::from_obj(v))
    }
}

unsafe impl<T: LeanRepr> IntoLean<Array<T>> for Vec<T::Value> {
    unsafe fn into_obj(self) -> Obj {
        Array::<T>::to_obj(self)
    }
}

unsafe impl<T: LeanRepr> LeanRepr for Option<T> {
    type Value = Option<T::Value>;
    unsafe fn to_obj(value: Self::Value) -> Obj {
        option_to_lean(value, |v| T::to_obj(v))
    }
    unsafe fn from_obj(o: Obj) -> Self::Value {
        option_from_lean(o, |v| T::from_obj(v))
    }
}

unsafe impl<T: LeanRepr> IntoLean<Option<T>> for Option<T::Value> {
    unsafe fn into_obj(self) -> Obj {
        Option::<T>::to_obj(self)
    }
}

unsafe impl<T: LeanRepr, E: LeanRepr> LeanRepr for Result<T, E> {
    type Value = Result<T::Value, E::Value>;
    unsafe fn to_obj(value: Self::Value) -> Obj {
        except_to_lean(value, |v| E::to_obj(v), |v| T::to_obj(v))
    }
    unsafe fn from_obj(o: Obj) -> Self::Value {
        except_from_lean(o, |v| E::from_obj(v), |v| T::from_obj(v))
    }
}

unsafe impl<T: LeanRepr, E: LeanRepr> IntoLean<Result<T, E>> for Result<T::Value, E::Value> {
    unsafe fn into_obj(self) -> Obj {
        Result::<T, E>::to_obj(self)
    }
}

unsafe impl<A: LeanRepr, B: LeanRepr> LeanRepr for (A, B) {
    type Value = (A::Value, B::Value);
    unsafe fn to_obj(value: Self::Value) -> Obj {
        prod_to_lean(value, |v| A::to_obj(v), |v| B::to_obj(v))
    }
    unsafe fn from_obj(o: Obj) -> Self::Value {
        prod_from_lean(o, |v| A::from_obj(v), |v| B::from_obj(v))
    }
}

unsafe impl<A: LeanRepr, B: LeanRepr> IntoLean<(A, B)> for (A::Value, B::Value) {
    unsafe fn into_obj(self) -> Obj {
        <(A, B)>::to_obj(self)
    }
}

unsafe impl<const N: u64> LeanRepr for Fin<N> {
    type Value = usize;
    unsafe fn to_obj(value: usize) -> Obj {
        fin_to_lean(value, N as usize)
    }
    unsafe fn from_obj(o: Obj) -> usize {
        fin_from_lean(o)
    }
}

unsafe impl<const N: u64> IntoLean<Fin<N>> for usize {
    unsafe fn into_obj(self) -> Obj {
        Fin::<N>::to_obj(self)
    }
}
