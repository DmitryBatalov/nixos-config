{pkgs, ...}: {
  xdg = {
    enable = true;
    autostart.enable = true;

    mimeApps = {
      enable = true;
      # Still pinned explicitly: firefox is enabled too, so leaving these to
      # xdg-mime's guess risks handing http:// to the wrong browser.
      defaultApplications = {
        "x-scheme-handler/http" = "chromium-browser.desktop";
        "x-scheme-handler/https" = "chromium-browser.desktop";
        "text/html" = "chromium-browser.desktop";
        "application/pdf" = "org.gnome.Evince.desktop";
      };
    };

    # Escape hatch for when the SSH tunnel is down -- it has died silently
    # before, and systemd still reports the unit active when it does.
    # --no-proxy-server is checked before the other proxy switches, so it wins
    # over the --proxy-server baked into the wrapper regardless of flag order.
    desktopEntries.chromium-direct = {
      name = "Chromium (Direct)";
      exec = "chromium --no-proxy-server %U";
      icon = "chromium";
      comment = "Chromium with the SOCKS proxy bypassed";
      categories = ["Network" "WebBrowser"];
      terminal = false;
    };

    configFile."flameshot/flameshot.ini".text = ''
      [General]
      useGrimAdapter=true
      showDesktopNotification=false
      showAbortNotification=false
      showStartupLaunchMessage=false
    '';
  };

  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # enable auto mount of USB disks
  services.udiskie.enable = true;
}
