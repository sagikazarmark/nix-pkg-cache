# nix-restate

Nix packages for [Restate](https://restate.dev), with a binary cache.

| Package       | Description                                                                                     |
| ------------- | ----------------------------------------------------------------------------------------------- |
| `restate`     | Source build of the [nixpkgs package](https://search.nixos.org/packages?query=restate) (cached) |
| `restate-bin` | Pre-built binaries from [GitHub releases](https://github.com/restatedev/restate/releases)       |

Both packages provide `restate`, `restate-server` and `restatectl`.

`restate` carries build fixes on top of nixpkgs while they are pending upstream ([NixOS/nixpkgs#574205](https://github.com/NixOS/nixpkgs/pull/574205)).
They are only applied when the nixpkgs in use still needs them; otherwise the package is identical to nixpkgs' `restate`.

Building Restate from source takes a long time (and occasionally breaks in nixpkgs).
`restate-bin` is an escape hatch: it downloads the official release binaries and usually tracks upstream releases more closely.

Supported systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`.

> [!NOTE]
> Restate is licensed under [BUSL-1.1](https://github.com/restatedev/restate/blob/main/LICENSE), which Nix considers unfree.
> The packages exposed by this flake allow it, so no extra configuration is needed;
> the overlay and the plain nixpkgs package require `allowUnfree` (or an `allowUnfreePredicate`).

## Binary cache

CI builds `restate` and `restate-bin` daily and pushes them to [restate.cachix.org](https://restate.cachix.org) for:

- the nixpkgs revision locked in this flake
- the latest [`nixpkgs-unstable`](https://github.com/NixOS/nixpkgs/tree/nixpkgs-unstable)
- the latest [`devenv-nixpkgs/rolling`](https://github.com/cachix/devenv-nixpkgs/tree/rolling)

The cache is keyed on the nixpkgs revision: you only get cache hits if your nixpkgs matches one of those
(e.g. by using this flake's locked nixpkgs, or by following a recent `nixpkgs-unstable` or devenv `rolling`).

Using the cache:

- **Cachix CLI:** `cachix use restate`
- **devenv:** `cachix.pull = [ "restate" ];` in `devenv.nix`
- **NixOS:**

    ```nix
    {
      nix.settings = {
        extra-substituters = [ "https://restate.cachix.org" ];
        extra-trusted-public-keys = [ "restate.cachix.org-1:Sa6TxEf6oaKtj3SzyqtuWOY76dQXcfYO0MEXpDjqfSE=" ];
      };
    }
    ```

- **This flake, used directly** (e.g. `nix run github:sagikazarmark/nix-restate#restate`):
  the flake offers the cache via `nixConfig`; accept it when prompted (or pass `--accept-flake-config`).

> [!IMPORTANT]
> The flake's `nixConfig` only applies when the flake is used directly.
> It is ignored when this flake is an input of another flake or of devenv: configure the cache yourself in that case.

## Usage

### CLI

```shell
nix run github:sagikazarmark/nix-restate#restate-bin -- --version
nix shell github:sagikazarmark/nix-restate#restate-bin --command restate-server
nix profile install github:sagikazarmark/nix-restate#restate-bin
```

### Flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-restate = {
      url = "github:sagikazarmark/nix-restate";
      # Optional: build against your own nixpkgs (see "Binary cache" above)
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, nix-restate, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ nix-restate.packages.${system}.restate-bin ];
      };
    };
}
```

### Overlay

The overlay adds `restate-bin` to your package set (`restate` is already part of nixpkgs):

```nix
import nixpkgs {
  inherit system;
  overlays = [ nix-restate.overlays.default ];
  config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "restate-bin" ];
}
```

The overlay also works with nixpkgs releases that still support `x86_64-darwin`.

### devenv

```yaml
# devenv.yaml
inputs:
    nixpkgs:
        url: github:cachix/devenv-nixpkgs/rolling
    nix-restate:
        url: github:sagikazarmark/nix-restate
        inputs:
            nixpkgs:
                follows: nixpkgs
```

```nix
# devenv.nix
{ pkgs, inputs, ... }:

{
  cachix.pull = [ "restate" ];

  packages = [
    inputs.nix-restate.packages.${pkgs.stdenv.system}.restate-bin
    # or the source build:
    # inputs.nix-restate.packages.${pkgs.stdenv.system}.restate
  ];
}
```

## Updates

- `restate-bin` is checked daily for new upstream releases; updates are opened as pull requests
  (hashes come from the `sha256.sum` file published with each release).
  To update manually: `./pkgs/restate-bin/update.sh [VERSION]`.
- `restate` follows nixpkgs. The locked nixpkgs revision is not updated automatically;
  bump it with `nix flake update`.

## License

The Nix code in this repository is licensed under the [MIT License](LICENSE).
Restate itself is licensed under [BUSL-1.1](https://github.com/restatedev/restate/blob/main/LICENSE).
