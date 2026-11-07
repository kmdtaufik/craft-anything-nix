{ lib, pkgs }:

let
  # Every upstream pin lives in ../versions.json: the release version, the source
  # archive URL and its hash, and the per-system release package URLs and hashes.
  # scripts/update.sh rewrites that file; nothing here needs editing for a bump.
  pins = builtins.fromJSON (builtins.readFile ../versions.json);

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
  inherit (pins) version;

  # { url, hash } of the upstream source archive the from-source build unpacks.
  source = pins.source;

  # { <system> = { url, hash; }; } official release .deb packages, by Nix system.
  debs = pins.packages;

  inherit dlopenLibs cliLibs;

  # BuildInputs needed by both builds
  buildInputs = [
    pkgs.stdenv.cc.cc.lib
    pkgs.dbus
  ] ++ dlopenLibs;

  # Shared wrapping logic solving the dlopen trap and PATH discovery
  wrapBinaries = { extraTools ? [ ] }: ''
    # Hook to expose analyzeHeadless when NixOS provides ghidra-analyzeHeadless
    ghidraHook='if ! command -v analyzeHeadless >/dev/null 2>&1 && command -v ghidra-analyzeHeadless >/dev/null 2>&1; then
      _SHIM_DIR="''${XDG_RUNTIME_DIR:-/tmp}/craft-anything-shims-$(id -u)"
      mkdir -p "$_SHIM_DIR"
      ln -sf "$(command -v ghidra-analyzeHeadless)" "$_SHIM_DIR/analyzeHeadless"
      export PATH="$_SHIM_DIR:$PATH"
    fi'

    # Wrap GUI with dlopen libraries and PATH for sibling CLI and sandboxing
    wrapProgram "$out/bin/craft-anything" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath dlopenLibs}" \
      --prefix PATH : "${lib.makeBinPath ([ pkgs.bubblewrap ] ++ extraTools)}" \
      --suffix PATH : "$out/bin" \
      --run "$ghidraHook"

    # Wrap CLI with required runtime libraries and sandboxing
    wrapProgram "$out/bin/craft-anything-cli" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath cliLibs}" \
      --prefix PATH : "${lib.makeBinPath ([ pkgs.bubblewrap ] ++ extraTools)}" \
      --suffix PATH : "$out/bin" \
      --run "$ghidraHook"
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
