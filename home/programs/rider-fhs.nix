{
  pkgs,
  unstable,
}: let
  proxychainsConf = pkgs.writeText "proxychains.conf" ''
    strict_chain
    quiet_mode
    proxy_dns
    localnet 127.0.0.0/255.0.0.0

    [ProxyList]
    socks5 127.0.0.1 1081
  '';

  # Plain upstream Rider. This used to carry an overrideAttrs that swapped src
  # for a hand-rolled FOD curling through the SOCKS proxy; it was redundant on
  # two counts. fetchurl already declares all_proxy/https_proxy in its
  # impureEnvVars, and modules/system.nix puts those on the nix-daemon, so
  # stock fetchurl goes through the tunnel by itself. And because Nix hashes
  # derivations modulo fixed-output derivations, the replacement src had the
  # same outputHash and therefore produced a byte-identical rider outPath
  # (bv4xnpca...) -- it could not have changed the result even in principle.
  # What actually keeps this working is the nixpkgs-rider pin in flake.nix.
  rider = unstable.jetbrains.rider;

  pkgsWithInsecure = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {
      permittedInsecurePackages = [
        "dotnet-sdk-6.0.428"
      ];
    };
  };

  dotnet = with pkgs.dotnetCorePackages;
    combinePackages [dotnet_10.sdk dotnet_8.sdk pkgsWithInsecure.dotnet-sdk_6];
in {
  inherit rider;
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
