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

  # URL and hash come straight from versions.json, so a bump is a data change.
  deb = common.debs.${system} or (throw "versions.json has no release package for ${system}");

  src = fetchurl {
    inherit (deb) url hash;
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
