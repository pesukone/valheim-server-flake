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
    # The Steam Nix fetcher only supports x86_64 Linux.
    flake-utils.lib.eachSystem [ flake-utils.lib.system.x86_64-linux ] (
      system:
      let
        defaultOverlay = final: prev: {
          valheim-server-unwrapped = final.callPackage ./pkgs/valheim-server { };
          valheim-server = final.callPackage ./pkgs/valheim-server/fhsenv.nix { };
          valheim-bepinex-pack = final.callPackage ./pkgs/bepinex-pack { };
          fetchValheimThunderstoreMod = final.callPackage ./pkgs/build-support/fetch-thunderstore-mod { };
        };
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            steam-fetcher.overlays.default
            defaultOverlay
          ];
        };
        linters = with pkgs; [
          alejandra
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          packages =
            with pkgs;
            [
              nil # Nix LS
            ]
            ++ linters;
        };

        checks = {
          fmt = pkgs.runCommandLocal "alejandra" { } ''
            ${pkgs.alejandra}/bin/alejandra --check ${./.} > "$out"
          '';
        };

        formatter = pkgs.alejandra;

        nixosModules = rec {
          valheim = import ./nixos-modules/valheim.nix { inherit self steam-fetcher; };
          default = valheim;
        };
        overlays.default = defaultOverlay;
        packages = {
          valheim-server = pkgs.valheim-server;
        };
      }
    );
}
