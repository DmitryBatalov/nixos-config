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
          (vscode-with-extensions.override {
            vscodeExtensions = with vscode-extensions; [
              ionide
              # pkgs.vscode-utils.extensionsFromVscodeMarketplace
              # [
              #   {
              #     name = "ionide";
              #     publisher = "Ionide";
              #     version = "7.28.3";
              #     sha256 = "";
              #   }
              # ]
            ];
          })
        ];

        shellHook = ''
          dotnet --version
        '';
      };
  };
}
