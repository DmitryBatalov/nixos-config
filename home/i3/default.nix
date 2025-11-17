{
  pkgs,
  config,
  ...
}: {
  # wallpaper, binary file
  home = {
    file = {
      ".config/i3/config".source = ./config;
      ".config/i3/i3blocks.conf".source = ./i3blocks.conf;
      # ".config/i3/keybindings".source = ./keybindings;
      ".config/i3/scripts" = {
        source = ./scripts;
        # copy the scripts directory recursively
        recursive = true;
        executable = true; # make all scripts executable
      };
    };
  };

  # home.file.".xxx".text = ''
  #     xxx
  # '';
}
