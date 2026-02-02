#!/usr/bin/env bash

# Tmux project session launcher via rofi
SCRIPTS_DIR="$HOME/.config/tmux/scripts"

declare -A PROJECTS
PROJECTS["bidflow"]="$SCRIPTS_DIR/bidflow.sh"
PROJECTS["pixie"]="$SCRIPTS_DIR/pixie.sh"
PROJECTS["nixconf"]="$SCRIPTS_DIR/nixconf.sh"

chosen=$(printf '%s\n' "${!PROJECTS[@]}" | sort | rofi -dmenu -i -p "tmux session" \
  -config ~/.config/rofi/rofidmenu.rasi)

[ -z "$chosen" ] && exit 0

exec "${TERMINAL:-alacritty}" -e "${PROJECTS[$chosen]}"
