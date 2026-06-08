{
  description = "NixOS from Scratch";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Pinned for Rider ONLY. This is the last nixpkgs-unstable rev whose
    # jetbrains.rider derivation matches the build already in the Nix store.
    # JetBrains 451-blocks downloads from our datacenter proxy exit, so any
    # rebuild from a newer rev can't fetch the tarball. Pinning here reuses the
    # cached build (no download). Revisit once a working download path exists.
    nixpkgs-rider.url = "github:NixOS/nixpkgs/331800de5053fcebacf6813adb5db9c9dca22a0c";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim-config = {
      url = "path:./home/dev/nixvim";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    claude-config = {
      url = "path:./home/dev/claude";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    disko,
    ...
  }: {
    nixosConfigurations = {
      nixos = let
        username = "dmitry";
        specialArgs = {inherit username;};
      in
        nixpkgs.lib.nixosSystem {
          inherit specialArgs;

          system = "x86_64-linux";
          modules = [
            ./hosts/nixos

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;

                extraSpecialArgs = inputs // specialArgs;
                users.${username} = import ./users/${username}/home.nix;
                backupFileExtension = "backup";
              };
            }
          ];
        };

      vega = let
        username = "dmitry";
        specialArgs = {inherit username;};
      in
        nixpkgs.lib.nixosSystem {
          inherit specialArgs;

          system = "x86_64-linux";
          modules = [
            ./hosts/vega
          ];
        };
    };
  };
}
