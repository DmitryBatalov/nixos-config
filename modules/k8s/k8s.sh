#!/usr/bin/env bash
# k8s -- hardware-gated Kubernetes access.
#
#   sudo k8s login            unlock once, get a read-only session for the day
#   kubectl / k9s             then just work, as you, until it expires
#   sudo k8s --breakglass …   privileged actions, gated on every single call
#   sudo k8s shell            a working session under a uid you cannot read
#   k8s logout                drop the session early
#
# The privileged kubeconfig never exists in the clear on disk: it is
# age-encrypted to a FIDO2 credential on a hardware token, and decrypted into
# memory only for as long as it takes to mint a short-lived ServiceAccount
# token. On a token with a PIN set, hmac-secret assertions require the PIN/UV
# protocol by construction, so that factor cannot silently drift off.
#
# Four choices that are load-bearing, none of them obvious:
#
#   Privileged commands run AS ROOT. Running them as the invoking user would
#   require the temp kubeconfig to be readable by that user, handing the live
#   token to every process running as them -- including the coding agent this
#   exists to keep out.
#
#   The session from `login` deliberately does the opposite: a user-owned file,
#   written BY THE USER via sudo -u. A long-running interactive tool is safer as
#   the user than as root -- same RBAC either way, but no root process sitting
#   in a tmux pane that anything running as the user can drive with send-keys.
#   Writing as the user is also what makes $HOME safe to touch at all: it is
#   attacker-controlled here, and `ln -s / ~/.kube` would otherwise turn root's
#   chown into `chown user /`. Dropping privileges beats checking for symlinks,
#   which is a check-then-use race.
#
#   Tools are looked up ONLY in K8S_TOOL_PATH (store paths pinned at build time)
#   and the system profile, never a user-writable directory: this runs as root,
#   so a planted `kubectl` would be executed by it.
#
#   Settings arrive as assignments injected above this line by the Nix module,
#   not as environment variables -- sudo's env_reset would strip those.

set -euo pipefail

# The wrapper's own PATH holds only what it shells out to, plus the setuid sudo.
# Deliberately not the system profile: that is the session's PATH, and run mode
# must not inherit it. The fallback matters only where nothing was pinned at
# build time.
PATH="${K8S_TOOL_PATH:-/run/current-system/sw/bin:/usr/bin:/bin}"
export PATH

CIPHER=${K8S_MINTER_AGE:-/etc/k8s/minter.conf.age}
IDENTITY=${K8S_AGE_IDENTITY:-/etc/k8s/identity.txt}
SA_NS=${K8S_SA_NAMESPACE:-team-access}
SA_RO=${K8S_SA_RO:-ops-ro}
SA_BG=${K8S_SA_BREAKGLASS:-breakglass}

TTL=${K8S_TTL:-15m}
MAX_TTL_SECONDS=${K8S_MAX_TTL_SECONDS:-86400}
TERMINALS=${K8S_TERMINALS:-*kitty* *foot* *alacritty* *wezterm* *ghostty* xterm* st}
SESSION_TTL=${K8S_SESSION_TTL:-8h}
SESSION_FILE=${K8S_SESSION_FILE:-.kube/k8s-session}
# `${VAR-default}` rather than `${VAR:-default}`: an *empty* value is a
# deliberate "nothing may run", and the colon form would silently replace it
# with the wrapper's own PATH -- turning allowedTools = [] into the widest
# setting there is instead of the narrowest.
RUN_PATH=${K8S_RUN_PATH-$PATH}
SHELL_PATH=${K8S_SHELL_PATH-$PATH}
OPS_USER=${K8S_OPS_USER:-k8s-ops}
SHELL_TTL=${K8S_SHELL_TTL:-1h}
K9S_SKIN=${K8S_K9S_SKIN:-}
MARKER='# k8s-session: written by "sudo k8s login", safe to delete'
NS=

