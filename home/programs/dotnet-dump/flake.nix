{
  description = "dotnet-dump development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
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
        dotnetPkg = pkgs.dotnet-sdk_8;

        # Build dotnet-dump using buildDotnetGlobalTool
        dotnet-dump = pkgs.buildDotnetGlobalTool {
          pname = "dotnet-dump";
          version = "8.0.547301";

          nugetHash = "sha256-Yxl4vO7y8/Igxhw6VWFA0ZYbC7gKHoyNUkzeeFu81wQ=";

          dotnet-sdk = dotnetPkg;
          dotnet-runtime = dotnetPkg;
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            dotnetPkg
            dotnet-dump
          ];

          shellHook = ''
            echo "dotnet-dump environment loaded"
            echo "dotnet-dump is ready to use"
          '';
        };

        packages.default = dotnet-dump;
      }
    );
}
