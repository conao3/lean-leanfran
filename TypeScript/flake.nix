{
  description = "leanfran: a Lean IR -> TypeScript backend with a typed runtime";

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
          nodejs = pkgs.nodejs_26;
          pnpm = pkgs.pnpm.override { nodejs-slim = pkgs.nodejs-slim_26; };

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
                printf '%s\n' "vp must run inside the leanfran workspace" >&2
                exit 1
              fi

              if [[ "''${1:-}" == install ]]; then
                shift
                exec pnpm install "$@"
              fi

              vp_cli="$workspace_root/node_modules/vite-plus/bin/vp"
              if [[ ! -f "$vp_cli" ]]; then
                printf '%s\n' "The local Vite+ CLI is missing; run 'vp install' first" >&2
                exit 1
              fi

              export PATH="${nodejs}/bin:$workspace_root/node_modules/.bin:$PATH"
              exec ${nodejs}/bin/node "$vp_cli" "$@"
            '';
          };
        in
        {
          packages.leanfran-typescript = pkgs.stdenv.mkDerivation {
            pname = "leanfran-typescript";
            version = "0.5.0";
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./lakefile.toml
                ./lean-toolchain
                ./Main.lean
                ./LeanTs.lean
                ./LeanTs
              ];
            };
            nativeBuildInputs = [
              pkgs.lean4
              pkgs.makeWrapper
            ];
            buildPhase = ''
              export HOME=$TMPDIR
              lake build leanfran-typescript
            '';
            installPhase = ''
              install -Dm755 .lake/build/bin/leanfran-typescript $out/bin/leanfran-typescript
              wrapProgram $out/bin/leanfran-typescript --set-default LEAN_SYSROOT ${pkgs.lean4}
            '';
            meta.mainProgram = "leanfran-typescript";
          };

          packages.default = config.packages.leanfran-typescript;

          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            settings.formatter.oxfmt = {
              command = "${vp}/bin/vp";
              options = [ "fmt" ];
              includes = [
                "*.ts"
                "*.mjs"
                "*.json"
                "*.yaml"
                "*.yml"
              ];
              excludes = [
                "lake-manifest.json"
                "**/_lean/**"
                "**/.leanfran/**"
              ];
            };
          };

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.lean4
              nodejs
              pnpm
              vp
              pkgs.gcc
              config.treefmt.build.wrapper
            ];
          };
        };
    };
}
