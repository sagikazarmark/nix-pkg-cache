{
  description = "Restate packages for Nix: source builds (cached) and pre-built upstream binaries";

  # Override with `inputs.nix-restate.inputs.nixpkgs.follows = "nixpkgs";` to build against your own nixpkgs.
  # CI populates the restate Cachix cache daily for the locked nixpkgs, the latest nixpkgs-unstable
  # and the latest github:cachix/devenv-nixpkgs/rolling.
  # The lock is not updated automatically: run `nix flake update` to bump it.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  # Only applies when this flake is used directly (e.g. `nix build github:...#restate`),
  # not when it is consumed as an input: add the cache to your own configuration in that case.
  nixConfig = {
    extra-substituters = [ "https://restate.cachix.org" ];
    extra-trusted-public-keys = [ "restate.cachix.org-1:Sa6TxEf6oaKtj3SzyqtuWOY76dQXcfYO0MEXpDjqfSE=" ];
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      # x86_64-darwin is dropped by nixpkgs unstable (26.11+);
      # restate-bin still supports it via the overlay on older nixpkgs.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = f: lib.genAttrs systems f;
    in
    {
      overlays.default = final: prev: {
        restate-bin = final.callPackage ./pkgs/restate-bin { };
      };

      packages = forAllSystems (
        system:
        let
          # Restate is BUSL-1.1 (unfree).
          # Setting allowUnfree does not change derivation hashes,
          # so cached outputs match what consumers get from the same nixpkgs revision.
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          # Source build from nixpkgs
          restate = pkgs.restate;

          # Pre-built upstream binaries from GitHub releases
          restate-bin = pkgs.callPackage ./pkgs/restate-bin { };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
