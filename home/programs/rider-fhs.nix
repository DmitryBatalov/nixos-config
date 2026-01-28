{ pkgs, unstable }:
let
  pkgsWithInsecure = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {
      permittedInsecurePackages = [
        "dotnet-sdk-6.0.428"
      ];
    };
  };

  dotnet = with pkgs.dotnetCorePackages;
    combinePackages [ dotnet_10.sdk dotnet_8.sdk pkgsWithInsecure.dotnet-sdk_6 ];

in
pkgs.buildFHSEnv {
  name = "rider";

  targetPkgs = _: [
    unstable.jetbrains.rider
    dotnet
  ];

  profile = ''
    export DOTNET_ROOT=${dotnet}/share/dotnet
    export DOTNET_PATH=${dotnet}/bin/dotnet
    export PATH=$PATH:${dotnet}/share/dotnet
  '';

  runScript = "rider";
}
