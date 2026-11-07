<p align="center">
  <img src="https://raw.githubusercontent.com/storytold/craft-anything/main/assets/app-icon/hicolor/256x256/apps/ai.storyteller.craft-anything.png" width="128" height="128" alt="Craft Anything Icon">
</p>

<h1 align="center">craft-anything-nix</h1>

<p align="center">
  <strong>Production-grade Nix packaging for <a href="https://github.com/storytold/craft-anything">Craft Anything</a></strong><br>
  <em>Software exploration workbench GUI, 320-tool CLI engine, and Model Context Protocol (MCP) server.</em>
</p>

<p align="center">
  <a href="https://github.com/kmdtaufik/craft-anything-nix/actions/workflows/ci.yml"><img src="https://github.com/kmdtaufik/craft-anything-nix/actions/workflows/ci.yml/badge.svg" alt="CI Status"></a>
  <a href="https://nixos.org"><img src="https://img.shields.io/badge/Nix_Flakes-Ready-5277C3.svg?logo=nixos&logoColor=white" alt="Flake Ready"></a>
  <a href="https://github.com/storytold/craft-anything/releases/tag/v0.3.0"><img src="https://img.shields.io/badge/Upstream-v0.3.0-blue.svg" alt="Upstream Version"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT%2FApache--2.0-green.svg" alt="License"></a>
</p>

---

## Overview

**Craft Anything** is an all-in-one software exploration system that helps you find out how any software works, then craft your own. It unifies native binary inspection (ELF, Mach-O, PE/CLI), dynamic runtime tracing, decompilation, web/Android reverse engineering, and autonomous rebuild agents.

This repository provides community Nix Flakes and NixOS/Home Manager modules exposing **two distinct build strategies**—both packaging **both** the graphical workbench and the CLI/MCP server:

1. **Patched Pre-built Release (`craft-anything-bin`, *Default*)**: Instant install from official upstream `.deb` archives patched for NixOS with `autoPatchelfHook` and `makeWrapper`.
2. **Build From Source (`craft-anything-src`)**: Pure source compilation of the Rust 2024 workspace using `oxalica/rust-overlay` (satisfying the Rust $\ge$ 1.97 requirement).

---

## Screenshots

### The Desktop Workbench
The Advanced Workbench gives you instant function lists, pseudo-C decompilation, direct xref exploration, an evidence ledger, and live coding agent conversation:

<p align="center">
  <img src="https://raw.githubusercontent.com/storytold/craft-anything/main/docs/images/workbench.png" width="100%" alt="Craft Anything Advanced Workbench: Functions, Pseudo-C Decompiler, Agent Tool Calls, Evidence Ledger">
</p>

### Autonomous Make & Rebuild Engine
Select an app, website, or game to study; choose Clean Room or Deep Mode, supply instructions, and let coding agents execute the study → build → verify loop:

<p align="center">
  <img src="https://raw.githubusercontent.com/storytold/craft-anything/main/docs/images/make.png" width="100%" alt="Craft Anything Make: Clean Room vs Deep Mode autonomous rebuilds">
</p>

### Website and Application Study Projects
Inspect live DOM structures, network captures, computed styles, and check parity against rebuild targets:

<p align="center">
  <img src="https://raw.githubusercontent.com/storytold/craft-anything/main/docs/images/project-website.png" width="100%" alt="Craft Anything Website Inspection Project">
</p>

---

## Highlights & NixOS Architecture

- **Both Binaries in Every Package**:
  - `craft-anything`: The `egui` / `wgpu` graphical desktop workbench with desktop launcher (`.desktop`) and hicolor icon integration.
  - `craft-anything-cli`: The headless CLI engine with 320+ tools and JSON-RPC stdio Model Context Protocol (MCP) server.
