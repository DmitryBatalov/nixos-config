{
  pkgs,
  nixpkgs-unstable,
  config,
  ...
}: let
  unstable = import nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true; # Explicit config for unstable
  };
in {
  home.packages = with pkgs; [
    (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
    kubectl

    unstable.freelens-bin
  ];
}
