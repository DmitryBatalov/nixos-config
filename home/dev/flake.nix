{
  description = "Dotnet env";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    system = "x86_64-linux";
  in {
    devShells."${system}".default = let
      pkgs = import nixpkgs {inherit system;};
    in
      pkgs.mkShell {
        packages = with pkgs; [
          dotnetCorePackages.sdk_8_0_3xx-bin
          dotnetCorePackages.sdk_10_0-bin
        ];

        shellHook = ''
          dotnet --list-sdks
        '';
      };
  };
}
