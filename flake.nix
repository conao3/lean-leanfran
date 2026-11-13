{
  description = "leanfran: Lean 4 backends for Rust, Python, TypeScript and Clojure";

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
        let
          version = (builtins.fromTOML (builtins.readFile ./Rust/Cargo.toml)).workspace.package.version;
          nodejs = pkgs.nodejs_26;
          pnpm = pkgs.pnpm.override { nodejs-slim = pkgs.nodejs-slim_26; };
          jdk = pkgs.jdk25;
          clojure = pkgs.clojure.override { inherit jdk; };
          vp = pkgs.writeShellApplication {
            name = "vp";
            runtimeInputs = [
              nodejs
              pnpm
            ];
            text = ''
              workspace_root="$PWD"
              while [[ "$workspace_root" != / && ! -f "$workspace_root/pnpm-workspace.yaml" ]]; do
                workspace_root="$(dirname "$workspace_root")"
              done
              if [[ ! -f "$workspace_root/pnpm-workspace.yaml" ]]; then
                echo "vp must run inside the TypeScript workspace" >&2
                exit 1
              fi
              if [[ "''${1:-}" == install ]]; then
                shift
                exec pnpm install "$@"
              fi
              vp_cli="$workspace_root/node_modules/vite-plus/bin/vp"
              if [[ ! -f "$vp_cli" ]]; then
                echo "The local Vite+ CLI is missing; run 'vp install' first" >&2
                exit 1
              fi
              export PATH="${nodejs}/bin:$workspace_root/node_modules/.bin:$PATH"
              exec ${nodejs}/bin/node "$vp_cli" "$@"
            '';
          };
          mkCompiler =
            backend: library: binary:
            pkgs.stdenv.mkDerivation {
              pname = "leanfran-${pkgs.lib.toLower backend}";
              inherit version;
              src = pkgs.lib.fileset.toSource {
                root = ./.;
                fileset = pkgs.lib.fileset.unions [
                  ./lean-toolchain
                  (./. + "/${backend}/lakefile.toml")
                  (./. + "/${backend}/lake-manifest.json")
                  (./. + "/${backend}/Main.lean")
                  (./. + "/${backend}/${library}.lean")
                  (./. + "/${backend}/${library}")
                ];
              };
              postUnpack = ''sourceRoot="$sourceRoot/${backend}"'';
              nativeBuildInputs = [
                pkgs.lean4
                pkgs.makeWrapper
              ];
              buildPhase = ''
                runHook preBuild
                lake build ${binary}
                runHook postBuild
              '';
              installPhase = ''
                runHook preInstall
                install -Dm755 .lake/build/bin/${binary} $out/bin/${binary}
                wrapProgram $out/bin/${binary} --set-default LEAN_SYSROOT ${pkgs.lean4}
                runHook postInstall
              '';
              meta.mainProgram = binary;
            };
          common = [
            pkgs.lean4
            config.treefmt.build.wrapper
          ];
          rustTools = [
            pkgs.elan
            pkgs.rustc
            pkgs.cargo
            pkgs.clippy
            pkgs.rustfmt
            pkgs.cargo-nextest
            pkgs.gcc
            pkgs.lld
            nodejs
            inputs.aeneas.packages.${system}.default
          ];
          pythonTools = [
            pkgs.python314
            pkgs.uv
            pkgs.ruff
            pkgs.gcc
          ];
          typescriptTools = [
            nodejs
            pnpm
            vp
            pkgs.gcc
          ];
          clojureTools = [
            jdk
            clojure
            pkgs.clj-kondo
            pkgs.cljstyle
          ];
          pythonEnv = {
            UV_PYTHON_DOWNLOADS = "never";
            UV_PYTHON = "${pkgs.python314}/bin/python3";
          };
        in
        {
          packages = {
            rust-compiler = mkCompiler "Rust" "LeanRust" "leanfran";
            python = mkCompiler "Python" "LeanPython" "leanfran-python";
            typescript = mkCompiler "TypeScript" "LeanTs" "leanfran-typescript";
            clojure = mkCompiler "Clojure" "LeanClj" "leanfran";
            cargo-leanfran = pkgs.rustPlatform.buildRustPackage {
              pname = "cargo-leanfran";
              inherit version;
              src = pkgs.lib.fileset.toSource {
                root = ./.;
                fileset = pkgs.lib.fileset.unions [
                  ./LICENSE
                  ./Rust/Cargo.toml
                  ./Rust/Cargo.lock
                  ./Rust/README.md
                  ./Rust/crates
                  ./Rust/tests
                  ./Rust/samples
                ];
              };
              postUnpack = ''sourceRoot="$sourceRoot/Rust"'';
              cargoLock.lockFile = ./Rust/Cargo.lock;
              cargoBuildFlags = [
                "-p"
                "cargo-leanfran"
              ];
              doCheck = false;
            };
            rust = pkgs.symlinkJoin {
              name = "leanfran-${version}";
              paths = [
                config.packages.rust-compiler
                config.packages.cargo-leanfran
                inputs.aeneas.packages.${system}.default
              ];
            };
            default = config.packages.rust;
          };
          devShells = {
            default = pkgs.mkShell {
              packages = pkgs.lib.unique (common ++ rustTools ++ pythonTools ++ typescriptTools ++ clojureTools);
              env = pythonEnv;
            };
            rust = pkgs.mkShell { packages = common ++ rustTools; };
            python = pkgs.mkShell {
              packages = common ++ pythonTools;
              env = pythonEnv;
            };
            typescript = pkgs.mkShell { packages = common ++ typescriptTools; };
            clojure = pkgs.mkShell { packages = common ++ clojureTools; };
          };
          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            programs.rustfmt.enable = true;
            programs.rustfmt.edition = "2021";
            programs.ruff-check.enable = true;
            programs.ruff-format.enable = true;
            settings.formatter.ruff-check.excludes = [
              "Python/test-out/*"
              "Python/samples/**/_lean/*"
            ];
            settings.formatter.ruff-format.excludes = [
              "Python/test-out/*"
              "Python/samples/**/_lean/*"
            ];
          };
        };
    };
}
