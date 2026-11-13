//! Runs `LeanRustTest.Io.run` through the generated Rust (diff test against `oracle-io`).

use leanfran_runtime as rt;

mod generated {
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/../../test-out/io.rs"));
}

fn main() {
    unsafe {
        let r = generated::l_LeanRustTest_Io_run();
        if !rt::lean_io_result_is_ok(r) {
            rt::lean_io_result_show_error(r);
            std::process::exit(1);
        }
        rt::lean_dec(r);
    }
}
