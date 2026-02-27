{ pkgs, unstable }:
let
  proxychainsConf = pkgs.writeText "proxychains.conf" ''
    strict_chain
    quiet_mode
    proxy_dns
    localnet 127.0.0.0/255.0.0.0

    [ProxyList]
    socks5 127.0.0.1 1081
  '';

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
    pkgs.proxychains-ng
  ];

  profile = ''
    export DOTNET_ROOT=${dotnet}/share/dotnet
    export DOTNET_PATH=${dotnet}/bin/dotnet
    export PATH=$PATH:${dotnet}/share/dotnet
    export PROXYCHAINS_CONF_FILE=${proxychainsConf}
  '';

  runScript = "proxychains4 -q rider";
}