- **The `egui` / `winit` / `wgpu` `dlopen` Trap Solved**: Rust GUI apps built on `eframe` dynamically load Wayland, X11, Vulkan, and OpenGL libraries at runtime via `dlopen()`. Standard `autoPatchelfHook` only rewrites ELF `DT_NEEDED` headers and misses these calls. This flake registers all graphics backends in `runtimeDependencies` and wraps `LD_LIBRARY_PATH` with:
  - `wayland`
  - `libxkbcommon`
  - `vulkan-loader`
  - `libGL` (`libglvnd`)
  - `libx11`, `libxcursor`, `libxi`, `libxrandr`, `libxcb`
  - `dbus`
- **First-Class Sibling Discovery**: `$out/bin/craft-anything` is wrapped so it automatically discovers `$out/bin/craft-anything-cli` on `PATH` for autonomous agent rebuild workflows.
- **External Analysis Engine Extensibility**: Seamlessly inject optional engines (`ghidra`, `chromium`, `gdb`, `rizin`, `android-tools`, etc.) directly into `PATH` through NixOS and Home Manager module options.

---

## Quick Run (Zero Install)

Run immediately on any Linux machine with Nix Flakes enabled:

### Instant Pre-built Release (Recommended)

```bash
# Launch the Graphical Desktop Workbench
nix run github:kmdtaufik/craft-anything-nix#gui-bin

# Run CLI diagnostics and health checks
nix run github:kmdtaufik/craft-anything-nix#cli-bin -- doctor

# Start the MCP server for AI coding agents
nix run github:kmdtaufik/craft-anything-nix#cli-bin -- mcp
```

### Build From Source

```bash
# Compile and run Desktop Workbench from source (Rust 1.97+)
nix run github:kmdtaufik/craft-anything-nix#gui-src

# Compile and run CLI / MCP server from source
nix run github:kmdtaufik/craft-anything-nix#cli-src -- doctor
```

---

## Permanent Installation

### 1. NixOS System Configuration

Add `craft-anything-nix` to your `flake.nix` inputs and enable the module:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    craft-anything-nix.url = "github:kmdtaufik/craft-anything-nix";
  };

  outputs = { self, nixpkgs, craft-anything-nix, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        craft-anything-nix.nixosModules.default
        {
          programs.craft-anything = {
            enable = true;

            # Choose package strategy (defaults to pre-built binary):
            # package = craft-anything-nix.packages.x86_64-linux.craft-anything-bin;
            # package = craft-anything-nix.packages.x86_64-linux.craft-anything-src;

            # Whether to install desktop GUI (.desktop & icons)
            enableDesktop = true;

            # Inject external analysis engines into Craft Anything's execution PATH:
            extraEngines = with pkgs; [
              gdb
              rizin
              binutils
              # ghidra
              # chromium
              # android-tools
            ];

            # Optional MCP tuning:
            mcp = {
              allTools = false;        # Expose all 320+ tools upfront (CRAFT_ANYTHING_MCP_ALL_TOOLS=1)
              maxResponseBytes = null; # Defaults to 8MB JSON-RPC response limit
            };
          };
        }
      ];
    };
  };
}
```

### 2. Home Manager Configuration

For standalone Home Manager setups:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    craft-anything-nix.url = "github:kmdtaufik/craft-anything-nix";
  };

  outputs = { self, nixpkgs, home-manager, craft-anything-nix, ... }: {
    homeConfigurations."kdx" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        craft-anything-nix.homeModules.default
        {
          programs.craft-anything = {
            enable = true;
            extraEngines = with pkgs; [ gdb rizin binutils ];
          };
        }
      ];
    };
  };
}
```

### 3. Imperative Install (`nix profile`)

```bash
# Install pre-built binary package
nix profile install github:kmdtaufik/craft-anything-nix#craft-anything-bin

# Or install from source
nix profile install github:kmdtaufik/craft-anything-nix#craft-anything-src
```

---

## Flake Outputs Reference

