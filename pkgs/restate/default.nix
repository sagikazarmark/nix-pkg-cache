# Build fixes for nixpkgs' restate.
#
# TODO: remove once NixOS/nixpkgs#574205 has reached the nixpkgs revisions built in CI
# (nixpkgs-unstable and devenv-nixpkgs rolling).
#
# The fixes are only applied when the given nixpkgs still needs them:
# once nixpkgs is fixed, this returns its restate package unchanged,
# so the derivation (and the cache) matches plain nixpkgs again.
{
  lib,
  stdenv,
  darwin,
  restate,
}:

let
  oldFlags = lib.filter (flag: flag != "") (
    lib.splitString " " (restate.drvAttrs.NIX_CFLAGS_COMPILE or "")
  );

  newFlags =
    if stdenv.cc.isGNU then
      # krb5-src: glibc's const-preserving strchr trips its -Werror=discarded-qualifiers
      lib.unique (oldFlags ++ [ "-Wno-error=discarded-qualifiers" ])
    else
      # Clang already defaults to gnu17 and rejects -std=gnu17 for C++ sources
      lib.remove "-std=gnu17" oldFlags;

  # krb5-src needs mig to generate its KCM RPC stubs
  extraNativeBuildInputs = lib.optionals (
    stdenv.hostPlatform.isDarwin && !lib.elem darwin.bootstrap_cmds restate.nativeBuildInputs
  ) [ darwin.bootstrap_cmds ];

  needsFix = newFlags != oldFlags || extraNativeBuildInputs != [ ];
in
if !needsFix then
  restate
else
  restate.overrideAttrs (old: {
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = toString newFlags;
    };
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ extraNativeBuildInputs;
  })
