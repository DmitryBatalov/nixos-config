#!/usr/bin/env bash

# Break-glass Kubernetes session.
#
# Unlike its neighbours this creates no tmux session of yours. `sudo k8s shell`
# runs its own tmux under a separate account, in a directory that disappears
# when the session closes -- and it refuses to start inside a tmux server
# running as you, because such a server accepts send-keys from any process with
# your uid. That is why this opens a window of its own instead of a pane.

sudo k8s shell --breakglass

printf '\n[session closed -- press enter]'
read -r _
