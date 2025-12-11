{pkgs ? import <nixpkgs> {}}:
(
  let
    pkgsWithInsecure = import <nixpkgs> {
      config = {
        permittedInsecurePackages = [
          # "dotnet-sdk_6"
          "dotnet-sdk-6.0.428"
        ];
      };
    };
    dotnet = with pkgs.dotnetCorePackages; combinePackages [dotnet_10.sdk dotnet_8.sdk pkgsWithInsecure.dotnet-sdk_6];
  in
    pkgs.buildFHSEnv {
      name = "rider-dotnet";
      profile = ''
        export DOTNET_ROOT=${dotnet}/share/dotnet
        export DOTNET_PATH=${dotnet}/bin/dotnet
        export PATH=$PATH:${dotnet}/share/dotnet
      '';

      runScript = ''
        nohup rider > /dev/null 2>&1 &
      '';
    }
).env
