{ lib, pkgs }:

let
  libx11' = pkgs.libx11 or pkgs.xorg.libX11;
  libxcursor' = pkgs.libxcursor or pkgs.xorg.libXcursor;
  libxi' = pkgs.libxi or pkgs.xorg.libXi;
  libxrandr' = pkgs.libxrandr or pkgs.xorg.libXrandr;
  libxcb' = pkgs.libxcb or pkgs.xorg.libxcb;

  # Dynamic libraries loaded at runtime via dlopen() by egui/winit/wgpu/rfd
  dlopenLibs = [
    pkgs.wayland
    pkgs.libxkbcommon
    pkgs.vulkan-loader
    pkgs.libGL
    libx11'
    libxcursor'
    libxi'
    libxrandr'
    libxcb'
    pkgs.dbus
  ];

  cliLibs = [
    pkgs.stdenv.cc.cc.lib
    pkgs.openssl
  ];
in
rec {
  pname = "craft-anything";
  version = "0.3.0";

  # Upstream source git archive hash (for v0.3.0 tag)
  srcHash = "sha256-wHQHqEpRW+eypP0y+rafAz8CBi/ei8lka8st5JxpqL4=";

  # Official release .deb hashes per supported platform
  debHashes = {
    x86_64-linux = "sha256-sDNLYQXpNqnVq7eG/046hmGuApj001ZOCfFme9mEhw0=";
    aarch64-linux = "sha256-lQq4JBUgmIDi1caUYrJ3TV2el65TFiZjWJMyGwSW+R0=";
  };

  inherit dlopenLibs cliLibs;

  # BuildInputs needed by both builds
  buildInputs = [
    pkgs.stdenv.cc.cc.lib
    pkgs.dbus
  ] ++ dlopenLibs;

  # Shared wrapping logic solving the dlopen trap and PATH discovery
  wrapBinaries = { extraTools ? [ ] }: ''
    # Wrap GUI with dlopen libraries and PATH for sibling CLI and sandboxing
    wrapProgram "$out/bin/craft-anything" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath dlopenLibs}" \
      --prefix PATH : "${lib.makeBinPath ([ pkgs.bubblewrap ] ++ extraTools)}" \
      --suffix PATH : "$out/bin"

    # Wrap CLI with required runtime libraries and sandboxing
    wrapProgram "$out/bin/craft-anything-cli" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath cliLibs}" \
      --prefix PATH : "${lib.makeBinPath ([ pkgs.bubblewrap ] ++ extraTools)}" \
      --suffix PATH : "$out/bin"
  '';

  meta = with lib; {
    description = "Software exploration workbench, CLI, and MCP server";
    longDescription = ''
      Craft Anything finds out how any software works, then helps you craft your own.
      It combines an egui/wgpu graphical workbench, a 320-tool CLI engine, and a
      Model Context Protocol (MCP) server for integration with AI coding agents.
    '';
    homepage = "https://getartcraft.com/apps/craft-anything";
    changelog = "https://github.com/storytold/craft-anything/releases/tag/v${version}";
    license = with licenses; [ mit asl20 ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "craft-anything";
  };
}