usage() {
  cat >&2 <<'USAGE'
Usage:
  sudo k8s login [--ttl DURATION] [--force]   read-only session (default 8h)
       k8s logout                             drop it
  sudo k8s shell [--breakglass] [--ttl D]     a session under a separate uid
  sudo k8s [--breakglass] [--ttl D] [-n NS] <tool> [args...]

  --breakglass    assume the break-glass identity: full cluster-admin, named in
                  the audit log. Deliberately not called --rw: it is not
                  write access, it is everything.
  --ttl DURATION  token lifetime, e.g. 15m, 4h
  -n, --ns NS     default namespace
  --force         login: replace a session file this tool did not write

  shell runs tmux as a dedicated account in a directory that exists only for
  the length of the session. Nothing of it is readable by you, which is the
  point: a token you can read is a token anything running as you can read.
  It refuses to start inside your own tmux -- that server holds the pane and
  takes send-keys from any process with your uid.

  sudo k8s login
  k9s
  sudo k8s --breakglass kubectl rollout restart deploy/api -n some-namespace
USAGE
}

# Home of the human behind sudo. getent covers Linux; macOS keeps regular users
# in Directory Services. dscl folds long values onto a continuation line, so
# match the field rather than taking column two.
user_home() {
  local u=$1 h=
  if command -v getent > /dev/null 2>&1; then
    h=$(getent passwd "$u" | cut -d: -f6)
  fi
  if [ -z "$h" ] && command -v dscl > /dev/null 2>&1; then
    h=$(dscl . -read "/Users/$u" NFSHomeDirectory 2> /dev/null \
      | sed -n 's/^NFSHomeDirectory: //p')
  fi
  printf '%s' "$h"
}

# First line of a session file we wrote. Substring rather than the full marker:
# the marker contains quotes that read badly inline.
written_by_us() { head -1 "$1" 2> /dev/null | grep -qF 'k8s-session'; }

die() {
  printf 'k8s: %s\n' "$1" >&2
  exit "${2:-1}"
}

ACCOUNTS_FILE=${K8S_ACCOUNTS_FILE:-/etc/k8s/accounts}

# The namespace and the two account names are deployment state, not
# configuration: they say which namespace on which cluster holds an account with
# full rights. The module that carries this script is public, so they live
# beside the credential instead -- root-owned, and absent from any repository.
# Without the file the build-time defaults apply unchanged.
#
# Parsed, not sourced. The file belongs to root, but these values are
# interpolated into kubectl's argv and into a generated kubeconfig, so they are
# read as data and then checked, rather than executed and trusted.
if [ -r "$ACCOUNTS_FILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in
      '#'* | '') continue ;;
    esac
    key=${line%%=*}
    val=${line#*=}
    key=${key//[[:space:]]/}
    val=${val//[[:space:]]/}
    case $key in
      namespace) SA_NS=$val ;;
      readonly) SA_RO=$val ;;
      breakglass) SA_BG=$val ;;
      *) die "$ACCOUNTS_FILE: unknown key '$key'" ;;
    esac
  done < "$ACCOUNTS_FILE"
fi

# Checked whether they came from the file or from the module. A namespace is a
# DNS-1123 label, a ServiceAccount name a subdomain, so the latter may contain
# dots and the former may not. Both are interpolated into a kubeconfig below,
# and a name carrying a quote or a newline would break out of it.
case $SA_NS in
  *[!a-z0-9-]* | -* | *- | "") die "not a valid namespace: $SA_NS" ;;
esac
for sa in "$SA_RO" "$SA_BG"; do
  case $sa in
    *[!a-z0-9.-]* | [-.]* | *[-.] | "") die "not a valid ServiceAccount name: $sa" ;;
  esac
done

# Which process holds the master end of our controlling terminal. That is part
# of the wiring rather than something a program claims about itself: a terminal
# multiplexer necessarily holds the master of every pane it draws, and no shell
# profile can change that. The previous check read $TMUX, which `unset TMUX` in
# an attacker-writable ~/.bashrc removed -- the guard the whole session design
# rests on, defeated by one line.
#
# Printed rather than returned, so the caller can name the offender.
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

# ------------------------------------------------------------- arguments ----
# The subcommand comes first, before the option loop: otherwise `k8s login
# --ttl 4h` parses as "tool=login, leftover args" and the flags are discarded.
mode=run
case "${1:-}" in
  login | logout | shell) mode=$1; shift ;;
esac

profile=ro
force=0
ttl_given=0
while [ $# -gt 0 ]; do
  case "$1" in
    --breakglass) profile=breakglass; shift ;;
    --ro) profile=ro; shift ;;
    --force) force=1; shift ;;
    --ttl) TTL=${2:?--ttl needs a value}; ttl_given=1; shift 2 ;;
    -n | --ns) NS=${2:?--ns needs a value}; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    --) shift; break ;;
    -*) printf 'k8s: unknown option: %s\n' "$1" >&2; usage; exit 2 ;;
    *) break ;;
  esac
