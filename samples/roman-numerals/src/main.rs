//! Converts between numbers and Roman numerals with the Rust code generated from
//! `lean/Roman.lean` (`src/generated/`, committed; building needs no Lean).

mod generated;

use generated::roman;
use std::process::ExitCode;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args
        .iter()
        .map(String::as_str)
        .collect::<Vec<_>>()
        .as_slice()
    {
        ["to-roman", n] => match n.parse::<u64>() {
            Ok(n) => {
                println!("{}", roman::to_roman(n.into()));
                ExitCode::SUCCESS
            }
            Err(_) => {
                eprintln!("roman-numerals: not a number: {n}");
                ExitCode::from(252)
            }
        },
        ["from-roman", s] => match roman::from_roman(s) {
            Some(n) => {
                println!("{n}");
                ExitCode::SUCCESS
            }
            None => {
                eprintln!("roman-numerals: not a Roman numeral: {s}");
                ExitCode::from(254)
            }
        },
        _ => {
            eprintln!("usage: roman-numerals to-roman <number> | from-roman <numeral>");
            ExitCode::from(252)
        }
    }
}
