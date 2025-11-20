{pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-25.05.tar.gz") {}}:
(pkgs.buildFHSEnv {
  name = "rider-dotnet";

  targetPkgs = pkgs:
    with pkgs; [
      dotnetCorePackages.sdk_8_0-bin

      # Essential libraries
      icu
      openssl
      zlib
      stdenv.cc.cc.lib
    ];

  profile = ''
    export DOTNET_ROOT=${pkgs.dotnet-sdk_8}
    export MSBuildSDKsPath=${pkgs.dotnet-sdk_8}/lib/sdk/8.0.100/Sdks
  '';

  runScript = ''
    nohup rider > /dev/null 2>&1 &
  '';
}).env
