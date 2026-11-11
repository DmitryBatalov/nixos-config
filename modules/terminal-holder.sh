# Shared by the k8s and gcp wrappers: concatenated into each script, not run.
# Reads TERMINALS, a space-separated list of globs, which each script sets.
#
# Which process holds the master end of our controlling terminal, if it is not
# one of the terminal emulators this machine trusts.
#
# That ownership is part of the wiring rather than something a program claims
# about itself: whoever holds the master types into the terminal, and no shell
# profile can change who that is. The check this replaces read $TMUX, which one
# line of `unset TMUX` in an attacker-writable ~/.bashrc removed -- and $TMUX was
# the only thing standing between a privileged session and a pane that anything
# with the user's uid could send-keys into.
#
# An allowlist rather than a list of multiplexers, because the danger is not
# tmux specifically. Measured on this machine: the coding agent itself holds the
# master of four ptys. A session opened on one of those would be typed into
# directly, no send-keys needed. Anything not recognised as a terminal the human
# is sitting at is therefore refused, and the caller is told what it saw.
terminal_holder() {
  local tty index proc fd target idx holder owner user pattern
  local -a patterns
  user=${SUDO_USER:-$(id -un)}
  tty=$(readlink /proc/self/fd/0 2> /dev/null) || return 0
  case $tty in
    /dev/pts/*) index=${tty#/dev/pts/} ;;
    *) return 0 ;;
  esac
  for proc in /proc/[0-9]*; do
    [ -r "$proc/fd" ] || continue
    for fd in "$proc"/fd/*; do
      target=$(readlink "$fd" 2> /dev/null) || continue
      [ "$target" = /dev/ptmx ] || continue
      idx=$(sed -n 's/^tty-index:[[:space:]]*//p' "$proc/fdinfo/${fd##*/}" 2> /dev/null)
      [ "$idx" = "$index" ] || continue
      holder=$(cat "$proc/comm" 2> /dev/null) || continue
      owner=$(stat -c %U "$proc" 2> /dev/null) || continue
      # A master held by another user is not something this uid can drive.
      [ "$owner" = "$user" ] || return 0
      # read -ra splits on whitespace without pathname expansion; a bare
      # `for pattern in $TERMINALS` would try to match *kitty* against files.
      read -r -a patterns <<< "$TERMINALS"
      for pattern in "${patterns[@]}"; do
        # shellcheck disable=SC2254  # the patterns are globs on purpose
        case $holder in
          $pattern) return 0 ;;
        esac
      done
      printf '%s' "$holder"
      return 0
    done
  done
}