done

if [ "$mode" = run ] && [ $# -lt 1 ]; then
  usage
  exit 2
fi
if [ "$mode" != run ] && [ $# -gt 0 ]; then
  die "$mode takes no further arguments: $*" 2
fi

if [ "$mode" = run ]; then
  tool=$1
  shift

  if [ "$tool" = k9s ]; then
    printf 'k8s: k9s is not run through the wrapper -- it would be a root process in\n' >&2
    printf '     your terminal for as long as it stays open, and anything running as\n' >&2
    printf '     you could drive it. Run "sudo k8s shell" and start k9s inside, where the\n' >&2
    printf '     tmux server belongs to another account, or "sudo k8s login" and run it\n' >&2
    printf '     as yourself.\n' >&2
    exit 2
  fi

  case "$tool" in
    login | logout)
      die "put '$tool' first: sudo k8s $tool [options]" 2
      ;;
  esac


  # Hygiene, not a boundary -- the caller is root anyway. It keeps the
  # connection the wrapper set up from being silently swapped for another one.
  for arg in "$@"; do
    case "$arg" in
      --) break ;;
      --kubeconfig | --kubeconfig=* | --token | --token=* | --as | --as=* \
        | --as-group | --as-group=* | --server | --server=* \
        | --kube-apiserver | --kube-apiserver=* | --kube-token | --kube-token=* \
        | --kube-as-user | --kube-as-user=* | --kube-ca-file | --kube-ca-file=*)
        die "${arg%%=*} is not allowed -- the wrapper owns the connection" 2
        ;;
    esac
  done
fi

# NS is interpolated into YAML below, and TTL into --duration. Reject both here
# rather than after the PIN and the touch have already been spent.
case "$NS" in
  "") ;;
  *[!a-z0-9-]* | -* | *-) die "not a valid namespace: $NS" 2 ;;
esac
case "$TTL" in
  *[!0-9smh]* | [!0-9]* | *[!smh] | "")
    die "not a valid duration: $TTL (expected e.g. 15m, 8h)" 2
    ;;
esac
ttl_n=${TTL%[smh]}
case "$ttl_n" in
  *[!0-9]* | "") die "not a valid duration: $TTL (single unit only, e.g. 90m)" 2 ;;
esac
case "${TTL#"$ttl_n"}" in
  s) ttl_seconds=$ttl_n ;;
  m) ttl_seconds=$((ttl_n * 60)) ;;
  h) ttl_seconds=$((ttl_n * 3600)) ;;
  *) die "not a valid duration: $TTL" 2 ;;
esac
# The apiserver refuses anything under 10 minutes, and it refuses it *after*
# the PIN and the touch have been spent. Catch it here instead.
if [ "$ttl_seconds" -lt 600 ]; then
  die "duration must be at least 10m -- the apiserver rejects anything shorter" 2
fi
# And a ceiling. There was only a floor, so `k8s login --ttl 8760h` minted a
# year-long token into a file the agent reads by design. Whether the cluster
# honours it depends on --service-account-max-token-expiration, which the
# wrapper cannot see, so refusing here does not depend on the cluster's setting.
if [ "$ttl_seconds" -gt "$MAX_TTL_SECONDS" ]; then
  die "duration must be at most $((MAX_TTL_SECONDS / 3600))h" 2
fi

if [ "$mode" = login ] && [ "$profile" != ro ]; then
  die "login mints a read-only session; use 'sudo k8s --breakglass <tool>' to escalate" 2
fi

if [ "$mode" = shell ]; then
  [ -t 0 ] || die "shell needs a terminal" 2
  id -u "$OPS_USER" > /dev/null 2>&1 || die "no such account: $OPS_USER"

  mux=$(terminal_holder)
  if [ -n "$mux" ]; then
    printf 'k8s: this terminal is held by "%s", running as you. Whoever holds a\n' "$mux" >&2
    printf '     terminal types into it -- that is what holding it means -- so a\n' >&2
    printf '     privileged session opened here would be drivable by anything with your\n' >&2
    printf '     uid. For a multiplexer that is an offered command; for anything else it\n' >&2
    printf '     is simply the wiring.\n' >&2
    printf '\n' >&2
    printf '     Start it from a terminal emulator instead -- the ones named in\n' >&2
    printf '     local.k8s.access.terminals. A multiplexer *inside* the session is fine\n' >&2
    printf '     and is what it runs: that one belongs to %s, which nothing running as\n' "$OPS_USER" >&2
    printf '     you can reach.\n' >&2
    exit 2
  fi
