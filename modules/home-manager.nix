{ config, lib, pkgs, ... }:

let
  cfg = config.programs.craft-anything;

  # Base package with extra engines passed
  basePackage = if cfg.extraEngines == [ ]
    then cfg.package
    else cfg.package.override { extraTools = cfg.extraEngines; };

  # Package with CLI-only filtering if enableDesktop is disabled
  desktopFilteredPackage = if cfg.enableDesktop
    then basePackage
    else pkgs.symlinkJoin {
      name = "${basePackage.name}-cli-only";
      paths = [ basePackage ];
      postBuild = ''
        rm -rf $out/share/applications $out/share/icons
        rm -f $out/bin/craft-anything
      '';
    };

  # Final package with environment flags if configured
  finalPackage = if (!cfg.mcp.allTools && cfg.mcp.maxResponseBytes == null && cfg.logLevel == null)
    then desktopFilteredPackage
    else pkgs.symlinkJoin {
      name = "${desktopFilteredPackage.name}-configured";
      paths = [ desktopFilteredPackage ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for exe in $out/bin/craft-anything $out/bin/craft-anything-cli; do
          if [ -f "$exe" ]; then
            wrapProgram "$exe" \
              ${lib.optionalString cfg.mcp.allTools "--set CRAFT_ANYTHING_MCP_ALL_TOOLS 1"} \
              ${lib.optionalString (cfg.mcp.maxResponseBytes != null) "--set CRAFT_ANYTHING_MCP_MAX_RESPONSE_BYTES ${toString cfg.mcp.maxResponseBytes}"} \
              ${lib.optionalString (cfg.logLevel != null) "--set CRAFT_ANYTHING_LOG ${cfg.logLevel}"}
          fi
        done
      '';
    };
in
{
  options.programs.craft-anything = {
    enable = lib.mkEnableOption "Craft Anything software exploration workbench, CLI, and MCP server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.craft-anything or pkgs.craft-anything-bin;
      defaultText = lib.literalExpression "pkgs.craft-anything-bin";
      description = "The Craft Anything package derivation to install.";
    };

    enableDesktop = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to include the desktop GUI and application menu items.";
    };

    extraEngines = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "with pkgs; [ gdb rizin binutils ghidra chromium ]";
      description = "Additional external analysis engines or tools to place on PATH for Craft Anything.";
    };

    logLevel = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "trace" "debug" "info" "warn" "error" ]);
      default = null;
      description = "Default CRAFT_ANYTHING_LOG logging level.";
    };

    mcp = {
      allTools = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Expose all 314+ engine tools in MCP server unconditionally (CRAFT_ANYTHING_MCP_ALL_TOOLS=1).";
      };

      maxResponseBytes = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 16777216;
        description = "Maximum response size in bytes for single MCP JSON-RPC responses (defaults to 8MB).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ finalPackage ];
  };
}
