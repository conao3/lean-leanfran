# C samples

Run each sample inside `nix develop .#c` from the repository root, with `leanfran` on PATH. Install it with `nix profile install 'github:conao3/lean-leanfran#leanfran'`.

- [pricing](pricing/) generates a C API from a Lake library and links it with pkg-config. In `langs/C/samples/pricing`, run `lake build`, then `lake env leanfran --lang c generate --module-name Pricing.Core --roots Pricing.total --prefix pricing --out-dir out` and `lake env leanfran --lang c build --out-dir out`. Compile `main.c` with `pkg-config --cflags --libs out/pricing.pc`. The program prints `3600`.
- [verified-clamp](verified-clamp/) embeds a Lean block in `src/clamp.c`, proves that the C function `clamp` refines it in `lean/Proofs/Clamp.lean`, and calls both from `src/main.c`. In `langs/C/samples/verified-clamp`, run `leanfran --lang c check --require proved`, `make leanfran-model-test`, and `make run`.

`maint/C/test-samples.sh` runs both samples in `make check BACKENDS=C`.
