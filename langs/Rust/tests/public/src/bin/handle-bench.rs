//! Times one command (`transition`, then `apply`) of the kernel `LeanRustTest.Public.Calc`
//! for tenants of several sizes: with the snapshot as a Rust value converted on every call,
//! and with the snapshot kept in a handle.
//!
//! `cargo run --release -p leanfran-public-test --bin handle-bench`

use leanfran::{Lean, List, Local, Owned};
use leanfran_public_test as p;
use std::hint::black_box;
use std::time::Instant;

fn commands(users: u64, count: usize) -> Vec<(p::CalcPrincipal, p::CalcCommand)> {
    let mut state = 0x9e37_79b9_7f4a_7c15_u64;
    let mut next = move || {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        state
    };
    (0..count)
        .map(|_| {
            let actor = p::CalcPrincipal {
                org: 1,
                user: next() % users,
            };
            let cmd = match next() % 4 {
                0 => p::CalcCommand::Set {
                    value: next() % 1000,
                },
                1 => p::CalcCommand::Apply {
                    op: p::CalcOp::Add,
                    arg: next() % 1000,
                },
                2 => p::CalcCommand::Apply {
                    op: p::CalcOp::Div,
                    arg: 1 + next() % 9,
                },
                _ => p::CalcCommand::Get,
            };
            (actor, cmd)
        })
        .collect()
}

/// One command on an owned snapshot.
fn command(
    owned: &mut Owned<p::CalcSnapshot>,
    actor: &p::CalcPrincipal,
    cmd: &p::CalcCommand,
) -> Option<p::CalcReply> {
    owned.with(
        |snap| match p::local::calc_transition(actor.clone(), &snap, cmd.clone()).get() {
            Ok((write, reply)) => (p::local::calc_apply(snap, write), Some(reply)),
            Err(_) => (snap, None),
        },
    )
}

fn per_op(label: &str, users: u64, count: usize, start: Instant) {
    let nanos = start.elapsed().as_nanos() as f64 / count as f64;
    println!("{label:<44} users={users:<6} {nanos:>10.0} ns/command");
}

