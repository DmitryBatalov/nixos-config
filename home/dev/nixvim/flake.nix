{
  description = "A Nixvim configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # Deliberately NOT `inputs.nixpkgs.follows = "nixpkgs"`. It does collapse
    # the fourth nixpkgs tree out of the root flake's lock, and it evaluates
    # fine, but nixvim then warns on every single evaluation:
    #
    #   Nixvim's inputs pin Nixpkgs to ac6b2166...; actual Nixpkgs is
    #   following 9fbb54b3... Please remove your inputs.nixvim.inputs.
    #   nixpkgs.follows or explicitly define `nixpkgs.source`.
    #
    # nixvim pins and tests against its own rev on purpose, so the extra
    # source tree is the price of staying on a supported configuration.
    #
    # Consequence worth knowing: the root flake's
    # `nixvim-config.inputs.nixpkgs.follows = "nixpkgs-unstable"` therefore
    # does nothing useful -- nothing in this flake's outputs reads the nixpkgs
    # input, so neovim is built from nixvim's pin either way.
    nixvim.url = "github:nix-community/nixvim";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = {
    nixvim,
    flake-parts,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem = {system, ...}: let
        nixvimLib = nixvim.lib.${system};
        nixvim' = nixvim.legacyPackages.${system};
        nixvimModule = {
          inherit system; # or alternatively, set `pkgs`
          module = import ./config; # import the module directly
        };
        nvim = nixvim'.makeNixvimWithModule nixvimModule;
      in {
        checks = {
          # Run `nix flake check .` to verify that your config is not broken
          default = nixvimLib.check.mkTestDerivationFromNixvimModule nixvimModule;
        };

        packages = {
          # Lets you run `nix run .` to start nixvim
          default = nvim;
        };
      };
    };
}
