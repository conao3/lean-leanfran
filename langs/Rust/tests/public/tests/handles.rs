//! Handles (`leanfran::Lean`) and the functions of the generated `lean` module.

use leanfran::{Array, Fin, Lean, List, Local, Nat, Owned};
use leanfran_public_test as p;
use p::lean as h;
use std::sync::{Arc, Mutex};
use std::thread;

fn principal(user: u64) -> p::CalcPrincipal {
    p::CalcPrincipal { org: 1, user }
}

fn seeded(users: u64) -> Lean<p::CalcSnapshot> {
    let mut snap = h::calc_init();
    for user in 0..users {
        let write = Some(p::CalcMemory { user, value: user });
        snap = h::calc_apply(snap, write);
    }
    snap
}

#[test]
fn values_round_trip() {
    assert_eq!(Lean::<u8>::new(200).get(), 200);
    assert_eq!(Lean::<i64>::new(-5).get(), -5);
    assert_eq!(Lean::<u64>::new(u64::MAX).get(), u64::MAX);
    assert_eq!(Lean::<f64>::new(1.5).get(), 1.5);
    assert!(Lean::<bool>::new(true).get());
    assert_eq!(Lean::<char>::new('λ').get(), 'λ');
    assert_eq!(Lean::<String>::new("語".to_string()).get(), "語");
    assert_eq!(Lean::<Nat>::new(Nat::from(7u8)).get(), Nat::from(7u8));
    assert_eq!(Lean::<List<u32>>::new(vec![1, 2, 3]).get(), vec![1, 2, 3]);
    assert_eq!(
        Lean::<Array<String>>::new(vec!["a".to_string()]).get(),
        vec!["a".to_string()]
    );
    assert_eq!(Lean::<Option<u16>>::new(None).get(), None);
    assert_eq!(Lean::<Result<u8, String>>::new(Ok(1)).get(), Ok(1));
    assert_eq!(
        Lean::<Result<u8, String>>::new(Err("e".to_string())).get(),
        Err("e".to_string())
    );
    assert_eq!(
        Lean::<(u8, List<bool>)>::new((1, vec![true])).get(),
        (1, vec![true])
    );
    assert_eq!(Lean::<Fin<10>>::new(9).get(), 9);
    let memory = p::CalcMemory { user: 1, value: 2 };
    assert_eq!(Lean::<p::CalcMemory>::new(memory.clone()).get(), memory);
    assert_eq!(Lean::<p::CalcOp>::new(p::CalcOp::Mul).get(), p::CalcOp::Mul);
    let snap = p::CalcSnapshot {
        memories: vec![memory],
    };
    let handle = Lean::<p::CalcSnapshot>::new(snap.clone());
    assert_eq!(handle.get(), snap);
    assert_eq!(handle.clone().get(), snap);
    assert_eq!(format!("{:?}", Lean::<u8>::new(3)), "Lean(3)");
}

#[test]
fn handle_functions_agree_with_the_value_functions() {
    let mut values = p::calc_init();
    let mut handle = h::calc_init();
    let commands = [
        p::CalcCommand::Set { value: 5 },
        p::CalcCommand::Apply {
            op: p::CalcOp::Add,
            arg: 3,
        },
        p::CalcCommand::Apply {
            op: p::CalcOp::Div,
            arg: 0,
        },
        p::CalcCommand::Get,
    ];
    for user in 0..20 {
        for cmd in &commands {
            let expected = p::calc_transition(principal(user), values.clone(), cmd.clone());
            let got = h::calc_transition(principal(user), &handle, cmd.clone()).get();
            assert_eq!(got, expected);
            if let Ok((write, _)) = expected {
                values = p::calc_apply(values, write.clone());
                handle = h::calc_apply(handle, write);
            }
        }
    }
    assert_eq!(handle.get(), values);
    assert_eq!(values.memories.len(), 20);
}

