#!/usr/bin/env bash

# Configuration
SESSION_NAME="nixconf"
WORKING_DIR="$HOME/projects/nixos-config"

# Attach if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  exec tmux attach-session -t "$SESSION_NAME"
fi

# Create new session with windows
tmux new-session -d -s "$SESSION_NAME" -n "git" -c "$WORKING_DIR"
tmux new-window -t "$SESSION_NAME" -n "code" -c "$WORKING_DIR"
tmux new-window -t "$SESSION_NAME" -n "claude" -c "$WORKING_DIR"
tmux new-window -t "$SESSION_NAME" -n "cmd" -c "$WORKING_DIR"

# Select second window and attach
tmux select-window -t "$SESSION_NAME:2"
exec tmux attach-session -t "$SESSION_NAME"
