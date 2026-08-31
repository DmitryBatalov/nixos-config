{
  osConfig,
  pkgs,
  ...
}: let
  proxy = osConfig.local.proxy;

  # KeePassXC native messaging manifest for Chromium.
  # The nixpkgs keepassxc only ships a Firefox manifest (allowed_extensions);
  # Chromium requires allowed_origins with the extension's chrome-extension:// URL,
  # so we ship our own package consumed via programs.chromium.nativeMessagingHosts.
  keepassxcChromiumHost = pkgs.writeTextFile {
    name = "keepassxc-chromium-native-messaging-host";
    destination = "/etc/chromium/native-messaging-hosts/org.keepassxc.keepassxc_browser.json";
    text = builtins.toJSON {
      name = "org.keepassxc.keepassxc_browser";
      description = "KeePassXC integration with native messaging support";
      path = "${pkgs.keepassxc}/bin/keepassxc-proxy";
      type = "stdio";
      allowed_origins = [
        "chrome-extension://oboonakemofpalcgghocfoadofidjkkk/"
      ];
    };
  };
in {
  programs = {
    firefox = {
      enable = true;
      # Silence 26.05 warning: keep legacy non-XDG path until we actually use Firefox.
      configPath = ".mozilla/firefox";
    };

    chromium = {
      enable = true;
      # Baked into the wrapper, so the stock chromium-browser.desktop and a
      # bare `chromium` in a terminal both go through the SSH tunnel. See the
      # chromium-direct entry in home/desktop for the way out.
      commandLineArgs = [
        "--proxy-server=socks5://${proxy.socksAddress}:${toString proxy.socksPort}"
      ];
      extensions = [
        {id = "oboonakemofpalcgghocfoadofidjkkk";} # KeePassXC-Browser
      ];
      nativeMessagingHosts = [keepassxcChromiumHost];
    };

    keepassxc = {
      enable = true;
      autostart = true;
      settings = {
        FdoSecrets.Enabled = false;
        GUI = {
          CompactMode = true;
          MinimizeOnStartup = true;
          MinimizeOnClose = true;
          MinimizeToTray = true;
          ShowTrayIcon = true;
          TrayIconAppearance = "monochrome-light";
        };
        Browser = {
          Enabled = true;
        };
      };
    };
  };
}
