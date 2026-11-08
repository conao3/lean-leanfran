{
  description = "lean-rs: a Lean IR -> Rust backend, a Lean embedding for Rust, and Lean verification of Rust functions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.treefmt-nix.flakeModule ];

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, config, ... }:
        {
          packages.default = pkgs.stdenv.mkDerivation {
            pname = "lean-rust";
            version = "0.1.0";
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./lakefile.toml
                ./lake-manifest.json
                ./lean-toolchain
                ./Main.lean
                ./LeanRust.lean
                ./LeanRust
              ];
            };
            nativeBuildInputs = [
              pkgs.lean4
              pkgs.makeWrapper
            ];
            buildPhase = ''
              export HOME=$TMPDIR
              lake build lean-rust
            '';
            installPhase = ''
              install -Dm755 .lake/build/bin/lean-rust $out/bin/lean-rust
              wrapProgram $out/bin/lean-rust --set-default LEAN_SYSROOT ${pkgs.lean4}
            '';
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            programs.rustfmt.enable = true;
            programs.rustfmt.edition = "2021";
          };

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.elan
              pkgs.rustc
              pkgs.cargo
              pkgs.clippy
              pkgs.rustfmt
              pkgs.cargo-nextest
              pkgs.gcc
              config.treefmt.build.wrapper
            ];
          };
        };
    };
}
