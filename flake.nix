{
  description = "leanfran: Lean 4 backends for Rust, Python, TypeScript, Clojure, PHP, and Go";

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
          version = (builtins.fromTOML (builtins.readFile ./langs/Rust/Cargo.toml)).workspace.package.version;
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
          phpTools = php: [
            php
            php.packages.composer
            (pkgs.phpstan.override { inherit php; })
            (pkgs.phpunit.override { inherit php; })
            pkgs.mago
            pkgs.gcc
          ];
          goTools =
            go:
            [
              go
              pkgs.gofumpt
              pkgs.golangci-lint
              pkgs.go-tools
              pkgs.gopls
              pkgs.python3
              pkgs.gnumake
            ]
            ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.gcc;
          cTools = [
            pkgs.go
            pkgs.clang-tools
            pkgs.cmake
            pkgs.pkg-config
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            pkgs.gcc
            pkgs.clang
          ];
          pythonEnv = {
            UV_PYTHON_DOWNLOADS = "never";
            UV_PYTHON = "${pkgs.python314}/bin/python3";
          };
        in
        {
          packages = {
            leanfran = pkgs.stdenv.mkDerivation {
              pname = "leanfran";
              inherit version;
              src = pkgs.lib.fileset.toSource {
                root = ./.;
                fileset = pkgs.lib.fileset.unions [
                  ./lean-toolchain
                  ./lakefile.toml
                  ./lake-manifest.json
                  ./Main.lean
                  ./Leanfran
                  ./langs/Rust/LeanRust.lean
                  ./langs/Rust/LeanRust
                  ./langs/Python/LeanPython.lean
                  ./langs/Python/LeanPython
                  ./langs/Python/src/leanfran/lean/LeanPythonLib
                  ./langs/TypeScript/LeanTs.lean
                  ./langs/TypeScript/LeanTs
                  ./langs/Clojure/LeanClj.lean
                  ./langs/Clojure/LeanClj
                  ./langs/PHP/LeanPhp.lean
                  ./langs/PHP/LeanPhp
                  ./langs/PHP/src/lean/LeanPhpLib
                  ./langs/Go/LeanGo.lean
                  ./langs/Go/LeanGo
                  ./langs/Go/lean/LeanGoLib
                  ./langs/C/LeanC.lean
                  ./langs/C/LeanC
                  ./langs/C/support
                  ./langs/C/lean/LeanfranC
                  ./langs/C/lean/LeanCLib
                ];
              };
              nativeBuildInputs = [
                pkgs.lean4
                pkgs.makeWrapper
              ];
              buildPhase = ''
                runHook preBuild
                lake build leanfran
                runHook postBuild
              '';
              installPhase = ''
                runHook preInstall
                install -Dm755 .lake/build/bin/leanfran $out/bin/leanfran
                wrapProgram $out/bin/leanfran --set-default LEAN_SYSROOT ${pkgs.lean4}
                install -Dm644 langs/Go/lean/LeanGoLib/Go.lean $out/share/leanfran-go/LeanGoLib/Go.lean
                install -Dm644 -t $out/share/leanfran-c langs/C/support/leanfran.h langs/C/support/leanfran.c
                runHook postInstall
              '';
              meta.mainProgram = "leanfran";
            };
            cargo-leanfran = pkgs.rustPlatform.buildRustPackage {
              pname = "cargo-leanfran";
              inherit version;
              src = pkgs.lib.fileset.toSource {
                root = ./.;
                fileset = pkgs.lib.fileset.unions [
                  ./LICENSE
                  ./langs/Rust/Cargo.toml
                  ./langs/Rust/Cargo.lock
                  ./langs/Rust/README.md
                  ./langs/Rust/crates
                  ./langs/Rust/tests
                  ./langs/Rust/samples
                ];
              };
              postUnpack = ''sourceRoot="$sourceRoot/langs/Rust"'';
              cargoLock.lockFile = ./langs/Rust/Cargo.lock;
              cargoBuildFlags = [
                "-p"
                "cargo-leanfran"
              ];
              doCheck = false;
            };
            rust = pkgs.symlinkJoin {
              name = "leanfran-${version}";
              paths = [
                config.packages.leanfran
                config.packages.cargo-leanfran
                inputs.aeneas.packages.${system}.default
              ];
            };
            default = config.packages.leanfran;
          };
          devShells = {
            default = pkgs.mkShell {
              packages = pkgs.lib.unique (
                common
                ++ rustTools
                ++ pythonTools
                ++ typescriptTools
                ++ clojureTools
                ++ phpTools pkgs.php84
                ++ goTools pkgs.go
                ++ cTools
              );
              env = pythonEnv;
            };
            rust = pkgs.mkShell { packages = common ++ rustTools; };
            python = pkgs.mkShell {
              packages = common ++ pythonTools;
              env = pythonEnv;
            };
            typescript = pkgs.mkShell { packages = common ++ typescriptTools; };
            clojure = pkgs.mkShell { packages = common ++ clojureTools; };
            php = pkgs.mkShell { packages = common ++ phpTools pkgs.php84; };
            php85 = pkgs.mkShell { packages = common ++ phpTools pkgs.php85; };
            go = pkgs.mkShell { packages = common ++ goTools pkgs.go; };
            go126 = pkgs.mkShell { packages = common ++ goTools pkgs.go_1_26; };
            c = pkgs.mkShell { packages = common ++ cTools; };
          };
          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            programs.rustfmt.enable = true;
            programs.rustfmt.edition = "2021";
            programs.ruff-check.enable = true;
            programs.ruff-format.enable = true;
            settings.formatter.ruff-check.excludes = [
              "langs/Python/test-out/*"
              "langs/Python/samples/**/_lean/*"
              "langs/Python/tests/embed/**/_lean/*"
            ];
            settings.formatter.ruff-format.excludes = [
              "langs/Python/test-out/*"
              "langs/Python/samples/**/_lean/*"
              "langs/Python/tests/embed/**/_lean/*"
            ];
          };
        };
    };
}
