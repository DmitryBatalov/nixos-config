{
  pkgs,
  config,
  ...
}: {
  xdg.configFile."tmux/scripts" = {
    source = ./scripts;
    recursive = true;
    executable = true;
  };
}
