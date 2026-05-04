{
  description = "Claude with SOCKS5 proxy via env vars";

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
      packages = forAllSystems (pkgs: {
        default = pkgs.writeShellScriptBin "claude" ''
          export HTTPS_PROXY="''${HTTPS_PROXY:-socks5h://127.0.0.1:1081}"
          export HTTP_PROXY="''${HTTP_PROXY:-socks5h://127.0.0.1:1081}"
          export ALL_PROXY="''${ALL_PROXY:-socks5h://127.0.0.1:1081}"
          export NO_PROXY="''${NO_PROXY:-localhost,127.0.0.0/8}"
          exec ${pkgs.claude-code}/bin/claude "$@"
        '';
      });
    };
}