#[test]
fn arguments_are_values_or_handles() {
    let snap = seeded(3);
    let cmd = Lean::<p::CalcCommand>::new(p::CalcCommand::Get);
    let actor = Lean::<p::CalcPrincipal>::new(principal(2));
    let by_handles = h::calc_transition(&actor, &snap, &cmd).get();
    let by_values = h::calc_transition(principal(2), snap.get(), p::CalcCommand::Get).get();
    assert_eq!(by_handles, by_values);
    assert_eq!(by_handles, Ok((None, p::CalcReply { v: 2 })));
    let moved = h::calc_transition(actor, snap.clone(), cmd).get();
    assert_eq!(moved, by_values);
}

#[test]
fn scalars_strings_and_containers() {
    let sum = h::calc_compute(p::CalcOp::Add, 2, &Lean::<u64>::new(3));
    assert_eq!(sum.get(), Ok(5));
    assert_eq!(
        h::calc_compute(&Lean::<p::CalcOp>::new(p::CalcOp::Sub), 2, 3).get(),
        Err(p::CalcError::Underflow)
    );
    assert!(h::calc_read_only(p::CalcCommand::Get).get());
    let snap = seeded(4);
    assert_eq!(h::calc_users(&snap).get(), vec![0, 1, 2, 3]);
    assert_eq!(h::calc_memory_of(snap.get().memories, 3).get(), 3);
    assert_eq!(h::calc_describe(&snap, "n").get(), "n: 4");
    assert_eq!(h::calc_describe(&snap, String::from("m")).get(), "m: 4");
    let label = Lean::<String>::new("l".to_string());
    assert_eq!(h::calc_describe(&snap, &label).get(), "l: 4");
    assert_eq!(h::mix(1, 2, 3, 4, 5).get(), 15);
    assert_eq!(h::double(Nat::from(21u8)).get(), Nat::from(42u8));
}

#[test]
fn snapshots_share_structure_and_stay_valid() {
    let old = seeded(50);
    let new = h::calc_apply(
        &old,
        Some(p::CalcMemory {
            user: 10,
            value: 99,
        }),
    );
    assert_eq!(h::calc_memory_of(old.get().memories, 10).get(), 10);
    assert_eq!(h::calc_memory_of(new.get().memories, 10).get(), 99);
    drop(old);
    assert_eq!(new.get().memories.len(), 50);
    assert_eq!(new.get().memories[49].value, 49);
}

/// Sizes of the multi-thread tests: (threads, rounds per thread, users).
const THREADS: (u64, u64, u64) = if cfg!(miri) { (3, 6, 8) } else { (8, 200, 64) };

#[test]
fn handles_cross_threads() {
    let (threads, rounds, users) = THREADS;
    let snap = seeded(users);
    let expected = snap.get();
    let workers: Vec<_> = (0..threads)
        .map(|t| {
            let snap = snap.clone();
            let expected = expected.clone();
            thread::spawn(move || {
                let mut local = snap.clone();
                for i in 0..rounds {
                    let user = (t * 7 + i) % users;
                    let cmd = p::CalcCommand::Apply {
                        op: p::CalcOp::Add,
                        arg: 1,
                    };
                    let (write, reply) = h::calc_transition(principal(user), &local, cmd)
                        .get()
                        .expect("no overflow");
                    assert!(reply.v > user);
                    local = h::calc_apply(&local, write);
                    drop(snap.clone());
                }
                assert_eq!(snap.get(), expected);
                local
            })
        })
        .collect();
    let locals: Vec<_> = workers.into_iter().map(|w| w.join().unwrap()).collect();
    assert_eq!(snap.get(), expected);
    for local in &locals {
        assert_eq!(local.get().memories.len(), users as usize);
    }
    let total: u64 = locals
        .iter()
        .map(|l| l.get().memories.iter().map(|m| m.value).sum::<u64>())
        .sum();
    assert_eq!(
        total,
        threads * (users * (users - 1) / 2) + threads * rounds
    );
}

