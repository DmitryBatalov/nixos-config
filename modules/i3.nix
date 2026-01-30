{pkgs, ...}: {
  # i3 related options
  environment.pathsToLink = ["/libexec"]; # links /libexec from derivations to /run/current-system/sw

  services = {
    displayManager = {
      defaultSession = "none+i3";
      # gdm.enable = true;
    };

    xserver = {
      enable = true;

      autoRepeatDelay = 200;
      autoRepeatInterval = 35;

      desktopManager = {
        xterm.enable = false;
      };

      # displayManager = {
      #   lightdm.enable = false;
      # };

      windowManager.i3 = {
        enable = true;
        extraPackages = with pkgs; [
          rofi # application launcher, the same as dmenu
          dunst # notification daemon
          i3blocks # status bar
          i3lock # default i3 screen locker
          xidlehook # lock screen after some time, with idle inhibition support
          xsecurelock # PAM-based screen locker with FIDO2 support
          mpv # used by xsecurelock saver_mpv for blur background
          i3status # provide information to i3bar
          i3 # i3 with gaps
          feh # set wallpaper
          acpi # battery information
          arandr # screen layout manager
          xbindkeys # bind keys to commands
          xorg.xbacklight # control screen brightness
          xorg.xdpyinfo # get screen information
          sysstat # get system information
          xclip
          file-roller # An archive manager from GNOME
        ];
      };

      # Configure keymap in X11
      xkb = {
        layout = "us,ru";
        variant = ",";
        options = "grp:win_space_toggle";
      };
    };

    tumbler.enable = true; # Thumbnail support for images
  };

  programs = {
    # thunar file manager(part of xfce) related options
    thunar.plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];
  };
}
