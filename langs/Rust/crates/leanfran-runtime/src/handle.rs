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
use core::cell::Cell;
use core::fmt;
use core::marker::PhantomData;

/// A Rust type that names a Lean type whose values a [`Lean`] handle can hold.
///
/// # Safety
///
/// `to_obj` must return an owned object of the Lean type that nothing else refers to, and
/// `from_obj` must read one without taking ownership; the type must be data (no closures, thunks, tasks or references), since
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
        unsafe {
            lean_inc(self.obj);
            Local::from_owned(self.obj)
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
    /// The scope of [`Owned::with`] that made the handle, or 0.
    scope: u64,
    ty: PhantomData<fn() -> L>,
    thread: PhantomData<*mut ()>,
}

thread_local! {
    /// The scope of `Owned::with` that is running on this thread (0: none), the number of its
    /// handles that are alive, and the last scope number used.
    static SCOPE: Cell<u64> = const { Cell::new(0) };
    static SCOPE_LIVE: Cell<usize> = const { Cell::new(0) };
    static SCOPE_LAST: Cell<u64> = const { Cell::new(0) };
}

/// A handle made in the running scope.
#[inline]
fn enter_scope() -> u64 {
    let scope = SCOPE.get();
    if scope != 0 {
        SCOPE_LIVE.set(SCOPE_LIVE.get() + 1);
    }
    scope
}

/// A handle of `scope` goes away. Only handles of the running scope are counted, so the count
/// of a scope is never below the number of its handles.
#[inline]
fn leave_scope(scope: u64) {
    if scope != 0 && scope == SCOPE.get() {
        SCOPE_LIVE.set(SCOPE_LIVE.get() - 1);
    }
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
        unsafe { Lean::from_owned(self.release()) }
    }

    /// The object of a handle of another scope than the running one is shared with handles
    /// that the running scope does not count: it is marked as shared between threads, which
    /// is what keeps moving an [`Owned`] to another thread sound.
    #[inline]
    fn settle(&self) {
        if self.scope != SCOPE.get() {
            unsafe { lean_mark_mt(self.obj) };
        }
    }

    /// The owned object of the handle, which goes away.
    #[inline]
    fn release(self) -> Obj {
        self.settle();
        leave_scope(self.scope);
        let obj = self.obj;
        core::mem::forget(self);
        obj
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
            scope: enter_scope(),
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
        self.settle();
        unsafe {
            lean_inc(self.obj);
            Local::from_owned(self.obj)
        }
    }
}

impl<L: LeanRepr> Drop for Local<L> {
    fn drop(&mut self) {
        leave_scope(self.scope);
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
        self.release()
    }
}

unsafe impl<L: LeanRepr> IntoLean<L> for &Local<L> {
    unsafe fn into_obj(self) -> Obj {
        self.settle();
        lean_inc(self.obj);
        self.obj
    }
}

/// A Lean value of the type named by `L` with one owner, which can move between threads and
/// is still updated in place.
///
/// The objects of the value keep the reference counts of one thread, like those of a
/// [`Local`]. That is sound because nothing else refers to them while the `Owned` is at rest:
/// it is made from a Rust value or from a [`Lean`], it cannot be cloned or shared (`Send`, not
/// `Sync`), and [`Owned::with`] lends the value as a `Local` for the time of a closure only.
/// A `Local` that outlives the closure is detected when the closure returns, and what it
/// shares with the value is then marked as shared between threads, which costs the in-place
/// updates of those objects and nothing else.
///
/// ```
/// use leanfran_runtime::{List, Local, Owned};
/// use std::sync::Mutex;
///
/// let numbers = Mutex::new(Owned::<List<u32>>::new(vec![1, 2, 3]));
/// std::thread::scope(|s| {
///     s.spawn(|| {
///         let length = numbers.lock().unwrap().with(|list: Local<List<u32>>| {
///             let length = list.get().len();
///             (list, length)
///         });
///         assert_eq!(length, 3);
///     });
/// });
/// ```
///
/// ```compile_fail,E0277
/// let owned = leanfran_runtime::Owned::<u8>::new(1);
/// std::thread::scope(|s| {
///     s.spawn(|| owned.get());
/// });
/// ```
pub struct Owned<L: LeanRepr> {
    /// Null while `with` runs and after its closure panicked.
    obj: Obj,
    ty: PhantomData<fn() -> L>,
}

// SAFETY: at rest, the objects of the value that are owned by one thread are reachable from
// this handle only (see `with`), so the thread that holds the handle is the only one that
// reads or writes them and their reference counts. Blocks freed on another thread than the
// one that allocated them join the small object pool of the freeing thread.
unsafe impl<L: LeanRepr> Send for Owned<L> {}

impl<L: LeanRepr> Owned<L> {
    /// The handle of the Lean value of `value`.
    pub fn new(value: L::Value) -> Self {
        Owned {
            obj: unsafe { L::to_obj(value) },
            ty: PhantomData,
        }
    }

    fn obj(&self) -> Obj {
        assert!(
            !self.obj.is_null(),
            "the Owned value was lost: a closure of `with` panicked"
        );
        self.obj
    }

    /// The Rust value of the handle.
    pub fn get(&self) -> L::Value {
        unsafe { L::from_obj(self.obj()) }
    }

    /// Lends the value to `f` as a [`Local`] and takes the `Local` that `f` returns as the new
    /// value. Passing the `Local` by value to a function of the `local` module of a generated
    /// module updates the value in place.
    ///
    /// Every other `Local` made in `f` should be gone when `f` returns. If one is still alive
    /// (kept in a captured variable or in the result), or if `f` returns a `Local` it got from
    /// elsewhere, the new value is marked as shared between threads.
    pub fn with<R>(&mut self, f: impl FnOnce(Local<L>) -> (Local<L>, R)) -> R {
        struct Restore(u64, usize);
        impl Drop for Restore {
            fn drop(&mut self) {
                SCOPE.set(self.0);
                SCOPE_LIVE.set(self.1);
            }
        }
        let obj = core::mem::replace(&mut self.obj, core::ptr::null_mut());
        assert!(
            !obj.is_null(),
            "the Owned value was lost: a closure of `with` panicked"
        );
        let scope = SCOPE_LAST.get() + 1;
        SCOPE_LAST.set(scope);
        let restore = Restore(SCOPE.replace(scope), SCOPE_LIVE.replace(0));
        let (value, result) = f(unsafe { Local::from_owned(obj) });
        let alone = value.scope == scope && SCOPE_LIVE.get() == 1;
        let obj = value.obj;
        core::mem::forget(value);
        if !alone {
            unsafe { lean_mark_mt(obj) };
        }
        drop(restore);
        self.obj = obj;
        result
    }

    /// The handle that can be shared between threads.
    pub fn share(self) -> Lean<L> {
        let obj = self.obj();
        core::mem::forget(self);
        unsafe { Lean::from_owned(obj) }
    }
}

impl<L: LeanRepr> From<Lean<L>> for Owned<L> {
    /// The shared value with one more owner. Its objects stay shared; the objects that
    /// functions build from it are owned.
    fn from(value: Lean<L>) -> Self {
        let obj = value.obj;
        core::mem::forget(value);
        Owned {
            obj,
            ty: PhantomData,
        }
    }
}

impl<L: LeanRepr> Drop for Owned<L> {
    fn drop(&mut self) {
        if !self.obj.is_null() {
            unsafe { lean_dec(self.obj) };
        }
    }
}

impl<L: LeanRepr> fmt::Debug for Owned<L>
where
    L::Value: fmt::Debug,
{
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_tuple("Owned").field(&self.get()).finish()
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
