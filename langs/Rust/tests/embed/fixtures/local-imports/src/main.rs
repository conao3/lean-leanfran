leanfran::lean! {
    #[lean(imports = ["Support"])]
    mod values;
    r#"
    def value (n : UInt32) : UInt32 := n + supportValue
    "#
}

leanfran::lean! {
    #[lean(uses = [crate::values])]
    mod policy;
    r#"
    def answer (n : UInt32) : UInt32 := value n
    "#
}

fn main() {
    println!("{}", policy::answer(10) + external::stdlib_value());
}

leanfran::lean! {
    #[lean(imports = ["Std"])]
    mod external;
    r#"
    def stdlib_value : UInt32 := 0
    "#
}
