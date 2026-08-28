{...}: {
  # `executable` is ignored for a directory source (home-manager lndirs the
  # tree and lndir keeps the store mode), so the scripts carry +x in git.
  xdg.configFile."tmux/scripts" = {
    source = ./scripts;
    recursive = true;
  };
}
