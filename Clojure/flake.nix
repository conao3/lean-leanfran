{
  description = "leanfran: a Lean IR -> Clojure backend and a Lean embedding for Clojure";

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
        let
          jdk = pkgs.jdk25;
          clojure = pkgs.clojure.override { inherit jdk; };
        in
        {
          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
          };

          packages.default = pkgs.stdenv.mkDerivation {
            pname = "leanfran";
            version = "0.6.0";
            src = ./.;
            nativeBuildInputs = [ pkgs.lean4 ];
            buildPhase = ''
              runHook preBuild
              lake build leanfran
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              install -Dm755 .lake/build/bin/leanfran $out/bin/leanfran
              runHook postInstall
            '';
            meta.mainProgram = "leanfran";
          };

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.lean4
              jdk
              clojure
              pkgs.clj-kondo
              pkgs.cljstyle
              config.treefmt.build.wrapper
            ];
          };
        };
    };
}
