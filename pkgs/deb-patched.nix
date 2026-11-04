{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, dpkg
, makeWrapper
, common
, extraTools ? [ ]
}:

let
  system = stdenv.hostPlatform.system;
  debArch = {
    "x86_64-linux" = "x86_64";
    "aarch64-linux" = "aarch64";
  }.${system} or (throw "Unsupported system for craft-anything-bin: ${system}");

  src = fetchurl {
    url = "https://github.com/storytold/craft-anything/releases/download/v${common.version}/craft-anything-${common.version}-linux-${debArch}.deb";
    hash = common.debHashes.${system} or (throw "Missing deb hash for architecture: ${system}");
  };
in
stdenv.mkDerivation {
  pname = "${common.pname}-bin";
  version = common.version;

  inherit src;

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  # Libraries loaded dynamically via dlopen()
  runtimeDependencies = common.dlopenLibs;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" source
    cd source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -r usr/bin "$out/"
    cp -r usr/share "$out/"

    chmod +x "$out/bin/craft-anything" "$out/bin/craft-anything-cli"

    # Ensure Exec line in desktop file uses unwrapped or standard command
    if [ -f "$out/share/applications/ai.storyteller.craft-anything.desktop" ]; then
      substituteInPlace "$out/share/applications/ai.storyteller.craft-anything.desktop" \
        --replace-quiet "/usr/bin/craft-anything" "craft-anything"
    fi

    runHook postInstall
  '';

  postFixup = common.wrapBinaries {
    inherit extraTools;
  };

  meta = common.meta;
}
