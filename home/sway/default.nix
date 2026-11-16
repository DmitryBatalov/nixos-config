{pkgs, ...}: {
  # sway ships no Polkit agent, so without one every "authenticate" request
  # (KeePassXC quick unlock, systemctl without sudo, ...) has nothing to prompt
  # with. polkit-gnome, not soteria: soteria 0.3.1 answers only a PAM prompt
  # that reads exactly "Password:", so pam_u2f's PIN prompt hangs it. This one
  # shows whatever PAM asks, and its info messages ("touch the device").
  services.polkit-gnome.enable = true;

  xdg.configFile = {
    "sway/wallpaper.png".source = "${pkgs.nixos-artwork.wallpapers.simple-dark-gray-bottom.src}";
    "sway/config".source = ./config;

    # `recursive` makes home-manager lndir the whole tree, and lndir preserves
    # the mode of the store copy -- the `executable` option is only honoured
    # for single files, never for a directory source. So the +x bit has to be
    # set on the scripts in git, which it now is.
    "sway/scripts" = {
      source = ./scripts;
      recursive = true;
    };

    "waybar/config.jsonc".source = ./waybar/config.jsonc;
    "waybar/style.css".source = ./waybar/style.css;
  };
}
