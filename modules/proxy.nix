{
  config,
  lib,
  ...
}: let
  cfg = config.local.proxy;
  socks = "socks5h://${cfg.socksAddress}:${toString cfg.socksPort}";
in {
  # The single source of truth for the SOCKS5 tunnel. The endpoint has moved
  # twice already (vega -> critical-olive -> vega), so the home-manager side
  # reads these through `osConfig` rather than repeating the numbers.
  options.local.proxy = {
    socksAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the local SOCKS5 proxy listens on.";
    };

    socksPort = lib.mkOption {
      type = lib.types.port;
      default = 1081;
      description = "Port the local SOCKS5 proxy listens on.";
    };

    remote = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "Host the ssh-tunnel user service dials out to.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        description = "SSH user on the tunnel host.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 22;
        description = "SSH port on the tunnel host.";
      };
    };

    nixDaemon.enable =
      lib.mkEnableOption "routing every nix-daemon HTTP fetch through the SOCKS5 tunnel";
  };

  config = lib.mkIf cfg.nixDaemon.enable {
    # Routes ALL of nix-daemon's HTTP fetches through the tunnel, including
    # cache.nixos.org.
    #
    # cache.nixos.org used to go direct to avoid a SOCKS5 dependency for cached
    # builds. That broke on 2026-08-17: cache.nixos.org is Fastly anycast, and
    # our ISP's routing to 3 of its 4 IPs is blackholed -- TCP connects, then
    # packets are silently dropped. Only 151.101.65.91 answered (the others
    # timed out), so which IP curl picked decided whether a build worked. The
    # daemon opens many parallel connections, most landed on dead POPs, its
    # curl threads wedged and it died with SIGABRT ("Nix daemon disconnected
    # unexpectedly").
    #
    # Through the tunnel: 8/8 requests OK at ~0.35s. Pinning the one good IP
    # via extraHosts would be faster (~0.19s) but throws away anycast failover
    # and breaks silently when Fastly rotates POPs.
    #
    # Trade-off accepted: the tunnel is now a hard dependency for every build.
    # If builds start timing out, check ssh-tunnel first -- systemd reports it
    # active even when it has stopped carrying traffic.
    #
    # Side effect worth knowing: fetchurl lists these in its impureEnvVars, so
    # every fixed-output derivation inherits the proxy from here too.
    systemd.services.nix-daemon.environment = {
      https_proxy = socks;
      http_proxy = socks;
      all_proxy = socks;
      no_proxy = "localhost,127.0.0.1";
    };
  };
}
