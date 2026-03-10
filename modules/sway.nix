{pkgs, ...}: {
  environment.pathsToLink = ["/libexec"];

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaylock-effects
      swayidle
      waybar
      rofi
      dunst
      wl-clipboard
      grim
      slurp
      brightnessctl
      kanshi
      wdisplays
      sysstat
      acpi
      file-roller
      playerctl
      swaykbdd
    ];
    extraSessionCommands = ''
      export MOZ_ENABLE_WAYLAND=1
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      export _JAVA_AWT_WM_NONREPARENTING=1
      export SDL_VIDEODRIVER=wayland
      export XDG_SESSION_TYPE=wayland
    '';
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };

  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd sway";
          user = "greeter";
        };
      };
    };
    gvfs.enable = true;
    tumbler.enable = true;
  };

  programs.thunar.plugins = with pkgs.xfce; [
    thunar-archive-plugin
    thunar-volman
  ];
}
