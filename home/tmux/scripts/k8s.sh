#!/usr/bin/env bash

# Configuration
SESSION_NAME="k8s"
WORKING_DIR="$HOME"

# Attach if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  exec tmux attach-session -t "$SESSION_NAME"
fi

# Create new session with windows
tmux new-session -d -s "$SESSION_NAME" -n "k9s" -c "$WORKING_DIR" k9s
tmux new-window -t "$SESSION_NAME" -n "cmd" -c "$WORKING_DIR"

# Select first window and attach
tmux select-window -t "$SESSION_NAME:1"
exec tmux attach-session -t "$SESSION_NAME"
