{
  programs = {
    bash = {
      enable = true;
      sessionVariables = {
        EDITOR = "nvim";
        BROWSER = "chromium";
      };
      shellAliases = {
        v = "nvim";
        lg = "lazygit";
        dcu = "docker compose up -d";
        dcd = "docker compose down";
        dcdv = "docker compose down -v";
        dcs = "docker compose stop";
        dcr = "docker compose stop && docker compose up -d";
      };
      initExtra = ''
        cdtmp() { cd "$(mktemp -d)"; }
      '';
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
      # Keep direnv's layout dir out of the project tree. .direnv/flake-inputs
      # holds symlinks into /nix/store and one of them is nixpkgs (~90k files),
      # so any tool that scans the project root following symlinks -- Paket --
      # walks the whole closure. Standard direnv recipe; layouts go to the XDG
      # cache instead, keyed by a hash of the project path.
      stdlib = ''
        : "''${XDG_CACHE_HOME:=$HOME/.cache}"
        declare -A direnv_layout_dirs
        direnv_layout_dir() {
          echo "''${direnv_layout_dirs[$PWD]:=$(
            echo -n "$XDG_CACHE_HOME"/direnv/layouts/
            echo -n "$PWD" | sha1sum | cut -d ' ' -f 1
          )}"
        }
      '';
    };

    # Small interactive tools that carry no configuration of their own.
    btop.enable = true;
    ripgrep.enable = true;
    fzf.enable = true;
  };
}
