{
  config,
  pkgs,
  lib,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  networking = {
    hostName = "vega";
    useDHCP = lib.mkDefault true;
    firewall = {
      enable = true;
      allowedTCPPorts = [443];
    };
  };

  # ============================= User =============================

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDaci07bJRxAFOdZIX+INNbEVmXhERlKShpfVoGRPga/ dmitry"
    ];
  };

  # ============================= Nix =============================

  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nixpkgs.config.allowUnfree = true;

  # ============================= Locale =============================

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # ============================= SSH =============================

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };

  # ============================= XRay VLESS + Reality =============================

  services.xray = {
    enable = true;
    settingsFile = "/etc/xray/config.json";
  };

  # ============================= Packages =============================

  # Generate xray config on first boot if it doesn't exist
  system.activationScripts.xray-config = ''
    if [ ! -f /etc/xray/config.json ]; then
      mkdir -p /etc/xray
      KEYS=$(${pkgs.xray}/bin/xray x25519)
      PRIVATE_KEY=$(echo "$KEYS" | ${pkgs.gawk}/bin/awk '/Private key:/ {print $3}')
      PUBLIC_KEY=$(echo "$KEYS" | ${pkgs.gawk}/bin/awk '/Public key:/ {print $3}')
      UUID=$(${pkgs.xray}/bin/xray uuid)
      SHORT_ID=$(${pkgs.openssl}/bin/openssl rand -hex 8)

      cat > /etc/xray/config.json <<EOF
    {
      "log": { "loglevel": "warning" },
      "inbounds": [
        {
          "listen": "0.0.0.0",
          "port": 443,
          "protocol": "vless",
          "settings": {
            "clients": [
              {
                "id": "$UUID",
                "flow": "xtls-rprx-vision"
              }
            ],
            "decryption": "none"
          },
          "streamSettings": {
            "network": "tcp",
            "security": "reality",
            "realitySettings": {
              "dest": "www.microsoft.com:443",
              "serverNames": ["www.microsoft.com"],
              "privateKey": "$PRIVATE_KEY",
              "shortIds": ["$SHORT_ID"]
            }
          },
          "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls", "quic"]
          }
        }
      ],
      "outbounds": [
        { "protocol": "freedom", "tag": "direct" },
        { "protocol": "blackhole", "tag": "block" }
      ]
    }
    EOF

      chmod 600 /etc/xray/config.json

      echo "================================================="
      echo "XRay VLESS Reality setup complete!"
      echo "Public key: $PUBLIC_KEY"
      echo "Client UUID: $UUID"
      echo "Short ID: $SHORT_ID"
      echo "================================================="
      echo "Public key: $PUBLIC_KEY" > /etc/xray/client-info.txt
      echo "Client UUID: $UUID" >> /etc/xray/client-info.txt
      echo "Short ID: $SHORT_ID" >> /etc/xray/client-info.txt
      chmod 600 /etc/xray/client-info.txt
    fi
  '';

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    htop
    xray
  ];

  system.stateVersion = "23.11";
}