fi

target_user=${SUDO_USER:-$(id -un)}
target_home=$(user_home "$target_user")
[ -n "$target_home" ] || die "cannot determine the home directory of $target_user"
session_config="$target_home/$SESSION_FILE"

# ---------------------------------------------------------------- logout ----
# No privileges needed: it removes a file the user owns.
if [ "$mode" = logout ]; then
  # `head` and `rm` below both follow symlinks, and the path they follow lives
  # in $HOME -- attacker-controlled in this threat model. `login` was hardened
  # against exactly this by writing through `sudo -u`; logout has to drop the
  # same way, or a symlink turns root's `rm` into someone else's choice of file.
  if [ "$(id -u)" -eq 0 ]; then
    exec sudo -u "$target_user" "$0" logout
  fi
  [ -e "$session_config" ] || die "no session" 0
  written_by_us "$session_config" \
    || die "$session_config was not written by this tool, refusing to delete it"
  rm -f "$session_config"
  printf 'k8s: session dropped\n' >&2
  exit 0
fi

# Everything above needs no privileges, so misuse is reported without sudo.
if [ "$(id -u)" -ne 0 ]; then
  die "must be run through sudo"
fi

# Run mode's PATH is the boundary, and two lookups do not respect it.
#
# `command -v` resolves a name containing a slash without consulting PATH at
# all, so `k8s --breakglass ./script` would run an arbitrary file as root with a
# live token. And it reports success for shell builtins with any PATH, so
# `k8s --breakglass exec /bin/bash` would run the builtin and hand out a root
# shell. `type -P` refuses builtins -- it returns only an executable file found
# in PATH -- but it still resolves a slashed path, so the slash is rejected
# separately. The resolved absolute path is what gets executed, so there is no
# second lookup to disagree with the first.
if [ "$mode" = run ]; then
  # An empty PATH is read as the current directory by some shells, so this must
  # refuse rather than fall through to a lookup.
  [ -n "$RUN_PATH" ] \
    || die "no tools are allowed to run: allowedTools is empty" 2

  case $tool in
    */*) die "give a tool name, not a path: $tool" 2 ;;
  esac
  # shellcheck disable=SC2030  # the subshell is the point: the narrow PATH must
  # not leak back into the wrapper, which still needs chmod and mktemp below.
  tool_path=$(
    PATH=$RUN_PATH
    type -P -- "$tool" || true
  )
  [ -n "$tool_path" ] \
    || die "$tool is not one of the tools this wrapper may run ($RUN_PATH)" 2
fi

case $profile in
  ro) SA=$SA_RO ;;
  breakglass) SA=$SA_BG ;;
  *) die "unknown profile" 2 ;;
esac

# Everything that can refuse the request must refuse it here: past this point
# the user has already spent a PIN entry and a touch.
first_login=0
if [ "$mode" = login ]; then
  [ "$ttl_given" -eq 1 ] || TTL=$SESSION_TTL
  [ -e "$session_config" ] || first_login=1
  if [ -e "$session_config" ] && [ "$force" -ne 1 ] && ! written_by_us "$session_config"; then
    die "$session_config exists and was not written by this tool; use --force to replace it"
  fi
fi

if [ "$mode" = shell ]; then
  [ "$ttl_given" -eq 1 ] || TTL=$SHELL_TTL
fi

for f in "$CIPHER" "$IDENTITY"; do
  [ -r "$f" ] || die "cannot read $f"
done

# ---------------------------------------------------------------- unlock ----
# /run and /var/run are tmpfs and cleared at boot. /tmp on this host sits on the
# root disk with no aging rule, so a directory left behind by SIGKILL -- which
# no trap can catch -- would linger there indefinitely.
runtime_dir=${TMPDIR:-/tmp}
for d in /run /var/run; do
  if [ -d "$d" ] && [ -w "$d" ]; then
    runtime_dir=$d
    break
  fi
done

umask 077
work=$(mktemp -d "$runtime_dir/k8s-wrapper.XXXXXXXX")
chmod 700 "$work"
export HOME="$work" # keep every tool's cache, plugins and config out of /root
# The tmux server is torn down here rather than after the client returns, so it
# happens on a signal too. Ctrl-\ sends SIGQUIT, and bash dies on an untrapped
# fatal signal *without* running the EXIT trap -- which used to leave a detached
# ops server holding a live token for the rest of its TTL.
cleanup() {
  if [ -n "${sess:-}" ] && [ -S "$sess/tmux.sock" ]; then
    # shellcheck disable=SC2031  # the wrapper's own PATH, untouched here: the
    # narrowing in run mode happens in a subshell and after this is registered.
    sudo -u "$OPS_USER" env -i PATH="$PATH" \
      tmux -S "$sess/tmux.sock" kill-server > /dev/null 2>&1 || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT

# One handler per signal, so the exit status still names which arrived. A trap
# that merely returns would resume the script instead of stopping it.
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 131' QUIT
trap 'exit 143' TERM

# Decrypt into memory, never onto disk. age-plugin-fido2-hmac writes its PIN
# prompt to /dev/tty, so command substitution -- which captures only stdout --
# still lets the prompt reach the terminal.
printf 'k8s: unlocking the minter kubeconfig -- the token wants its PIN and a touch.\n' >&2
printf '     The plugin overwrites its own prompt line, so the PIN request can look\n' >&2
printf '     like a blank line waiting for input. Type it anyway.\n' >&2
minter=$(age -d -i "$IDENTITY" "$CIPHER")

# printf here must stay a shell builtin: an external one would put the whole
# kubeconfig into a process's argv, visible in /proc/*/cmdline.
kc() { kubectl --kubeconfig <(printf '%s' "$minter") "$@"; }

