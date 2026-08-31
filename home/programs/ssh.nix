{
  # enable ssh agent (i.e. access remote git repo with ssh key)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
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
    };
  };

  services.ssh-agent.enable = true;
}
