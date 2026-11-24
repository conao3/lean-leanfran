//! Handles (`leanfran::Lean`) and the functions of the generated `lean` module.

use leanfran::{Array, Fin, Lean, List, Nat};
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