fn main() {
    for users in [1_u64, 100, 10_000] {
        let count = if users == 10_000 { 2_000 } else { 200_000 };
        let cmds = commands(users, count);
        let mut snap = p::calc_init();
        for user in 0..users {
            snap = p::calc_apply(snap, Some(p::CalcMemory { user, value: 1 }));
        }
        let seeded = snap.clone();

        let start = Instant::now();
        for (actor, cmd) in &cmds {
            if let Ok((write, reply)) = p::calc_transition(actor.clone(), snap.clone(), cmd.clone())
            {
                black_box(reply);
                snap = p::calc_apply(snap, write);
            }
        }
        per_op("values: transition + apply", users, count, start);

        let mut handle = Lean::<p::CalcSnapshot>::new(seeded.clone());
        let start = Instant::now();
        for (actor, cmd) in &cmds {
            if let Ok((write, reply)) =
                p::lean::calc_transition(actor.clone(), &handle, cmd.clone()).get()
            {
                black_box(reply);
                handle = p::lean::calc_apply(handle, write);
            }
        }
        per_op("handle: transition + apply", users, count, start);
        assert_eq!(handle.get(), snap);

        let mut local = Local::<p::CalcSnapshot>::new(seeded.clone());
        let start = Instant::now();
        for (actor, cmd) in &cmds {
            if let Ok((write, reply)) =
                p::local::calc_transition(actor.clone(), &local, cmd.clone()).get()
            {
                black_box(reply);
                local = p::local::calc_apply(local, write);
            }
        }
        per_op("local: transition + apply", users, count, start);
        assert_eq!(local.get(), snap);

        let mut owned = Owned::<p::CalcSnapshot>::new(seeded.clone());
        let start = Instant::now();
        for (actor, cmd) in &cmds {
            black_box(command(&mut owned, actor, cmd));
        }
        per_op("owned: transition + apply", users, count, start);
        assert_eq!(owned.get(), snap);

        let engine = std::sync::Mutex::new(Owned::<p::CalcSnapshot>::new(seeded.clone()));
        let start = Instant::now();
        for (actor, cmd) in &cmds {
            black_box(command(&mut engine.lock().unwrap(), actor, cmd));
        }
        per_op("owned in a Mutex: transition + apply", users, count, start);

        let start = Instant::now();
        std::thread::scope(|s| {
            for part in cmds.chunks(cmds.len() / 4) {
                let engine = &engine;
                s.spawn(move || {
                    for (actor, cmd) in part {
                        black_box(command(&mut engine.lock().unwrap(), actor, cmd));
                    }
                });
            }
        });
        per_op("owned in a Mutex, 4 threads", users, count, start);

        let start = Instant::now();
        for (actor, cmd) in &cmds {
            black_box(
                p::local::calc_transition(actor.clone(), &local, cmd.clone())
                    .get()
                    .is_ok(),
            );
        }
        per_op("  local: transition", users, count, start);

        let start = Instant::now();
        for (actor, cmd) in &cmds {
            black_box(p::local::calc_transition(
                actor.clone(),
                &local,
                cmd.clone(),
            ));
        }
        per_op(
            "  local: transition, result not converted",
            users,
            count,
            start,
        );

        let actor_handle = Local::<p::CalcPrincipal>::new(p::CalcPrincipal {
            org: 1,
            user: users / 2,
        });
        let cmd_handle = Local::<p::CalcCommand>::new(p::CalcCommand::Get);
        let start = Instant::now();
        for _ in 0..count {
            black_box(p::local::calc_transition(
                &actor_handle,
                &local,
                &cmd_handle,
            ));
        }
        per_op(
            "  local: transition (get), no conversion",
            users,
            count,
            start,
        );

        let list = Local::<List<p::CalcMemory>>::new(local.get().memories);
        let start = Instant::now();
        for _ in 0..count {
            black_box(p::local::calc_memory_of(&list, users / 2));
        }
        per_op(
            "  local: memory_of (scan to the middle)",
            users,
            count,
            start,
        );

        let mid = Some(p::CalcMemory {
            user: users / 2,
            value: 7,
        });
        let start = Instant::now();
        for _ in 0..count {
            local = p::local::calc_apply(local, mid.clone());
        }
        per_op("  local: apply (write in the middle)", users, count, start);

        let first = Some(p::CalcMemory { user: 0, value: 7 });
        let start = Instant::now();
        for _ in 0..count {
            local = p::local::calc_apply(local, first.clone());
        }
        per_op("  local: apply (write at the front)", users, count, start);

        let start = Instant::now();
        for _ in 0..count {
            black_box(local.clone());
        }
        per_op("  local: clone", users, count, start);

        let mut array = Local::<p::CalcArraySnapshot>::new(p::CalcArraySnapshot {
            memories: seeded.memories.clone(),
        });
        let rows = Local::<leanfran::Array<p::CalcMemory>>::new(seeded.memories.clone());
        let start = Instant::now();
        for _ in 0..count {
            black_box(p::local::calc_memory_of_array(&rows, users / 2));
        }
        per_op("  local, Array: scan to the middle", users, count, start);

        let start = Instant::now();
        for _ in 0..count {
            array = p::local::calc_apply_array(array, mid.clone());
        }
        per_op(
            "  local, Array: apply (write in the middle)",
            users,
            count,
            start,
        );
        assert_eq!(array.get().memories[(users / 2) as usize].value, 7);

        let start = Instant::now();
        for (actor, cmd) in &cmds {
            black_box(
                p::lean::calc_transition(actor.clone(), &handle, cmd.clone())
                    .get()
                    .is_ok(),
            );
        }
        per_op("  handle: transition", users, count, start);

        let write = Some(p::CalcMemory {
            user: users / 2,
            value: 7,
        });
        let start = Instant::now();
        for _ in 0..count {
            handle = p::lean::calc_apply(handle, write.clone());
        }
        per_op("  handle: apply (write in the middle)", users, count, start);

        let start = Instant::now();
        for _ in 0..count {
            black_box(handle.clone());
        }
        per_op("  handle: clone", users, count, start);

        let rounds = count / 20;
        let start = Instant::now();
        for _ in 0..rounds {
            black_box(Lean::<p::CalcSnapshot>::new(black_box(handle.get())));
        }
        per_op("  handle: get + new", users, rounds, start);

        let start = Instant::now();
        for _ in 0..count {
            black_box(seeded.clone());
        }
        per_op("  values: clone the snapshot", users, count, start);
    }
}
