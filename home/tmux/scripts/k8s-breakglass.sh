#!/usr/bin/env bash

# Break-glass Kubernetes session.
#
# Unlike its neighbours this creates no tmux session of yours. `sudo k8s shell`
# runs its own tmux under a separate account, in a directory that disappears
# when the session closes -- and it refuses to start inside a tmux server
# running as you, because such a server accepts send-keys from any process with
# your uid. That is why this opens a window of its own instead of a pane.
#
# The banner exists because the first thing this window does is ask for a PIN,
# and that prompt comes from sudo's PAM stack before the wrapper has printed a
# single line. Without a word of context it is just a demand for a secret in a
# window that appeared on its own.

cat <<'BANNER'

  Kubernetes break-glass session

  You will be asked to authenticate twice, and it is not the same check twice:

    1. sudo        PIN + touch    that it is you at this machine
    2. age         PIN + touch    to unlock the minting credential in /etc/k8s

  Only then is a cluster-admin token minted, and it is minted for this session
  alone. Closing the window destroys the token, the kubeconfig and the working
  directory. Your own account cannot read any of them while it runs.

  Ctrl-C now if you did not mean to open this.

BANNER

sudo k8s shell --breakglass

printf '\n[session closed -- press enter]'
read -r _
