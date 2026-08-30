{
  config,
  lib,
  ...
}: let
  cfg = config.local.certs;
in {
  options.local.certs.russianTrusted.enable =
    lib.mkEnableOption "the Russian Trusted CA root and intermediates";

  config = lib.mkIf cfg.russianTrusted.enable {
    security.pki.certificateFiles = [
      ../certs/russian_trusted_root_ca_pem.crt
      ../certs/russian_trusted_sub_ca_pem.crt
      ../certs/russian_trusted_sub_ca_2024_pem.crt
    ];
  };
}
