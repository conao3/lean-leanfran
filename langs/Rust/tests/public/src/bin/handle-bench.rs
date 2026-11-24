//! Times one command (`transition`, then `apply`) of the kernel `LeanRustTest.Public.Calc`
//! for tenants of several sizes: with the snapshot as a Rust value converted on every call,
//! and with the snapshot kept in a handle.
//!
//! `cargo run --release -p leanfran-public-test --bin handle-bench`

use leanfran::Lean;
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
