{
  description = "leanfran: a Lean IR -> Python backend, a Lean embedding for Python, and pydantic models for Lean types";

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
          packages.leanfran = pkgs.stdenv.mkDerivation {
            pname = "leanfran-python";
            version = "0.6.0";
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./lakefile.toml
                ./lean-toolchain
                ./Main.lean
                ./LeanPython.lean
                ./LeanPython
              ];
            };
            nativeBuildInputs = [
              pkgs.lean4
              pkgs.makeWrapper
            ];
            buildPhase = ''
              export HOME=$TMPDIR
              lake build leanfran-python
            '';
            installPhase = ''
              install -Dm755 .lake/build/bin/leanfran-python $out/bin/leanfran-python
              wrapProgram $out/bin/leanfran-python --set-default LEAN_SYSROOT ${pkgs.lean4}
            '';
            meta.mainProgram = "leanfran-python";
          };

          packages.default = config.packages.leanfran;

          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            programs.ruff-check.enable = true;
            programs.ruff-format.enable = true;
            settings.formatter.ruff-check.excludes = [
              "test-out/*"
              "samples/**/_lean/*"
            ];
            settings.formatter.ruff-format.excludes = [
              "test-out/*"
              "samples/**/_lean/*"
            ];
          };

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.lean4
              pkgs.python314
              pkgs.uv
              pkgs.ruff
              pkgs.gcc
              config.treefmt.build.wrapper
            ];
            env.UV_PYTHON_DOWNLOADS = "never";
            env.UV_PYTHON = "${pkgs.python314}/bin/python3";
          };
        };
    };
}
