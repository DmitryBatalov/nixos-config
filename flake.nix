{
  description = "NixOS from Scratch";

  inputs = {
    # Indirect (registry) ref, unlike every other input here. Rewriting it as
    # github:NixOS/nixpkgs/nixos-26.05 would re-resolve the input and silently
    # bump nixpkgs, so it is left for a deliberate flake update rather than
    # changed as a side effect of a refactor.
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
    nixpkgs,
    home-manager,
    ...
  }: let
    # Both hosts are x86_64-linux; nothing here is meant to be cross-platform.
    system = "x86_64-linux";
    username = "dmitry";
    specialArgs = {inherit inputs username;};

    # `home` pulls in home-manager as a NixOS module. Only one host uses it
    # today, but a headless machine would want it off, which is why it stays a
    # flag rather than being inlined.
    mkHost = {
      modules,
      home ? false,
    }:
      nixpkgs.lib.nixosSystem {
        inherit system specialArgs;

        modules =
          modules
          ++ nixpkgs.lib.optionals home [
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;

                extraSpecialArgs = specialArgs;
                users.${username} = import ./users/${username}/home.nix;
                backupFileExtension = "backup";
              };
            }
          ];
      };
  in {
    # Matches the alejandra formatter nixvim uses (conform.nvim) so `nix fmt`
    # and editor-on-save formatting agree.
    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;

    nixosConfigurations = {
      nixos = mkHost {
        modules = [./hosts/nixos];
        home = true;
      };
    };
  };
}