#[test]
fn a_mutex_holds_the_snapshot_for_several_threads() {
    let engine = Arc::new(Mutex::new(h::calc_init()));
    let (threads, rounds, _) = THREADS;
    let workers: Vec<_> = (0..threads)
        .map(|t| {
            let engine = Arc::clone(&engine);
            thread::spawn(move || {
                for i in 0..rounds {
                    let mut snap = engine.lock().unwrap();
                    let cmd = p::CalcCommand::Apply {
                        op: p::CalcOp::Add,
                        arg: 1,
                    };
                    let (write, _) = h::calc_transition(principal(i % 10), &*snap, cmd)
                        .get()
                        .expect("no overflow");
                    *snap = h::calc_apply(&*snap, write);
                    let _ = t;
                }
            })
        })
        .collect();
    for w in workers {
        w.join().unwrap();
    }
    let snap = engine.lock().unwrap().get();
    assert_eq!(snap.memories.len(), rounds.min(10) as usize);
    assert_eq!(
        snap.memories.iter().map(|m| m.value).sum::<u64>(),
        threads * rounds
    );
}

#[test]
fn local_handles_agree_with_the_value_functions() {
    let mut values = p::calc_init();
    let mut local = p::local::calc_init();
    let commands = [
        p::CalcCommand::Set { value: 5 },
        p::CalcCommand::Apply {
            op: p::CalcOp::Mul,
            arg: 3,
        },
        p::CalcCommand::Apply {
            op: p::CalcOp::Div,
            arg: 0,
        },
        p::CalcCommand::Get,
    ];
    for user in 0..20 {
        for cmd in &commands {
            let expected = p::calc_transition(principal(user), values.clone(), cmd.clone());
            let got = p::local::calc_transition(principal(user), &local, cmd.clone()).get();
            assert_eq!(got, expected);
            if let Ok((write, _)) = expected {
                values = p::calc_apply(values, write.clone());
                local = p::local::calc_apply(local, write);
            }
        }
    }
    assert_eq!(local.get(), values);
    assert_eq!(format!("{:?}", Local::<u8>::new(3)), "Local(3)");
}

#[test]
fn a_local_handle_that_is_kept_keeps_its_value() {
    let old = Local::<p::CalcSnapshot>::new(seeded(20).get());
    let write = Some(p::CalcMemory { user: 5, value: 99 });
    let new = p::local::calc_apply(&old, write.clone());
    assert_eq!(old.get().memories[5].value, 5);
    assert_eq!(new.get().memories[5].value, 99);
    let copy = new.clone();
    let newer = p::local::calc_apply(new, Some(p::CalcMemory { user: 5, value: 7 }));
    assert_eq!(copy.get().memories[5].value, 99);
    assert_eq!(newer.get().memories[5].value, 7);
}

#[test]
fn local_and_shared_handles_convert() {
    let local = p::local::calc_apply(
        p::local::calc_init(),
        Some(p::CalcMemory { user: 1, value: 2 }),
    );
    let shared: Lean<p::CalcSnapshot> = local.share();
    let worker = {
        let shared = shared.clone();
        thread::spawn(move || {
            let local = shared.to_local();
            let next = p::local::calc_apply(local, Some(p::CalcMemory { user: 1, value: 3 }));
            assert_eq!(next.get().memories[0].value, 3);
            next.share()
        })
    };
    let from_worker = worker.join().unwrap();
    assert_eq!(shared.get().memories[0].value, 2);
    assert_eq!(from_worker.get().memories[0].value, 3);
    let mixed = h::calc_apply(
        &shared.to_local(),
        Some(p::CalcMemory { user: 9, value: 9 }),
    );
    assert_eq!(mixed.get().memories.len(), 2);
    let back = p::local::calc_apply(&mixed, None);
    assert_eq!(back.get(), mixed.get());
}

/// `Local` is neither `Send` nor `Sync`: with both impls of the trait below applying, the call
/// would be ambiguous and this test would not compile.
#[test]
fn a_local_handle_stays_on_its_thread() {
    trait AmbiguousIfSend<A> {
        fn check() {}
    }
    impl<T: ?Sized> AmbiguousIfSend<()> for T {}
    impl<T: ?Sized + Send> AmbiguousIfSend<u8> for T {}
    trait AmbiguousIfSync<A> {
        fn check() {}
    }
    impl<T: ?Sized> AmbiguousIfSync<()> for T {}
    impl<T: ?Sized + Sync> AmbiguousIfSync<u8> for T {}
    <Local<p::CalcSnapshot> as AmbiguousIfSend<_>>::check();
    <Local<p::CalcSnapshot> as AmbiguousIfSync<_>>::check();
}

