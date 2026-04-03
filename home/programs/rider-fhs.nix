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

  # Override Rider source to fetch via SOCKS5 proxy
  riderBase = unstable.jetbrains.rider;
  rider = riderBase.overrideAttrs (old: {
    src = pkgs.stdenvNoCC.mkDerivation {
      name = old.src.name;
      outputHash = old.src.outputHash;
      outputHashAlgo = "sha256";
      outputHashMode = "flat";
      nativeBuildInputs = [ pkgs.curl ];
      phases = [ "installPhase" ];
      installPhase = ''
        curl -L --socks5-hostname 127.0.0.1:1081 -o $out ${old.src.url}
      '';
    };
  });

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
{
  rider = rider;
  fhs = pkgs.buildFHSEnv {
    name = "rider";

    targetPkgs = _: [
      rider
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
  };
}
