//! Runs the generated `IO` functions; `tests/api.rs` checks the output.

use leanfran_public_test as p;

fn main() {
    let n = p::hello("Rust").unwrap();
    println!("returned {n}");
    println!("counter {}", p::counter().unwrap());
    match p::failing(3u64.into()) {
        Ok(()) => println!("no error"),
        Err(e) => println!("error {:?}: {e}", e.kind()),
    }
    p::failing(0u64.into()).unwrap();
    println!("done");
}