#[test]
fn an_array_snapshot_is_written_in_place_or_copied() {
    let rows: Vec<_> = (0..5)
        .map(|user| p::CalcMemory { user, value: user })
        .collect();
    let kept = Local::<p::CalcArraySnapshot>::new(p::CalcArraySnapshot { memories: rows });
    let write = Some(p::CalcMemory { user: 3, value: 30 });
    let copied = p::local::calc_apply_array(&kept, write.clone());
    assert_eq!(kept.get().memories[3].value, 3);
    assert_eq!(copied.get().memories[3].value, 30);
    let moved = p::local::calc_apply_array(copied, Some(p::CalcMemory { user: 9, value: 9 }));
    assert_eq!(moved.get().memories.len(), 6);
    assert_eq!(moved.get().memories[3].value, 30);
    let shared = h::calc_apply_array(kept.share(), write);
    assert_eq!(shared.get().memories[3].value, 30);
}

/// True when the first object of the owned value still has the count of one thread.
fn owned_by_one_thread(owned: &mut Owned<p::CalcSnapshot>) -> bool {
    owned.with(|snap| {
        let single = unsafe { leanfran::runtime::lean_is_st(snap.as_obj()) };
        (snap, single)
    })
}

fn seeded_owned(users: u64) -> Owned<p::CalcSnapshot> {
    Owned::new(seeded(users).get())
}

/// One command on an owned snapshot; true when the list was updated in place (a structure
/// with one field is its field, so the snapshot is the first cell of the list).
fn add_one(owned: &mut Owned<p::CalcSnapshot>, user: u64) -> bool {
    owned.with(|snap| {
        let cmd = p::CalcCommand::Apply {
            op: p::CalcOp::Add,
            arg: 1,
        };
        let (write, _) = p::local::calc_transition(principal(user), &snap, cmd)
            .get()
            .expect("no overflow");
        let before = snap.as_obj();
        let next = p::local::calc_apply(snap, write);
        let in_place = next.as_obj() == before;
        (next, in_place)
    })
}

#[test]
fn an_owned_value_is_updated_in_place() {
    let mut owned = seeded_owned(8);
    assert!(add_one(&mut owned, 0));
    assert!(add_one(&mut owned, 5));
    assert_eq!(owned.get().memories[0].value, 1);
    assert_eq!(owned.get().memories[5].value, 6);
    assert_eq!(format!("{:?}", Owned::<u8>::new(3)), "Owned(3)");
    let length = owned.with(|snap| {
        let length = snap.get().memories.len();
        (snap, length)
    });
    assert_eq!(length, 8);
}

#[test]
fn an_owned_value_moves_between_threads() {
    let (threads, rounds, users) = THREADS;
    let engine = Arc::new(Mutex::new(seeded_owned(users)));
    let workers: Vec<_> = (0..threads)
        .map(|t| {
            let engine = Arc::clone(&engine);
            thread::spawn(move || {
                let mut in_place = 0;
                for i in 0..rounds {
                    let mut owned = engine.lock().unwrap();
                    if add_one(&mut owned, (t + i) % users) {
                        in_place += 1;
                    }
                }
                in_place
            })
        })
        .collect();
    let in_place: u64 = workers.into_iter().map(|w| w.join().unwrap()).sum();
    assert_eq!(in_place, threads * rounds);
    let owned = Arc::try_unwrap(engine).ok().unwrap().into_inner().unwrap();
    let total: u64 = owned.get().memories.iter().map(|m| m.value).sum();
    assert_eq!(total, users * (users - 1) / 2 + threads * rounds);
    let (sender, receiver) = std::sync::mpsc::channel();
    thread::spawn(move || {
        let mut owned = owned;
        assert!(add_one(&mut owned, 0));
        sender.send(owned).unwrap();
    });
    let mut owned = receiver.recv().unwrap();
    assert!(add_one(&mut owned, 0));
    let shared: Lean<p::CalcSnapshot> = owned.share();
    let again = Owned::from(shared.clone());
    assert_eq!(again.get(), shared.get());
}

