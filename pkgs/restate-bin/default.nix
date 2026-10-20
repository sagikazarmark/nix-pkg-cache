{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  sources = lib.importJSON ./sources.json;

  # nix system => upstream target (keep in sync with update.sh)
  targets = {
    aarch64-darwin = "aarch64-apple-darwin";
    aarch64-linux = "aarch64-unknown-linux-musl";
    x86_64-darwin = "x86_64-apple-darwin";
    x86_64-linux = "x86_64-unknown-linux-musl";
  };

  inherit (stdenvNoCC.hostPlatform) system;
  target = targets.${system} or (throw "restate-bin: unsupported system ${system}");

  # archive name => binaries it contains
  components = {
    restate-cli = [ "restate" ];
    restate-server = [ "restate-server" ];
    restatectl = [ "restatectl" ];
  };

  fetchComponent =
    component:
    fetchurl {
      url = "https://github.com/restatedev/restate/releases/download/v${sources.version}/${component}-${target}.tar.xz";
      hash = sources.assets.${system}.${component};
    };

  binaries = lib.concatLists (lib.attrValues components);
in
stdenvNoCC.mkDerivation {
  pname = "restate-bin";
  inherit (sources) version;

  srcs = map fetchComponent (lib.attrNames components);
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    ${lib.concatStrings (
      lib.mapAttrsToList (
        component: bins:
        lib.concatMapStrings (bin: ''
          install -Dm755 ${component}-${target}/${bin} $out/bin/${bin}
        '') bins
      ) components
    )}

    runHook postInstall
  '';

  # Linux binaries are static-pie (musl); Darwin binaries are signed.
  # Patching or stripping would at best be a no-op and at worst break code signatures.
  dontStrip = true;
  dontPatchELF = true;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    for bin in ${lib.escapeShellArgs binaries}; do
      echo "checking $bin --version"
      $out/bin/$bin --version | grep -F "${sources.version}"
    done

    runHook postInstallCheck
  '';

  # Updates: run pkgs/restate-bin/update.sh (see README).

  meta = {
    description = "Platform for developing distributed fault-tolerant applications (pre-built binaries)";
    homepage = "https://restate.dev";
    changelog = "https://github.com/restatedev/restate/releases/tag/v${sources.version}";
    mainProgram = "restate";
    license = lib.licenses.bsl11;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames targets;
  };
}
