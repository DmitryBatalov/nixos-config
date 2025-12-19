{
  description = "dotnet-dump development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            dotnet-sdk_8 # or dotnet-sdk_9 for .NET 9
          ];

          shellHook = ''
            echo "dotnet-dump environment loaded"
            echo "Installing dotnet-dump globally..."
            dotnet tool install --global dotnet-dump 2>/dev/null || dotnet tool update --global dotnet-dump
            export PATH="$HOME/.dotnet/tools:$PATH"
            echo "dotnet-dump is ready to use"
          '';
        };

        packages.default = pkgs.writeShellScriptBin "dotnet-dump" ''
          export DOTNET_ROOT="${pkgs.dotnet-sdk_8}"
          exec ${pkgs.dotnet-sdk_8}/bin/dotnet tool run dotnet-dump "$@"
        '';
      }
    );
}
