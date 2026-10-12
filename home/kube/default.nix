{pkgs, ...}: {
  # Makes the read-only session from `sudo k8s login` visible as context `ops`
  # beside the contexts in ~/.kube/config. That file stays first, so it keeps
  # deciding current-context and receives what kubectl and gcloud write; the
  # session file is the wrapper's alone. Production is reached by naming it
  # (`--context ops`), not by default.
  home.sessionVariables.KUBECONFIG = "$HOME/.kube/config:$HOME/.kube/k8s-session";

  home.packages = with pkgs; [
    (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
    kubectl
    k9s

    unstable.freelens-bin
  ];
}
