{
  pkgs,
  config,
  ...
}: {
  # https://github.com/endeavouros-team/endeavouros-i3wm-setup
  home.file.".config/rofi" = {
    source = ./configs;
    # copy the scripts directory recursively
    recursive = true;
  };

  # home.file.".xxx".text = ''
  #     xxx
  # '';
}

