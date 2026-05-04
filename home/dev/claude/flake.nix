{
  description = "Claude with HTTP->SOCKS5 bridge (Bun fetch lacks remote-DNS SOCKS5)";

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
          set -u
          GOST_PID=""

          # Pick a free ephemeral port for the bridge
          for _ in 1 2 3 4 5 6 7 8 9 10; do
            PORT=$((32768 + RANDOM % 28000))
            if ! (exec 3<>/dev/tcp/127.0.0.1/$PORT) 2>/dev/null; then
              break
            fi
            exec 3>&- 3<&-
          done

          cleanup() {
            if [ -n "$GOST_PID" ] && kill -0 "$GOST_PID" 2>/dev/null; then
              kill "$GOST_PID" 2>/dev/null
            fi
          }
          trap cleanup EXIT INT TERM HUP

          # HTTP->SOCKS5 bridge: Bun's fetch supports HTTP_PROXY but rejects
          # socks5h:// and socks5:// can't do remote DNS we need.
          ${pkgs.gost}/bin/gost \
            -L="http://127.0.0.1:$PORT" \
            -F="socks5://127.0.0.1:1081" \
            >/dev/null 2>&1 &
          GOST_PID=$!

          # Wait for bridge to bind
          for _ in 1 2 3 4 5 6 7 8 9 10; do
            if (exec 3<>/dev/tcp/127.0.0.1/$PORT) 2>/dev/null; then
              exec 3>&- 3<&-
              break
            fi
            sleep 0.1
          done

          export HTTPS_PROXY="''${HTTPS_PROXY:-http://127.0.0.1:$PORT}"
          export HTTP_PROXY="''${HTTP_PROXY:-http://127.0.0.1:$PORT}"
          export ALL_PROXY="''${ALL_PROXY:-http://127.0.0.1:$PORT}"
          export NO_PROXY="''${NO_PROXY:-localhost,127.0.0.0/8}"

          ${pkgs.claude-code}/bin/claude "$@"
        '';
      });
    };
}
