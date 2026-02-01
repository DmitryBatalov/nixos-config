{
  description = "Claude with proxychains";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems =
        function:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system:
          function (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }
          )
        );
    in
    {
      packages = forAllSystems (pkgs:
        let
          proxychainsConf = pkgs.writeText "proxychains.conf" ''
            strict_chain
            quiet_mode
            proxy_dns

            [ProxyList]
            socks5 127.0.0.1 1081
          '';
        in
        {
          default = pkgs.writeShellScriptBin "claude" ''
            export PROXYCHAINS_CONF_FILE=${proxychainsConf}
            exec ${pkgs.proxychains-ng}/bin/proxychains4 -q ${pkgs.claude-code}/bin/claude "$@"
          '';
        });
    };
}
