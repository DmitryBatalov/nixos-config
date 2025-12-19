{
  description = "Proxy dev shell with Claude";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # Allow unfree packages for all systems
      forAllSystems = function:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed
          (system: function (import nixpkgs {
            inherit system;
            config.allowUnfree = true;  # ← This allows unfree packages
          }));
    in {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            proxychains-ng
	    claude-code
          ];
          
          # Create config as a Nix store path
          PROXYCHAINS_CONF_FILE = pkgs.writeText "proxychains.conf" ''
            strict_chain
            quiet_mode
            proxy_dns

            [ProxyList]
            socks5 127.0.0.1 1081
          '';
          
          shellHook = ''
            echo "✅ proxychains-ng ready with SOCKS5 on 127.0.0.1:1081"
            echo "Run: proxychains4 claude"
          '';
        };
      });
    };
}
