#!/usr/bin/env bash

# Tmux project session launcher via rofi
SCRIPTS_DIR="$HOME/.config/tmux/scripts"

declare -A PROJECTS
PROJECTS["bidflow"]="$SCRIPTS_DIR/bidflow.sh"
PROJECTS["pixie"]="$SCRIPTS_DIR/pixie.sh"
PROJECTS["nixconf"]="$SCRIPTS_DIR/nixconf.sh"
PROJECTS["k8s"]="$SCRIPTS_DIR/k8s.sh"
PROJECTS["k8s break-glass"]="$SCRIPTS_DIR/k8s-breakglass.sh"

# Extra terminal flags per entry. The app_id is what the sway rules match on --
# see the assign and for_window lines in the sway config. The window's colours
# come from tmux inside the session, not from the terminal that opened it.
declare -A TERMOPTS
TERMOPTS["k8s break-glass"]="--class k8s-breakglass"

chosen=$(printf '%s\n' "${!PROJECTS[@]}" | sort | rofi -dmenu -i -p "tmux session" \
  -config ~/.config/rofi/rofidmenu.rasi)

[ -z "$chosen" ] && exit 0

# An array rather than an unquoted expansion: the flags must split on spaces,
# but a path with a space in it must not.
read -r -a termopts <<< "${TERMOPTS[$chosen]:-}"

exec "${TERMINAL:-kitty}" "${termopts[@]}" -e "${PROJECTS[$chosen]}"
