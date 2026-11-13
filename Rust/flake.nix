{
  description = "leanfran: a Lean IR -> Rust backend, a Lean embedding for Rust, and Lean verification of Rust functions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    aeneas.url = "github:AeneasVerif/aeneas/c5eb4a28cef65e0aa27743105308243e535a2a2b";
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
        {
          pkgs,
          config,
          system,
          ...
        }:
        {
          packages.leanfran = pkgs.stdenv.mkDerivation {
            pname = "leanfran";
            version = "0.5.0";
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
              lake build leanfran
            '';
            installPhase = ''
              install -Dm755 .lake/build/bin/leanfran $out/bin/leanfran
              wrapProgram $out/bin/leanfran --set-default LEAN_SYSROOT ${pkgs.lean4}
            '';
          };

          packages.cargo-leanfran = pkgs.rustPlatform.buildRustPackage {
            pname = "cargo-leanfran";
            version = "0.5.0";
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./Cargo.toml
                ./Cargo.lock
                ./crates
                ./tests
                ./samples
              ];
            };
            cargoLock.lockFile = ./Cargo.lock;
            cargoBuildFlags = [
              "-p"
              "cargo-leanfran"
            ];
            doCheck = false;
          };

          packages.default = pkgs.symlinkJoin {
            name = "leanfran-0.5.0";
            paths = [
              config.packages.leanfran
              config.packages.cargo-leanfran
              inputs.aeneas.packages.${system}.default
            ];
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
              pkgs.lld
              pkgs.nodejs
              inputs.aeneas.packages.${system}.default
              config.treefmt.build.wrapper
            ];
          };
        };
    };
}
