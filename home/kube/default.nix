{pkgs, ...}: {
  # The read-only sessions from `sudo k8s login --cluster NAME` are contexts
  # `k8s-NAME` in the stock ~/.kube/config, so kubectl and k9s need no
  # KUBECONFIG. login leaves current-context alone: production is reached by
  # naming it (`--context k8s-NAME`), not by default.
  #
  # No gcloud here: Google Cloud is administered through `sudo gcp`, which
  # brings its own, and the everyday account keeps no token on this machine.
  home.packages = with pkgs; [
    kubectl
    k9s
  ];
}