| Output | Type | Description |
|---|---|---|
| `packages.${system}.default` | Package | Alias to `craft-anything-bin` |
| `packages.${system}.craft-anything-bin` | Package | Patched official release `.deb` (GUI + CLI) |
| `packages.${system}.craft-anything-src` | Package | Full Rust 1.97+ source compilation (GUI + CLI) |
| `apps.${system}.default` | App | Runs `craft-anything` (pre-built GUI) |
| `apps.${system}.gui-bin` | App | Runs `craft-anything` (pre-built GUI) |
| `apps.${system}.cli-bin` | App | Runs `craft-anything-cli` (pre-built CLI) |
| `apps.${system}.gui-src` | App | Runs `craft-anything` (source GUI) |
| `apps.${system}.cli-src` | App | Runs `craft-anything-cli` (source CLI) |
| `overlays.default` | Overlay | Exposes `craft-anything-bin`, `craft-anything-src`, and `craft-anything` |
| `nixosModules.default` | NixOS Module | `programs.craft-anything` |
| `homeModules.default` | Home Manager Module | `programs.craft-anything` |
| `devShells.${system}.default` | DevShell | Full Rust 1.97+ dev shell with graphics libraries |

---

## MCP Server Integration

Craft Anything provides a 320-tool Model Context Protocol (MCP) server that connects reverse engineering and software exploration capabilities to AI coding agents over stdio.

### Claude Code (`~/.claude.json`)

```json
{
  "mcpServers": {
    "craft-anything": {
      "command": "craft-anything-cli",
      "args": ["mcp"]
    }
  }
}
```

### Cursor / Windsurf / Claude Desktop (`mcp.json`)

```json
{
  "mcpServers": {
    "craft-anything": {
      "command": "craft-anything-cli",
      "args": ["mcp", "--all-tools"]
    }
  }
}
```

### Automatic Registration

You can also run the built-in automated installer:

```bash
craft-anything-cli setup
```

This auto-detects configured AI agent apps (Claude Code, Cursor, Windsurf, VS Code, Gemini CLI, Codex, etc.) and registers the MCP server and investigation skills.

---

## Maintenance & Releases

Every upstream pin lives in one data file, [`versions.json`](versions.json): the release
version, the source archive URL and its SRI hash, and the release `.deb` URL and hash for
each system. No `.nix` file carries a hash, so a bump is a data change and nothing else.

```json
{
  "version": "0.3.0",
  "source": { "url": "…/archive/refs/tags/v0.3.0.tar.gz", "hash": "sha256-…" },
  "packages": {
    "x86_64-linux": { "url": "…/craft-anything-0.3.0-linux-x86_64.deb", "hash": "sha256-…" },
    "aarch64-linux": { "url": "…/craft-anything-0.3.0-linux-aarch64.deb", "hash": "sha256-…" }
  }
}
```

### Automatic (CI)

Every day the `update` job asks GitHub for the newest release. When it differs from
`versions.json`, the job rewrites the file, commits it to `main`, and the `build` job then
builds **both** strategies from the new pins. Pushes and pull requests to `main` build both
strategies in parallel, whether or not the version changed — but only when they touch a
`.nix` file, `flake.lock`, `versions.json` or this workflow. Documentation and other changes
never start two Rust builds.

Run it by hand from **Actions → CI → Run workflow**, optionally naming a release or
forcing the hashes to be recomputed.

The job pushes with `GITHUB_TOKEN`. If `main` is branch-protected, let
`github-actions[bot]` bypass the rule; otherwise the push is refused and the run fails
loudly rather than silently skipping the bump. Run `./scripts/update.sh` by hand and open a
pull request if you would rather review the hash change first.

### Manually

```bash
./scripts/update.sh                     # newest upstream release
./scripts/update.sh 0.4.0               # a specific release
./scripts/update.sh 0.3.0 --force       # recompute the current release's hashes
```

The script:
1. Resolves the release tag (argument, or GitHub's latest).
2. Prefetches the source archive and each release `.deb`, computing SRI SHA-256 hashes the
   same way `fetchzip` and `fetchurl` verify them.
3. Rewrites `versions.json` atomically.

Then check it:

```bash
nix flake check
nix build .#craft-anything-bin .#craft-anything-src
```

---

## License

Craft Anything is licensed under [MIT](https://opensource.org/licenses/MIT) or [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0).
Packaging files in this repository are available under the MIT License.
