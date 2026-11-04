{ lib
, pkgs
, stdenv
, fetchFromGitHub
, rustPlatform ? (
    if pkgs ? rust-bin then
      pkgs.makeRustPlatform {
        cargo = pkgs.rust-bin.stable.latest.default;
        rustc = pkgs.rust-bin.stable.latest.default;
      }
    else
      pkgs.rustPlatform
  )
, pkg-config
, makeWrapper
, common
, extraTools ? [ ]
}:

let
  pname = "${common.pname}-src";
  version = common.version;
in
rustPlatform.buildRustPackage rec {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "craft-anything";
    rev = "v${version}";
    hash = common.srcHash;
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    pkgs.dbus
  ] ++ common.dlopenLibs;

  # Build both desktop GUI and CLI/MCP binaries
  cargoBuildFlags = [
    "-p"
    "craft-anything"
    "-p"
    "craft-anything-cli"
  ];

  # Skip tests in Nix build sandbox (tests expect network/GPU resources)
  doCheck = false;

  postInstall = ''
    # Install desktop entry
    install -Dm644 packaging/linux/ai.storyteller.craft-anything.desktop \
      "$out/share/applications/ai.storyteller.craft-anything.desktop"

    # Install AppStream metadata if available
    if [ -f packaging/linux/ai.storyteller.craft-anything.metainfo.xml.in ]; then
      install -Dm644 packaging/linux/ai.storyteller.craft-anything.metainfo.xml.in \
        "$out/share/metainfo/ai.storyteller.craft-anything.metainfo.xml"
      substituteInPlace "$out/share/metainfo/ai.storyteller.craft-anything.metainfo.xml" \
        --replace-quiet "@VERSION@" "${version}" \
        --replace-quiet "@DATE@" "2026-11-02"
    fi

    # Install all pre-rendered icon sizes
    for size in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
      if [ -f "assets/app-icon/hicolor/$size/apps/ai.storyteller.craft-anything.png" ]; then
        install -Dm644 "assets/app-icon/hicolor/$size/apps/ai.storyteller.craft-anything.png" \
          "$out/share/icons/hicolor/$size/apps/ai.storyteller.craft-anything.png"
      fi
    done

    # Install scalable SVG icon
    if [ -f "assets/app-icon/hicolor/scalable/apps/ai.storyteller.craft-anything.svg" ]; then
      install -Dm644 "assets/app-icon/hicolor/scalable/apps/ai.storyteller.craft-anything.svg" \
        "$out/share/icons/hicolor/scalable/apps/ai.storyteller.craft-anything.svg"
    fi
  '';

  postFixup = common.wrapBinaries {
    inherit extraTools;
  };

  meta = common.meta;
}
