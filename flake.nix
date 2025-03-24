{
  description = "NixOS module for the Valheim dedicated server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    steam-fetcher = {
      url = "github:nix-community/steam-fetcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      steam-fetcher,
    }:
    let
      defaultOverlay = final: prev: {
        valheim-server-unwrapped = final.callPackage ./pkgs/valheim-server { };
        valheim-server = final.callPackage ./pkgs/valheim-server/fhsenv.nix { };
        valheim-bepinex-pack = final.callPackage ./pkgs/bepinex-pack { };
        fetchValheimThunderstoreMod = final.callPackage ./pkgs/build-support/fetch-thunderstore-mod { };
      };
    in
    {
      # See: https://discourse.nixos.org/t/how-to-consume-a-eachdefaultsystem-flake-overlay/19420/6
      overlays.default = defaultOverlay;
    }
    //
      # The Steam Nix fetcher only supports x86_64 Linux.
      flake-utils.lib.eachSystem [ flake-utils.lib.system.x86_64-linux ] (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              steam-fetcher.overlays.default
              defaultOverlay
            ];
          };
        in
        {
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              nixd
              nixfmt-rfc-style
            ];
          };

          checks = {
            fmt = pkgs.runCommandLocal "nixfmt" { } ''
              ${pkgs.nixfmt-rfc-style}/bin/nixfmt --check ${./.} > "$out"
            '';
          };

          formatter = pkgs.nixfmt-rfc-style;

          nixosModules = rec {
            valheim = import ./nixos-modules/valheim.nix { inherit self steam-fetcher; };
            default = valheim;
          };
          packages = {
            valheim-server = pkgs.valheim-server;
          };
        }
      );
}
