{pkgs, ...}: {
  # For hosts only reachable through the tunnel:
  #   ProxyCommand nc -X 5 -x 127.0.0.1:1081 %h %p
  home.packages = [pkgs.netcat-openbsd];

  # enable ssh agent (i.e. access remote git repo with ssh key)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # Per-machine hosts, kept out of this public repository.
    includes = ["config.local"];
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
      };
      # ASUS RT-AC1200 running Padavan; dropbear v2017.75 only speaks
      # ssh-rsa (SHA-1) for both host and user key auth. Reached via
      # AC1200's WAN-side IP+port from Keenetic LAN (192.168.1.x).
      "ac1200" = {
        HostName = "192.168.1.142";
        Port = 10022;
        User = "admin";
        IdentityFile = "~/.ssh/id_rsa";
        IdentitiesOnly = "yes";
        PubkeyAcceptedAlgorithms = "+ssh-rsa";
        HostkeyAlgorithms = "+ssh-rsa,ecdsa-sha2-nistp521";
      };
      # Headless NixOS box (hosts/atlas). The address is a DHCP reservation
      # on the Keenetic; deploys use it too:
      # nixos-rebuild switch --flake .#atlas --target-host atlas --sudo --ask-sudo-password
      "atlas" = {
        HostName = "192.168.1.46";
        User = "dmitry";
        # For git on atlas, which holds no keys of its own. The cost: while a
        # session is open, any process there that can reach the socket can
        # sign with every key in this agent.
        ForwardAgent = "yes";
      };
    };
  };

  services.ssh-agent.enable = true;
}
