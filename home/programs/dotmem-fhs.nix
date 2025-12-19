{pkgs ? import <nixpkgs> {}}:
(
  let
    dotnet = with pkgs.dotnetCorePackages; combinePackages [dotnet_10.sdk dotnet_8.sdk];
  in
    pkgs.buildFHSEnv {
      name = "dotmem";
      profile = ''
        export DOTNET_ROOT=${dotnet}/share/dotnet
        export DOTNET_PATH=${dotnet}/bin/dotnet
        export PATH=$PATH:${dotnet}/share/dotnet

        cat > /tmp/proxychains.conf <<EOF
        # Proxychains config
        strict_chain
        proxy_dns
        remote_dns_subnet 224
        tcp_read_time_out 15000
        tcp_connect_time_out 8000

        # Exclude local addresses
        localnet 127.0.0.0/255.0.0.0
        localnet ::1/128

        [ProxyList]
        socks5 127.0.0.1 1081
        EOF

        export PROXYCHAINS_CONF_FILE=/tmp/proxychains.conf
      '';
      targetPkgs = pkgs:
        with pkgs; [
          # Core libraries
          icu
          zlib
          openssl
          stdenv.cc.cc.lib
          # Graphics/Font libraries
          fontconfig
          freetype
          harfbuzz
          libglvnd
          mesa

          # GTK and dependencies
          gtk3
          glib
          cairo
          pango
          atk
          gdk-pixbuf
          gobject-introspection

          # X11 libraries
          xorg.libX11
          xorg.libXi
          xorg.libXcursor
          xorg.libXrandr
          xorg.libXext
          xorg.libSM
          xorg.libICE
          xorg.libxcb
          xorg.libXcomposite
          xorg.libXdamage
          xorg.libXfixes
          xorg.libXrender

          # Image formats
          libpng
          libjpeg
          libwebp
          libpng

          expat
          proxychains-ng
        ];
      runScript = ''
        proxychains4 /home/dmitry/Downloads/JetBrains.dotMemory.linux-x64.2025.3.0.4/dotMemoryUI
      '';
    }
).env
