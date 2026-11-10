{pkgs, ...}: {
  # Makes the read-only sessions from `sudo k8s login --cluster NAME` visible as
  # contexts `k8s-NAME` beside the contexts in ~/.kube/config. That file stays
  # first, so it keeps deciding current-context and receives what kubectl and
  # gcloud write; the session files are the wrapper's alone. Production is
  # reached by naming it (`--context k8s-NAME`), not by default.
  #
  # A glob rather than a list: which clusters exist is deployment state, kept
  # out of this public repository. It is evaluated when a shell starts, so a
  # session logged in later shows up in the next terminal.
  #
  # Appended to what is already set, never replacing it: a nested shell (tmux,
  # `nix develop`, direnv) keeps its own KUBECONFIG and only gains sessions it
  # lacks. Plain files only -- a directory makes every kubectl call fail -- and
  # no name with `:`, which KUBECONFIG would split, or an editor's `~` backup.
  programs.bash.initExtra = ''
    KUBECONFIG=''${KUBECONFIG:-$HOME/.kube/config}
    for f in "$HOME"/.kube/k8s-sessions/*; do
      [ -f "$f" ] || continue
      case $f in *:* | *~) continue ;; esac
      case :$KUBECONFIG: in *:"$f":*) continue ;; esac
      KUBECONFIG=$KUBECONFIG:$f
    done
    unset f
    export KUBECONFIG
  '';

  home.packages = with pkgs; [
    (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
    kubectl
    k9s

    unstable.freelens-bin
  ];
}
