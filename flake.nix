{
  description = "Nix packaging for Craft Anything (Desktop Workbench GUI & MCP Server)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (import rust-overlay) ];
          };
          common = pkgs.callPackage ./pkgs/common.nix { };
          craft-anything-bin = pkgs.callPackage ./pkgs/deb-patched.nix { inherit common; };
          craft-anything-src = pkgs.callPackage ./pkgs/from-source.nix { inherit common; };
        in
        {
          default = craft-anything-bin;
          inherit craft-anything-bin craft-anything-src;
          craft-anything = craft-anything-bin;
        }
      );

      apps = forAllSystems (system:
        let
          selfPkgs = self.packages.${system};
        in
        {
          default = {
            type = "app";
            program = "${selfPkgs.craft-anything-bin}/bin/craft-anything";
            meta.description = "Craft Anything Desktop Workbench GUI (pre-built binary)";
          };
          gui-bin = {
            type = "app";
            program = "${selfPkgs.craft-anything-bin}/bin/craft-anything";
            meta.description = "Craft Anything Desktop Workbench GUI (pre-built binary)";
          };
          cli-bin = {
            type = "app";
            program = "${selfPkgs.craft-anything-bin}/bin/craft-anything-cli";
            meta.description = "Craft Anything CLI & MCP Server (pre-built binary)";
          };
          gui-src = {
            type = "app";
            program = "${selfPkgs.craft-anything-src}/bin/craft-anything";
            meta.description = "Craft Anything Desktop Workbench GUI (built from source)";
          };
          cli-src = {
            type = "app";
            program = "${selfPkgs.craft-anything-src}/bin/craft-anything-cli";
            meta.description = "Craft Anything CLI & MCP Server (built from source)";
          };
        }
      );

      overlays.default = final: prev: {
        craft-anything-common = final.callPackage ./pkgs/common.nix { };
        craft-anything-bin = final.callPackage ./pkgs/deb-patched.nix {
          common = final.craft-anything-common;
        };
        craft-anything-src = final.callPackage ./pkgs/from-source.nix {
          common = final.craft-anything-common;
        };
        craft-anything = final.craft-anything-bin;
      };

      nixosModules = {
        default = import ./modules/nixos.nix;
        craft-anything = self.nixosModules.default;
      };

      homeModules = {
        default = import ./modules/home-manager.nix;
        craft-anything = self.homeModules.default;
      };

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (import rust-overlay) ];
          };
          common = pkgs.callPackage ./pkgs/common.nix { };
          rustToolchain = pkgs.rust-bin.stable.latest.default;
        in
        {
          default = pkgs.mkShell {
            packages = [
              rustToolchain
              pkgs.pkg-config
              pkgs.dbus
              pkgs.bubblewrap
            ] ++ common.dlopenLibs;

            shellHook = ''
              export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath common.dlopenLibs}:$LD_LIBRARY_PATH"
            '';
          };
        }
      );
    };
}
