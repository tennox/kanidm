{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11"; # or use /nixos-unstable to get latest packages, but maybe less caching
    systems.url = "github:nix-systems/default"; # (i) allows overriding systems easily, see https://github.com/nix-systems/nix-systems#consumer-usage
    devenv.url = "github:cachix/devenv";
    rust-overlay.url = "github:oxalica/rust-overlay"; # TODO: replace with fenix?
    crane.url = "github:ipetkov/crane";
    fenix = {
      # needed for devenv's languages.rust
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, systems, flake-parts, nixpkgs, rust-overlay, crane, devenv, ... }: (
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = (import systems);
      imports = [
        inputs.devenv.flakeModule
      ];

      # perSystem docs: https://flake.parts/module-arguments.html#persystem-module-parameters
      perSystem = { config, self', inputs', pkgs, system, ... }: (
        let
          rustToolchain = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {
            targets = [
              "x86_64-unknown-linux-musl"
              # "wasm-unknown-unknown"
            ];
          });
          craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

          my-crate = craneLib.buildPackage {
            # https://crane.dev/getting-started.html
            src = craneLib.cleanCargoSource (craneLib.path ./.);

            # CARGO_BUILD_TARGET = "wasm-unknown-unknown";
            CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
            CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
            # Add extra inputs here or any other derivation settings
            # doCheck = true;
            # buildInputs = [];
            # nativeBuildInputs = [];
          };
        in
        {
          # Per-system attributes can be defined here. The self' and inputs'
          # module parameters provide easy access to attributes of the same
          # system.
          checks = {
            inherit my-crate;
          };

          packages.default = my-crate;

          devenv.shells.default = {
            # Useful packages for nix, so I put them here instead of devenv.nix
            packages = with pkgs; [
              nixpkgs-fmt
              nil
            ];
          } // (import ./devenv.nix { inherit pkgs; });
        }
      );
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.

      };
    }
  );
}
