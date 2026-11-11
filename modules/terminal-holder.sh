# Shared by the k8s and gcp wrappers: concatenated into each script, not run.
# Reads TERMINALS, a space-separated list of globs, which each script sets.
#
# Which process holds the master end of our controlling terminal, if it is not
# one of the terminal emulators this machine trusts. Empty means trusted;
# anything else names what was found, or why nothing could be, and is refused.
#
# Whoever holds the master types into the terminal. The check this replaces
# read $TMUX, which one line of `unset TMUX` in ~/.bashrc removed -- and $TMUX
# was the only thing between a privileged session and a pane that anything with
# the user's uid could send-keys into.
#
# An allowlist rather than a list of multiplexers, because the danger is not
# tmux specifically. Measured on this machine: the coding agent itself holds the
# master of four ptys. A session opened on one of those would be typed into
# directly, no send-keys needed.
#
# What this does not do is stop the user's uid once it is hostile. The holder
# is recognised by its comm, which any process of that uid can set -- one line
# in ~/.bashrc can exec a relay named kitty -- and a genuine kitty is drivable
# by the same uid through its own config. Within one uid there is no terminal
# to trust. So this catches the mistakes -- a session opened in your own tmux
# or in an agent's pty -- not an attacker who already runs code as you.
#
# sudo is looked through rather than at. Since 1.9.14 it runs the command on a
# pty of its own by default (use_pty), so the master of our terminal is always
# held by sudo, as root -- which the owner check alone read as "not drivable by
# this uid" and waved through. sudo relays its own controlling terminal, so
# what counts is who holds that one.
#
# Every lookup that fails refuses: "could not tell" is not "nobody".
terminal_holder() {
  local tty index proc holder owner user pattern hops
  local -a patterns
  user=${SUDO_USER:-$(id -un)}
  tty=$(readlink /proc/self/fd/0 2> /dev/null) || {
    printf 'an unreadable stdin'
    return 0
  }
  case $tty in
    /dev/pts/*) index=${tty#/dev/pts/} ;;
    # A kernel console has no master for anyone to hold.
    /dev/tty[0-9]*) return 0 ;;
    *)
      printf '%s, not a terminal' "$tty"
      return 0
      ;;
  esac
  for hops in 1 2 3 4 5 6 7 8; do
    proc=$(pty_master "$index") || {
      printf 'nobody visible on /dev/pts/%s' "$index"
      return 0
    }
    if ! holder=$(cat "$proc/comm" 2> /dev/null) \
      || ! owner=$(stat -c %U "$proc" 2> /dev/null); then
      printf 'a process that went away while looked at'
      return 0
    fi
    if [ "$holder" = sudo ] && [ "$owner" = root ]; then
      index=$(ctty_index "$proc") || {
        printf 'a sudo with no terminal of its own'
        return 0
      }
      [ -n "$index" ] || return 0 # sudo's own terminal is a kernel console
      continue
    fi
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
  printf 'sudo nested %s deep' "$hops"
}

# The /proc directory of the process holding the master of /dev/pts/INDEX;
# fails if there is none to be seen. Only a pty master's fdinfo carries
# tty-index, so one grep over all of them finds it, where a readlink per
# descriptor took seconds. The paths go through xargs, not onto grep's command
# line: there are thousands, and a list too long to exec -- easy to arrange,
# with a small stack limit or many open files -- would otherwise find nobody.
pty_master() {
  local info fd
  while IFS= read -r info; do
    fd=${info/\/fdinfo\///fd/}
    [ "$(readlink "$fd" 2> /dev/null)" = /dev/ptmx ] || continue
    printf '%s' "${info%/fdinfo/*}"
    return 0
  done < <(printf '%s\0' /proc/[0-9]*/fdinfo/* \
    | xargs -0 grep -ls "^tty-index:[[:space:]]*$1\$")
  return 1
}

# The pts index of a process's controlling terminal, from field 7 of its stat;
# empty for a kernel console, failure for none at all. The controlling
# terminal, not fd 0: sudo relays the former, and its stdin may be another.
ctty_index() {
  local stat major minor
  local -a fields
  stat=$(cat "$1/stat" 2> /dev/null) || return 1
  # comm, in parentheses, may itself contain spaces and parentheses.
  read -r -a fields <<< "${stat##*) }"
  [ "${fields[4]:-0}" -ne 0 ] || return 1
  major=$(((fields[4] >> 8) & 0xfff))
  minor=$(((fields[4] & 0xff) | ((fields[4] >> 12) & 0xfff00)))
  case $major in
    13[6-9] | 14[0-3]) printf '%s' $(((major - 136) * 256 + minor)) ;;
    4) ;;
    *) return 1 ;;
  esac
}
