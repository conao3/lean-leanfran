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