#[test]
fn a_local_that_outlives_the_closure_is_safe() {
    let (_, rounds, users) = THREADS;
    let mut owned = seeded_owned(users);
    let mut kept = None;
    owned.with(|snap| {
        kept = Some(snap.clone());
        (snap, ())
    });
    let kept = kept.unwrap();
    let expected = kept.get();
    assert!(!owned_by_one_thread(&mut owned));
    assert!(!add_one(&mut owned, 0));
    let mut fresh = seeded_owned(users);
    assert!(owned_by_one_thread(&mut fresh));
    let worker = thread::spawn(move || {
        let mut updated = 0;
        for i in 0..rounds {
            if add_one(&mut owned, i % users) {
                updated += 1;
            }
        }
        (owned, updated)
    });
    for _ in 0..rounds {
        let copy = kept.clone();
        assert_eq!(p::local::calc_users(&copy).get().len(), users as usize);
    }
    let (owned, _) = worker.join().unwrap();
    assert_eq!(kept.get(), expected);
    let total: u64 = owned.get().memories.iter().map(|m| m.value).sum();
    assert_eq!(total, users * (users - 1) / 2 + rounds + 1);
}

#[test]
fn locals_from_elsewhere_are_safe_in_a_closure() {
    let (_, rounds, users) = THREADS;
    let outside = Local::<p::CalcSnapshot>::new(seeded(users).get());
    let mut owned = Owned::<p::CalcSnapshot>::new(p::CalcSnapshot { memories: vec![] });
    let in_place = owned.with(|snap| {
        drop(snap);
        let next = p::local::calc_apply(&outside, None);
        (next, ())
    });
    let _ = in_place;
    assert!(!owned_by_one_thread(&mut owned));
    let mut second = seeded_owned(users);
    let in_result: Local<p::CalcSnapshot> = second.with(|snap| {
        let copy = snap.clone();
        (snap, copy)
    });
    assert!(!owned_by_one_thread(&mut second));
    let mut third = seeded_owned(users);
    let stray = Local::<p::CalcSnapshot>::new(seeded(users).get());
    third.with(|snap| {
        drop(snap);
        (stray, ())
    });
    assert!(!owned_by_one_thread(&mut third));
    let worker = thread::spawn(move || {
        for i in 0..rounds {
            add_one(&mut owned, i % users);
        }
        owned
    });
    for _ in 0..rounds {
        assert_eq!(outside.clone().get().memories.len(), users as usize);
        assert_eq!(in_result.clone().get().memories.len(), users as usize);
    }
    let owned = worker.join().unwrap();
    assert_eq!(outside.get().memories[0].value, 0);
    assert_eq!(owned.get().memories.len(), users as usize);
    drop(second);
    let mut nested_outer = seeded_owned(2);
    let mut nested_inner = seeded_owned(2);
    nested_outer.with(|outer| {
        let inner_users = nested_inner.with(|inner| {
            let merged = p::local::calc_apply(&outer, None);
            drop(merged);
            let count = p::local::calc_users(&inner).get().len();
            (inner, count)
        });
        assert_eq!(inner_users, 2);
        (outer, ())
    });
    assert!(add_one(&mut nested_inner, 0));
    assert_eq!(nested_outer.get().memories.len(), 2);
}

#[test]
fn a_panic_in_the_closure_loses_the_value() {
    let mut owned = seeded_owned(2);
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        owned.with(|snap| -> (Local<p::CalcSnapshot>, ()) {
            let _keep = snap;
            panic!("in the closure")
        })
    }));
    assert!(result.is_err());
    let lost = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| owned.get()));
    assert!(lost.is_err());
    assert_eq!(Local::<u8>::new(1).clone().get(), 1);
}

/// `Owned` is `Send` and not `Sync`.
#[test]
fn an_owned_value_is_send_and_not_sync() {
    fn send<T: Send>() {}
    send::<Owned<p::CalcSnapshot>>();
    trait AmbiguousIfSync<A> {
        fn check() {}
    }
    impl<T: ?Sized> AmbiguousIfSync<()> for T {}
    impl<T: ?Sized + Sync> AmbiguousIfSync<u8> for T {}
    <Owned<p::CalcSnapshot> as AmbiguousIfSync<_>>::check();
}
