{
  pkgs,
  config,
  ...
}: {
  home.file.".config/tmux/scripts" = {
    source = ./scripts;
    recursive = true;
    executable = true;
  };
}