minted=$(kc create token "$SA" -n "$SA_NS" --duration="$TTL" -o json)
token=$(printf '%s' "$minted" | jq -r '.status.token')
expires=$(printf '%s' "$minted" | jq -r '.status.expirationTimestamp')

# The only value interpolated into the generated tmux.conf that is not a
# build-time constant, and it comes from whatever the kubeconfig points at. A
# crafted response could close the quoting and append a run-shell directive.
case $expires in
  *[!0-9TZ:.+-]* | "") die "the cluster returned an implausible expiry: $expires" ;;
esac

# One view, four fields. The raw output stays inside the pipe on purpose: it
# carries the minter credential, which must not reach a shell variable or a
# herestring's temp file.
{
  read -r server
  read -r ca_data
  read -r ca_file
  read -r insecure
} < <(kc config view --raw --minify -o json | jq -r '
        .clusters[0].cluster
        | (.server // ""),
          (."certificate-authority-data" // ""),
          (."certificate-authority" // ""),
          ((."insecure-skip-tls-verify" // false) | tostring)')

# Frees the allocation and keeps it out of any subshell forked from here on.
# Not erasure: bash does not zero freed memory, and the process substitutions
# above already forked copy-on-write copies.
unset minter minted

[ -n "$server" ] || die "the minter kubeconfig has no server for its current context"
[ -n "$token" ] && [ "$token" != null ] || die "the cluster returned no token"

render_kubeconfig() {
  printf '%s\n' "$MARKER"
  printf '# identity: system:serviceaccount:%s:%s\n' "$SA_NS" "$SA"
  printf '# expires:  %s\n' "$expires"
  printf 'apiVersion: v1\nkind: Config\nclusters:\n- name: target\n  cluster:\n'
  printf '    server: %s\n' "$server"
  if [ -n "$ca_data" ]; then
    printf '    certificate-authority-data: %s\n' "$ca_data"
  elif [ -n "$ca_file" ]; then
    printf '    certificate-authority: %s\n' "$ca_file"
  fi
  if [ "$insecure" = true ]; then printf '    insecure-skip-tls-verify: true\n'; fi
  printf 'users:\n- name: ops\n  user:\n    token: %s\n' "$token"
  printf 'contexts:\n- name: ops\n  context:\n    cluster: target\n    user: ops\n'
  if [ -n "$NS" ]; then printf '    namespace: %s\n' "$NS"; fi
  printf 'current-context: ops\n'
}

# ----------------------------------------------------------------- login ----
if [ "$mode" = login ]; then
  session_dir=$(dirname "$session_config")
  # Both the mkdir and the write run as the user. If ~/.kube is a symlink into
  # /etc, the write fails with EACCES instead of landing a user-owned file
  # somewhere the attacker chose -- race-free, unlike testing for a symlink.
  sudo -u "$target_user" mkdir -p "$session_dir"
  render_kubeconfig | sudo -u "$target_user" sh -c 'umask 077; cat > "$1"' sh "$session_config"
  unset token
  printf 'k8s: read-only session for %s until %s\n' "$target_user" "$expires" >&2
  printf 'k8s: kubectl and k9s now work without sudo. "k8s logout" ends it.\n' >&2
  if [ "$first_login" -eq 1 ]; then
    printf "k8s: put this in your shell profile so both clusters coexist --\n" >&2
    printf "       gcloud writes ~/.kube/config, this writes the session file:\n" >&2
    printf "       export KUBECONFIG=\$HOME/.kube/config:\$HOME/%s\n" "$SESSION_FILE" >&2
  fi
  exit 0
fi

# ----------------------------------------------------------------- shell ----
if [ "$mode" = shell ]; then
  # Everything the session owns lives inside $work, which the EXIT trap removes.
  # Closing the shell takes the kubeconfig, the tmux socket and the working
  # directory with it -- there is no state to forget to clean up. $work becomes
  # traversable but not listable, so the ops account can reach its own directory
  # and learn nothing about what else is in /run.
  chmod 711 "$work"
  sess=$work/session
  mkdir -p "$sess/work"

  render_kubeconfig > "$sess/config"
  unset token

  # A bare tmux and a bare bash: none of the invoking user's dotfiles are
  # readable from here, and that is deliberate rather than a limitation. A
  # shared rc file is executable code, so sharing one would hand anything
  # running as that user a way to run commands inside this session.
  {
    printf 'set -g default-terminal "tmux-256color"\n'
    printf 'set -g history-limit 20000\n'
    printf 'set -g mouse on\n'
    printf 'set -g status-left-length 40\n'
    printf 'set -g status-right-length 60\n'
    if [ "$profile" = breakglass ]; then
      # The window background comes from tmux, not from the terminal that
      # launched it: the colour then means "a privileged session is running"
      # rather than "kitty was started with a flag". Nothing outside the session
      # paints it, so the mark cannot survive the session that earned it.
      printf 'set -g window-style "bg=#2b0b0b,fg=#ffd7af"\n'
      printf 'set -g window-active-style "bg=#2b0b0b,fg=#ffd7af"\n'
      printf 'set -g pane-border-style fg=#7f1d1d\n'
      printf 'set -g pane-active-border-style fg=#ff3b3b\n'
      printf 'set -g status-style bg=colour52,fg=colour223\n'
      printf 'set -g status-left " BREAK-GLASS  %s "\n' "$SA"
    else
      printf 'set -g window-style "bg=#08052b,fg=#d0d8ff"\n'
      printf 'set -g window-active-style "bg=#08052b,fg=#d0d8ff"\n'
      printf 'set -g pane-border-style fg=#1c2a4a\n'
      printf 'set -g pane-active-border-style fg=#5294e2\n'
      printf 'set -g status-style bg=colour23,fg=colour231\n'
      printf 'set -g status-left " read-only  %s "\n' "$SA"
    fi
    printf 'set -g default-command "bash --rcfile %s/.bashrc -i"\n' "$sess"
    printf 'set -g status-right " expires %s "\n' "$expires"
  } > "$sess/tmux.conf"

  {
    # /etc/bashrc runs before this file and, because env -i left its guard
    # variable unset, sources /etc/profile -- which replaces PATH with the system
    # default. This file is read last, so it is where the session's own PATH is
    # re-asserted.
    printf 'export PATH=%s\n' "$SHELL_PATH"
    printf 'PS1="[%s] \\w \\$ "\n' "$SA"
    printf 'export KUBECONFIG=%s/config\n' "$sess"
    printf 'cd %s/work\n' "$sess"
    printf 'alias k=kubectl\n'
  } > "$sess/.bashrc"

  # k9s reads its configuration from $HOME, which here is the session directory,
  # so its skin is per-session too and goes away with it. The transparent skin
  # paints no background of its own, leaving the one tmux just set: the session's
  # colour keeps a single definition instead of two that drift apart.
  # The skin and the read-only flag are unrelated, and keeping the flag inside
  # the skin's condition meant a renamed path in nixpkgs would silently drop it.
  mkdir -p "$sess/.config/k9s"
  {
    printf 'k9s:\n'
    # Not a boundary -- RBAC is -- but a read-only session should not be
    # offering commands the apiserver will refuse anyway.
    if [ "$profile" = ro ]; then printf '  readOnly: true\n'; fi
    printf '  ui:\n'
    if [ -n "$K9S_SKIN" ] && [ -r "$K9S_SKIN" ]; then
      mkdir -p "$sess/.config/k9s/skins"
      cat "$K9S_SKIN" > "$sess/.config/k9s/skins/transparent.yaml"
      printf '    skin: transparent\n'
    fi
  } > "$sess/.config/k9s/config.yaml"

  chown -R "$OPS_USER" "$sess"
  chmod 700 "$sess" "$sess/work"
  chmod 600 "$sess/config"

  printf 'k8s: session as system:serviceaccount:%s:%s until %s\n' "$SA_NS" "$SA" "$expires" >&2
  printf 'k8s: running as %s. Your home is not readable from here, and this\n' "$OPS_USER" >&2
  printf '     directory disappears when you close the session.\n' >&2

  # tmux needs a terminfo entry for the terminal it is talking to, and `env -i`
  # drops the search path that would find it. The system directory carries
  # tmux-256color for the panes; the invoking user's profile carries entries the
  # system one lacks -- xterm-kitty among them. That profile is a root-owned
  # store path, so pointing a privileged session at it is not a way in.
  term_dirs="/etc/profiles/per-user/$target_user/share/terminfo:/run/current-system/sw/share/terminfo"
  term=${TERM:-xterm-256color}
  term_found=0
  IFS=: read -r -a term_dir_list <<< "$term_dirs"
  for d in "${term_dir_list[@]}"; do
    if [ -e "$d/${term:0:1}/$term" ]; then
      term_found=1
      break
    fi
  done
  if [ "$term_found" -ne 1 ]; then
    printf 'k8s: no terminfo for %s here, falling back to xterm-256color\n' "$term" >&2
    term=xterm-256color
  fi

  # A function rather than a variable holding flags: the variable would have to
  # be left unquoted to split into arguments, and that is how a path with a
  # space becomes two arguments to a command running as another user.
  run_as_ops() {
    sudo -u "$OPS_USER" env -i \
      HOME="$sess" \
      TERM="$term" \
      TERMINFO_DIRS="$term_dirs" \
      LANG="${LANG:-C.UTF-8}" \
      LOCALE_ARCHIVE=/run/current-system/sw/lib/locale/locale-archive \
      PATH="$SHELL_PATH" \
      KUBECONFIG="$sess/config" \
      "$@"
  }

  if command -v tmux > /dev/null 2>&1; then
    # -S puts the socket inside the session directory, so it dies with it and no
    # detached server can outlive the token.
    run_as_ops tmux -f "$sess/tmux.conf" -S "$sess/tmux.sock" new-session -A -s k8s || true
  else
    run_as_ops bash --rcfile "$sess/.bashrc" -i || true
  fi

  printf 'k8s: session closed\n' >&2
  exit 0
fi

# ------------------------------------------------------------------- run ----
render_kubeconfig > "$work/config"
chmod 600 "$work/config"
unset token
export KUBECONFIG="$work/config"

printf 'k8s: %s as system:serviceaccount:%s:%s (expires %s)\n' \
  "$tool" "$SA_NS" "$SA" "$expires" >&2

# The resolved absolute path is executed, so nothing is looked up a second
# time. set -e propagates the tool's exact exit status, and the EXIT trap
# still runs because this is not an exec.
# The child still gets the narrow PATH: a tool that spawns helpers -- kubectl
# credential plugins, helm's post-renderer -- must not reach past the set.
# shellcheck disable=SC2031  # deliberately the same value as the lookup used.
export PATH=$RUN_PATH

"$tool_path" "$@"
