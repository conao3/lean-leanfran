//! Prints the most frequent words of standard input, counted by the Lean code in `lib.rs`.

use std::io::Read;
use std::process::ExitCode;
use word_count::count;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let limit: u64 = match args
        .iter()
        .map(String::as_str)
        .collect::<Vec<_>>()
        .as_slice()
    {
        ["text", "list-top-words"] => 10,
        ["text", "list-top-words", "--limit", n] => match n.parse() {
            Ok(n) => n,
            Err(_) => {
                eprintln!("word-count: --limit must be a number: {n}");
                return ExitCode::from(252);
            }
        },
        _ => {
            eprintln!("usage: word-count text list-top-words [--limit <n>] < text");
            return ExitCode::from(252);
        }
    };
    let mut text = String::new();
    if let Err(e) = std::io::stdin().read_to_string(&mut text) {
        eprintln!("word-count: {e}");
        return ExitCode::from(255);
    }
    for (word, n) in count::top_words(limit.into(), &text) {
        println!("{n}\t{word}");
    }
    ExitCode::SUCCESS
}
