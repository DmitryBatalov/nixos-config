{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    baseIndex = 1;
    mouse = true;
    terminal = "tmux-256color";
    customPaneNavigationAndResize = true;
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = gruvbox;
        extraConfig = ''
          set -g @tmux-gruvbox 'dark'
        '';
      }
    ];
    extraConfig = ''
      set -ag terminal-overrides ",*:RGB"
      set -g allow-passthrough on
    '';
  };

  # `executable` is ignored for a directory source (home-manager lndirs the
  # tree and lndir keeps the store mode), so the scripts carry +x in git.
  xdg.configFile."tmux/scripts" = {
    source = ./scripts;
    recursive = true;
  };
}
