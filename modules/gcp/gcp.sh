# gcp -- hardware-gated gcloud with an administrator's rights.
#
#   sudo gcp <gcloud arguments>     one gcloud command as the admin account
#   sudo gcp shell                  a session as the admin account, for an hour
#   sudo gcp grant ROLE [1h|forever] give your own account ROLE, for a while
#   sudo gcp install <key.json>     encrypt that account's key, once
#
# Your own Google account keeps only what everyday work needs -- reading logs
# -- so its gcloud token and browser session, which anything running as you
# can read, are not worth stealing. Changes go through a separate service
# account whose JSON key is age-encrypted to a FIDO2 credential on the hardware
# token. Each call decrypts it in memory, trades it for an hour-long access
# token, runs one gcloud command with that token, and throws everything away:
# the token sits in a root-only directory for exactly the command's lifetime.
#
# No intermediate minter, unlike k8s: Kubernetes records nothing of a stored
# token's use, which is why k8s mints, but Cloud Audit Logs record every call a
# service account makes under its own name.
#
# gcloud runs in your terminal as a system account of its own, in that
# directory, with HOME and CLOUDSDK_CONFIG there too: nothing it caches or
# writes survives, and nothing of yours is read. The commands that exist to
# print the token (auth, config) are refused.
#
# shell keeps that token for its whole hour and gives it a prompt: tmux and
# bash as the same system account, so neither the token nor the session it is
# typed into can be reached by anything running as you.

set -euo pipefail

PATH="${GCP_TOOL_PATH:-/run/current-system/sw/bin:/usr/bin:/bin}"
RUN_PATH=${GCP_RUN_PATH:-$PATH}
IDENTITY=${GCP_AGE_IDENTITY:-/etc/k8s/identity.txt}
DIR=${GCP_DIR:-/etc/gcp}
RUN_USER=${GCP_RUN_USER:-gcp-run}
GRANT_JQ=${GCP_GRANT_JQ:-}
SHELL_PATH=${GCP_SHELL_PATH:-$RUN_PATH}
SHELL_BASH=${GCP_SHELL_BASH:-bash}
LOGS_ACCOUNT=${GCP_LOGS_ACCOUNT:-logs-reader}
GCLOUD_COMPLETION=${GCP_GCLOUD_COMPLETION:-}
TERMINALS=${GCP_TERMINALS:-*kitty* *foot* *alacritty* *wezterm* *ghostty* xterm* st}
KEY=$DIR/admin.gsa.age
SETTINGS=$DIR/settings

die() {
  printf 'gcp: %s\n' "$1" >&2
  exit "${2:-1}"
}

usage() {
  cat >&2 << 'EOF'
usage: sudo gcp <gcloud arguments>
       sudo gcp shell
       sudo gcp grant ROLE [DURATION | forever]
       sudo gcp token logs [DURATION]
            gcp logs <gcloud logging arguments>
       sudo gcp install <service account key.json>

Runs one gcloud command as the admin service account, after the token's PIN
and a touch. The project comes from /etc/gcp/settings unless --project says
otherwise.

shell unlocks the key once and opens a session as the admin account until
its access token expires, an hour later; closing it revokes the token. It
refuses to start inside your own tmux, or in any terminal not named in
local.k8s.access.terminals: whoever holds a terminal types into it.

  sudo gcp projects get-iam-policy PROJECT
  sudo gcp projects add-iam-policy-binding PROJECT \
    --member user:you@example.com --role roles/container.admin \
    --condition='expression=request.time < timestamp("2030-01-01T12:00:00Z"),title=temporary'

grant gives ROLE to the account named by `user = ...` in /etc/gcp/settings,
for DURATION (30m, 1h -- the default --, 8h, 1d; at most 24h), after which
Google stops honouring it on its own. `forever` grants it without a limit.

  sudo gcp grant errorreporting.viewer
  sudo gcp grant cloudsql.admin 30m
  sudo gcp grant cloudsql.viewer forever

The limit bounds honest use, not a compromise: a thief holding your session
inside the window could make the access outlast it. So grant refuses owner,
editor and the IAM, key and impersonation roles; grant those, if ever, with
an explicit add-iam-policy-binding. Roles that reach the cluster or what it
runs -- container and compute admin, Artifact Registry writes, bucket and
secret reads -- are granted for at most 1h, after you type the role name
back. roles/viewer cannot expire and needs `forever`.

token logs has the admin account issue an access token for the log reader
account -- roles/logging.viewer and nothing else, no keys -- scoped to
reading logs, for DURATION (15m, 30m, 1h -- the default and Google's cap),
and leaves it where you, and an agent working as you, can read it:
/run/user/UID/gcp/logs-token. gcp logs, without sudo, runs gcloud logging
with it, against the project from the settings.

  sudo gcp token logs
  gcp logs read 'resource.type="k8s_container" AND severity>=ERROR' \
    --freshness=1h --limit=50
EOF
  exit "${1:-2}"
}

[ $# -gt 0 ] || usage
case $1 in
  -h | --help | help) usage 0 ;;
esac

# ------------------------------------------------------------------ logs ---
# As you, not root: the token is yours to read anyway, and what it can do is
# bounded by Google -- one account, one role, a logging.read scope, an hour.
# Only `gcloud logging` is offered, for clarity rather than as a boundary. The
# config directory is a cache of its own, so no ~/.config/gcloud comes back.
if [ "$1" = logs ]; then
  shift
  [ "$(id -u)" -ne 0 ] || die "run it without sudo: gcp logs ..." 2
  tokens=/run/user/$(id -u)/gcp
  [ -s "$tokens/logs-token" ] || die "no logs token; run: sudo gcp token logs" 2
  expires_at=$(cat -- "$tokens/logs-token.expires" 2> /dev/null) || expires_at=0
  case $expires_at in '' | *[!0-9]*) expires_at=0 ;; esac
  [ "$(date +%s)" -lt "$expires_at" ] || die "the logs token has expired; run: sudo gcp token logs" 2
  logs_project=$(cat -- "$tokens/project" 2> /dev/null) || logs_project=
  case $logs_project in
    [a-z]*[a-z0-9]) ;;
    *) die "no project beside the logs token; run: sudo gcp token logs" 2 ;;
  esac
  case $logs_project in
    *[!a-z0-9-]*) die "no project beside the logs token; run: sudo gcp token logs" 2 ;;
  esac
  exec env -i \
    HOME="$HOME" \
    PATH="$RUN_PATH" \
    TERM="${TERM:-dumb}" \
    LANG="${LANG:-C.UTF-8}" \
    CLOUDSDK_CONFIG="${XDG_CACHE_HOME:-$HOME/.cache}/gcp-logs" \
    CLOUDSDK_AUTH_ACCESS_TOKEN_FILE="$tokens/logs-token" \
    CLOUDSDK_CORE_PROJECT="$logs_project" \
    CLOUDSDK_CORE_CHECK_GCE_METADATA=false \
    CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=1 \
    gcloud logging "$@"
fi

[ "$(id -u)" -eq 0 ] || die "run it as: sudo gcp $*" 2
target_user=${SUDO_USER:-}
[ -n "$target_user" ] && [ "$target_user" != root ] \
  || die "run it through sudo from your own account" 2

recipient_of() {
  grep 'public key' "$1" | grep -oP 'age1.*' | head -1
}

# The project is deployment state -- it names a customer -- and user, the
# everyday account grant gives roles to, names a person; both live beside
# the key, root-owned, rather than in this public repository. Parsed, not
# sourced, and checked: both reach gcloud's arguments or environment.
load_settings() {
  local line key val
  project='' user=''
  [ -r "$SETTINGS" ] || die "cannot read $SETTINGS; run sudo gcp install first"
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in
      '#'* | '') continue ;;
      *=*) ;;
      *) die "$SETTINGS: not a key = value line: $line" ;;
    esac
    key=${line%%=*}
    val=${line#*=}
    key=${key//[[:space:]]/}
    val=${val//[[:space:]]/}
    case $key in
      project) project=$val ;;
      user) user=$val ;;
      *) die "$SETTINGS: unknown key '$key'" ;;
    esac
  done < "$SETTINGS"
  case $project in
    [a-z]*[a-z0-9]) ;;
    *) die "$SETTINGS: not a project id: $project" ;;
  esac
  case $project in
    *[!a-z0-9-]*) die "$SETTINGS: not a project id: $project" ;;
  esac
  case $user in
    "") ;;
    *[!A-Za-z0-9.@_+-]* | *@*@* | @* | *@) die "$SETTINGS: not an account: $user" ;;
    ?*@?*.?*) ;;
    *) die "$SETTINGS: not an account: $user" ;;
  esac
}

# /run is tmpfs and cleared at boot, so a directory a SIGKILL leaves behind
# dies with the next reboot rather than lingering on disk.
umask 077
work=$(mktemp -d /run/gcp.XXXXXXXX)
# 0711: RUN_USER must pass through to its own run/, which is 0700 and its
# alone; everything else in here is root's, 0600 under the umask.
chmod 711 "$work"
export HOME="$work"
# Revoked, not merely deleted: a token that got out -- printed, logged -- would
# otherwise stay good for the rest of its hour. Best effort; the hour still
# bounds it if Google is unreachable.
# shellcheck disable=SC2329 # invoked by the EXIT trap
cleanup() {
  # The tmux server first: it outlives its client on a detach or a signal, and
  # would otherwise stay behind as RUN_USER, holding the session open.
  if [ -S "$work/run/tmux.sock" ]; then
    setpriv --reuid="$RUN_USER" --regid="$RUN_USER" --init-groups \
      env -i PATH="$SHELL_PATH" tmux -S "$work/run/tmux.sock" kill-server \
      > /dev/null 2>&1 || true
  fi
  if [ -s "$work/run/token" ]; then
    # Read as RUN_USER, whose directory it is: a shell could have swapped the
    # file for a symlink, and root's cat would send its target to Google.
    { printf 'token='; setpriv --reuid="$RUN_USER" --regid="$RUN_USER" --init-groups \
      cat -- "$work/run/token"; } \
      | curl -q -s --proto =https --max-time 10 --data-binary @- \
        https://oauth2.googleapis.com/revoke > /dev/null 2>&1 || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 131' QUIT
trap 'exit 143' TERM

[ -r "$IDENTITY" ] || die "cannot read $IDENTITY"

# ---------------------------------------------------------------- install ---
if [ "$1" = install ]; then
  [ $# -eq 2 ] || usage
  src=$2
  # Read as the user: the path is theirs, and root following a symlink there
  # would encrypt whatever it pointed at.
  sudo -u "$target_user" test -f "$src" || die "not a readable file: $src"
  # shellcheck disable=SC2024 # read as the user, written by root into $work, on purpose
  sudo -u "$target_user" cat -- "$src" > "$work/key.json"
  jq -e '.type == "service_account"' "$work/key.json" > /dev/null 2>&1 \
    || die "$src is not a service account key"
  email=$(jq -r .client_email "$work/key.json")
  key_project=$(jq -r '.project_id // empty' "$work/key.json")
  case $key_project in
    [a-z]*[a-z0-9]) ;;
    *) die "the key names no plausible project: '$key_project'" ;;
  esac
  case $key_project in
    *[!a-z0-9-]*) die "the key names no plausible project: '$key_project'" ;;
  esac
  printf 'gcp: checking the key with Google...\n' >&2
  google_access_token < "$work/key.json" > /dev/null
  printf '     %s works\n' "$email" >&2

  recipient=$(recipient_of "$IDENTITY")
  case $recipient in
    age1*) ;;
    *) die "no recipient in $IDENTITY" ;;
  esac
  age -r "$recipient" -o "$work/admin.gsa.age" "$work/key.json"
  printf 'gcp: verifying the round trip -- the token wants its PIN and a touch\n' >&2
  age -d -i "$IDENTITY" "$work/admin.gsa.age" | cmp -s - "$work/key.json" \
    || die "the round trip failed; nothing was installed"

  install -d -m 0700 -o root -g root "$DIR"
  printf '# read by the gcp wrapper\nproject = %s\n' "$key_project" > "$work/settings"
  # A re-install keeps the account grant gives roles to -- parsed and checked
  # like any other read of the file, not copied as written.
  old_user=$( (load_settings > /dev/null 2>&1 && printf '%s' "$user") || true)
  if [ -n "$old_user" ]; then printf 'user = %s\n' "$old_user" >> "$work/settings"; fi
  # The key first: a crash between the two then leaves a new key with the old
  # project at worst, never a project with no key.
  install -m 0400 -o root -g root "$work/admin.gsa.age" "$KEY"
  install -m 0400 -o root -g root "$work/settings" "$SETTINGS"
  sudo -u "$target_user" shred -u -- "$src" 2> /dev/null \
    || sudo -u "$target_user" rm -f -- "$src"
  printf 'gcp: installed %s for %s; destroyed %s\n' "$KEY" "$key_project" "$src" >&2
  exit 0
fi

# -------------------------------------------------------------------- run ---
# Commands whose whole point is to hand out the token or the config holding it.
# Printed to your terminal, an owner token is readable from its scrollback by
# anything running as you, for the rest of its hour. Matched anywhere in the
# arguments, since global flags may come first; a resource that happens to be
# named like one of these is refused too, and has to be addressed otherwise.
for arg in "$@"; do
  case $arg in
    auth | config | config-helper | print-access-token | print-identity-token)
      die "refusing '$arg': it would print or keep the admin credential" 2
      ;;
  esac
done

load_settings

# token: an hour at most, which is what Google allows without an org policy
# -- and this project has no organisation to set one in.
if [ "$1" = token ]; then
  [ $# -ge 2 ] && [ $# -le 3 ] || usage
  [ "$2" = logs ] || die "no such token: $2 (there is: logs)" 2
  case $LOGS_ACCOUNT in
    [a-z]*[a-z0-9]) ;;
    *) die "not an account id: $LOGS_ACCOUNT" ;;
  esac
  case $LOGS_ACCOUNT in
    *[!a-z0-9-]*) die "not an account id: $LOGS_ACCOUNT" ;;
  esac
  duration=${3:-1h}
  n=${duration%?}
  case $duration in
    [1-9]*m | [1-9]*h) ;;
    *) die "not a duration: $duration (15m, 30m, 1h)" 2 ;;
  esac
  case $n in *[!0-9]*) die "not a duration: $duration (15m, 30m, 1h)" 2 ;; esac
  [ ${#n} -le 4 ] || die "at most 1h" 2
  case $duration in
    *m) secs=$((n * 60)) ;;
    *h) secs=$((n * 3600)) ;;
  esac
  [ "$secs" -le 3600 ] || die "at most 1h: Google issues no longer token here" 2
  tokens=/run/user/$(id -u "$target_user")
  [ -d "$tokens" ] || die "no $tokens; log in as $target_user first" 2
  tokens=$tokens/gcp
fi

# Checked before the PIN is spent, like grant's arguments.
if [ "$1" = shell ]; then
  [ $# -eq 1 ] || usage
  [ -t 0 ] || die "shell needs a terminal" 2
  holder=$(terminal_holder)
  if [ -n "$holder" ]; then
    printf 'gcp: this terminal is held by "%s", running as you. Whoever holds a\n' "$holder" >&2
    printf '     terminal types into it, so an admin session opened here would be\n' >&2
    printf '     drivable by anything with your uid. Start it from a terminal\n' >&2
    printf '     emulator, one named in local.k8s.access.terminals.\n' >&2
    exit 2
  fi
fi

# grant: a role for the everyday account, for a while, checked before the PIN
# is spent. The limit is an IAM condition, so Google stops honouring the role
# by itself -- nothing here has to be around to take it back.
#
# The limit bounds honest use, not a compromise: the account receiving the
# role is the one whose token and browser session can be stolen, and a thief
# holding it inside the window can make the access outlast it. So grant
# refuses the roles that do that to the whole project -- IAM administration,
# keys and impersonation of service accounts, owner and editor. Granting one
# of those is still possible, as an explicit add-iam-policy-binding.
#
# The roles that reach around the hardware-gated paths to the cluster are
# allowed, but only briefly and only after the role is typed back: write
# access to GKE is what `sudo k8s --breakglass` exists to gate, and a
# browser's Cloud Shell would use it as the everyday account; compute.admin
# and instanceAdmin reach a node and its service account; writing to
# Artifact Registry is writing what production will run; and reading buckets
# or Secret Manager reads Terraform state and secrets, credentials included. Typing the name
# guards against a command accepted without reading it, not against theft:
# that is what the one-hour ceiling is for.
grant_until=
if [ "$1" = grant ]; then
  [ $# -ge 2 ] && [ $# -le 3 ] || usage
  [ -n "$user" ] || die "no account to grant to; add 'user = you@example.com' to $SETTINGS" 2
  role=${2#roles/}
  case $role in
    *[!A-Za-z0-9._]* | "") die "not a predefined role: $2" 2 ;;
  esac
  case $role in
    owner | editor | resourcemanager.* | *.securityAdmin | iam.*Admin \
      | iam.serviceAccountTokenCreator | iam.serviceAccountOpenIdTokenCreator \
      | iam.serviceAccountUser | iam.workloadIdentityUser)
      die "roles/$role would let the account keep access past any limit; grant it with add-iam-policy-binding if you must" 2
      ;;
  esac
  risky=
  case $role in
    container.admin | container.clusterAdmin | container.developer)
      risky="gives write access to the cluster around sudo k8s --breakglass" ;;
    compute.admin | compute.instanceAdmin*)
      risky="reaches the cluster's nodes and the service account they run as" ;;
    artifactregistry.writer | artifactregistry.repoAdmin | artifactregistry.admin)
      risky="can replace the images production runs" ;;
    storage.objectViewer | storage.objectAdmin | storage.admin)
      risky="reads every bucket, Terraform state and its secrets among them" ;;
    secretmanager.secretAccessor | secretmanager.admin)
      risky="reads the secret values production runs with" ;;
  esac
  duration=${3:-1h}
  case $role:$duration in
    viewer:forever) ;;
    viewer:*) die "roles/viewer is a basic role and cannot expire; say 'forever' if you mean it" 2 ;;
  esac
  case $duration in
    forever)
      [ -z "$risky" ] || die "roles/$role $risky; it is granted for at most 1h, never forever" 2
      printf 'gcp: granting roles/%s to %s with no time limit\n' "$role" "$user" >&2
      set -- projects add-iam-policy-binding "$project" \
        --member "user:$user" --role "roles/$role" --condition=None --format=none
      ;;
    [1-9]*[mhd] | [1-9][mhd])
      n=${duration%?}
      case $n in *[!0-9]*) die "not a duration: $duration (30m, 1h, 8h, 1d, forever)" 2 ;; esac
      # Bounded before the arithmetic: a long enough number wraps negative and
      # would pass the 24h check as a grant that expired yesterday.
      [ ${#n} -le 5 ] || die "at most 24h; for longer, say 'forever' and remove it yourself" 2
      case $duration in
        *m) secs=$((n * 60)) ;;
        *h) secs=$((n * 3600)) ;;
        *d) secs=$((n * 86400)) ;;
      esac
      [ "$secs" -le 86400 ] || die "at most 24h; for longer, say 'forever' and remove it yourself" 2
      [ -z "$risky" ] || [ "$secs" -le 3600 ] || die "roles/$role is granted for at most 1h" 2
      grant_until=$(date -u -d "@$(($(date +%s) + secs))" +%Y-%m-%dT%H:%M:%SZ)
      ;;
    *) die "not a duration: $duration (30m, 1h, 8h, 1d, forever)" 2 ;;
  esac
  if [ -n "$risky" ]; then
    # From the terminal itself, not stdin: the answer must be typed, here.
    : < /dev/tty 2> /dev/null || die "roles/$role needs a typed confirmation, and there is no terminal" 2
    printf 'gcp: roles/%s %s,\n     until %s, to %s,\n     whose browser session can be stolen. Type the role name to confirm: ' \
      "$role" "$risky" "$grant_until" "$user" > /dev/tty
    read -r answer < /dev/tty || answer=
    [ "${answer#roles/}" = "$role" ] || die "not confirmed; nothing granted" 2
  fi
  if [ -n "$grant_until" ]; then
    printf 'gcp: granting roles/%s to %s until %s\n' "$role" "$user" "$grant_until" >&2
  fi
fi

# A timed grant is one read-modify-write of the policy rather than
# add-iam-policy-binding: IAM caps the bindings one role and member may have,
# so expired grants would pile up until grant stopped working. Every expired
# binding grant itself made -- its title says so -- is dropped in the same
# write, and the etag from the read makes a concurrent change fail rather than
# be overwritten. Every argument is the wrapper's; none is the caller's.
# shellcheck disable=SC2016 # expanded by the inner bash, not here
grant_script='
gcloud projects get-iam-policy "$1" --format=json > policy.json
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg member "user:$2" \
  --arg role "roles/$3" --arg until "$4" -f "$5" policy.json > new.json
gcloud projects set-iam-policy "$1" new.json --format=none
'

[ -r "$KEY" ] || die "cannot read $KEY; run sudo gcp install first"
id -u "$RUN_USER" > /dev/null 2>&1 || die "no such account: $RUN_USER"

# gcloud runs as RUN_USER, in a directory of its own, not as root in yours.
# Nothing gcloud does needs root -- only the token is privileged -- and every
# path it is given would otherwise be opened by root: `keys create k.json`
# through a symlink you planted, `--flags-file`, a `builds submit .` uploading
# whatever a link in the current directory points at. Relative paths land in
# this directory and go with it; to keep a file gcloud writes, ask for it on
# stdout.
install -d -m 0700 -o "$RUN_USER" -g "$RUN_USER" "$work/run"

printf 'gcp: sudo accepted the touch. Unlocking the admin key takes the PIN and\n' >&2
printf '     a touch once more. The plugin overwrites its own prompt line, so\n' >&2
printf '     this PIN request can look like a blank line. Type it anyway.\n' >&2
# Written straight to a file: gcloud reads its token from one, and a shell
# variable would only add a copy. Readable by RUN_USER alone.
age -d -i "$IDENTITY" "$KEY" | google_access_token > "$work/run/token" \
  || exit 1
[ -s "$work/run/token" ] || die "no access token"
chown "$RUN_USER:$RUN_USER" "$work/run/token"
chmod 0400 "$work/run/token"
if [ "$1" = token ]; then
  printf 'gcp: unlocked. Asking for the token as the admin account on %s.\n' "$project" >&2
else
  printf 'gcp: unlocked. Running gcloud as the admin account on %s.\n' "$project" >&2
fi

# ----------------------------------------------------------------- token ---
# The admin account asks IAM Credentials for a token of the log reader's,
# which it may do for that account alone. curl rather than gcloud auth: auth
# is refused here, and this needs one request. The admin token goes in a
# header file, not on curl's command line, where ps would show it.
if [ "$1" = token ]; then
  email="$LOGS_ACCOUNT@$project.iam.gserviceaccount.com"
  { printf 'Authorization: Bearer '; cat -- "$work/run/token"; } > "$work/auth-header"
  # shellcheck disable=SC2016 # jq's own variables
  resp=$(jq -n --arg lifetime "${secs}s" \
    '{scope: ["https://www.googleapis.com/auth/logging.read"], lifetime: $lifetime}' \
    | curl -q -sS --proto =https --fail-with-body \
      -H @"$work/auth-header" -H 'Content-Type: application/json' --data-binary @- \
      "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/$email:generateAccessToken") \
    || die "Google refused a token for $email: $(jq -r '.error.message? // .' <<< "${resp:-}" 2> /dev/null)"
  logs_token=$(jq -r '.accessToken // empty' <<< "$resp")
  case $logs_token in
    '' | *[!A-Za-z0-9._-]*) die "no usable token in Google's answer" ;;
  esac
  expires_at=$(date -d "$(jq -r '.expireTime' <<< "$resp")" +%s) \
    || die "no expiry in Google's answer"

  # Written as you: the directory is yours, and root following a link you
  # planted there would write wherever it pointed. The umask makes it 0600.
  as_user() {
    setpriv --reuid="$target_user" --regid="$(id -g "$target_user")" --init-groups "$@"
  }
  as_user mkdir -p -- "$tokens"
  printf '%s' "$logs_token" | as_user tee -- "$tokens/.logs-token.new" > /dev/null
  as_user mv -f -- "$tokens/.logs-token.new" "$tokens/logs-token"
  printf '%s\n' "$expires_at" | as_user tee -- "$tokens/logs-token.expires" > /dev/null
  printf '%s\n' "$project" | as_user tee -- "$tokens/project" > /dev/null
  unset logs_token resp

  printf 'gcp: a logs token for %s until %s, in\n' "$email" "$(date -d "@$expires_at" +%H:%M)" >&2
  printf '     %s/logs-token. Read logs with\n\n' "$tokens" >&2
  printf "       gcp logs read 'severity>=ERROR' --freshness=1h --limit=50\n\n" >&2
  printf '     or any gcloud with --access-token-file=%s/logs-token.\n' "$tokens" >&2
  exit 0
fi

# ----------------------------------------------------------------- shell ---
if [ "$1" = shell ]; then
  # Issued a moment ago for an hour; a minute is left as margin.
  expires=$(date -d '+59 min' +%H:%M)

  # A bare tmux and a bare bash, as for k8s shell: an rc file of yours is
  # executable code, and sharing it would let anything running as you run
  # commands here. The colours are k8s shell's break-glass ones: this account
  # is owner.
  {
    printf 'set -g default-terminal "tmux-256color"\n'
    printf 'set -g history-limit 20000\n'
    printf 'set -g mouse on\n'
    printf 'set -g status-left-length 60\n'
    printf 'set -g status-right-length 60\n'
    printf 'set -g window-style "bg=#2b0b0b,fg=#ffd7af"\n'
    printf 'set -g window-active-style "bg=#2b0b0b,fg=#ffd7af"\n'
    printf 'set -g pane-border-style fg=#7f1d1d\n'
    printf 'set -g pane-active-border-style fg=#ff3b3b\n'
    printf 'set -g status-style bg=colour52,fg=colour223\n'
    printf 'set -g status-left " GCP ADMIN  %s "\n' "$project"
    printf 'set -g status-right " expires %s "\n' "$expires"
    # runUser's login shell is nologin, which tmux would otherwise run.
    printf 'set -g default-shell %s\n' "$SHELL_BASH"
    printf 'set -g default-command "%s --rcfile %s/.bashrc -i"\n' "$SHELL_BASH" "$work/run"
  } > "$work/run/tmux.conf"

  {
    # /etc/bashrc, read first, sources /etc/profile, which replaces PATH.
    printf 'export PATH=%s\n' "$SHELL_PATH"
    printf 'PS1="[admin@%s] \\w \\$ "\n' "$project"
    if [ -n "$GCLOUD_COMPLETION" ]; then printf '. %s\n' "$GCLOUD_COMPLETION"; fi
    # Not a boundary -- the token file is readable here, or gcloud could not
    # use it -- but a printed token lands in scrollback, and this keeps it from
    # getting there by habit.
    cat << 'EOF'
gcloud() {
  local a
  for a in "$@"; do
    case $a in
      auth | config | config-helper | print-access-token | print-identity-token)
        printf 'gcp: refusing %s: it would print or keep the admin credential\n' "$a" >&2
        return 2
        ;;
    esac
  done
  command gcloud "$@"
}
EOF
  } > "$work/run/.bashrc"

  # The token's public recipient, so what gcloud hands out -- a new key -- can
  # be encrypted before it is ever kept in the clear: age -R ~/recipient.txt.
  # Encrypting needs no touch; decrypting needs the token, which this session
  # cannot open.
  recipient=$(recipient_of "$IDENTITY")
  case $recipient in
    age1*) printf '%s\n' "$recipient" > "$work/run/recipient.txt" ;;
    *) die "no recipient in $IDENTITY" ;;
  esac
  chown "$RUN_USER:$RUN_USER" "$work/run/tmux.conf" "$work/run/.bashrc" \
    "$work/run/recipient.txt"

  # As for k8s shell: env -i drops the terminfo search path, and kitty's entry
  # lives in your profile, a root-owned store path.
  term_dirs="/etc/profiles/per-user/$target_user/share/terminfo:/run/current-system/sw/share/terminfo"
  term=${TERM:-xterm-256color}
  [ -e "/etc/profiles/per-user/$target_user/share/terminfo/${term:0:1}/$term" ] \
    || [ -e "/run/current-system/sw/share/terminfo/${term:0:1}/$term" ] \
    || term=xterm-256color

  printf 'gcp: session as the admin account on %s until %s, running as %s.\n' \
    "$project" "$expires" "$RUN_USER" >&2
  printf '     Closing it revokes the token. Encrypt to the token with\n' >&2
  printf '     age -R ~/recipient.txt.\n' >&2
  # Not exec, so the trap kills the server and revokes the token.
  (
    cd "$work/run"
    exec setpriv --reuid="$RUN_USER" --regid="$RUN_USER" --init-groups \
      env -i \
      HOME="$work/run" \
      PATH="$SHELL_PATH" \
      TERM="$term" \
      TERMINFO_DIRS="$term_dirs" \
      LANG="${LANG:-C.UTF-8}" \
      LOCALE_ARCHIVE=/run/current-system/sw/lib/locale/locale-archive \
      CLOUDSDK_CONFIG="$work/run/gcloud" \
      CLOUDSDK_AUTH_ACCESS_TOKEN_FILE="$work/run/token" \
      CLOUDSDK_CORE_PROJECT="$project" \
      CLOUDSDK_CORE_LOG_HTTP_REDACT_TOKEN=true \
      CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=1 \
      tmux -f "$work/run/tmux.conf" -S "$work/run/tmux.sock" new-session -s gcp
  ) || true
  printf 'gcp: session closed\n' >&2
  exit 0
fi

if [ -n "$grant_until" ]; then
  [ -r "$GRANT_JQ" ] || die "no grant filter at $GRANT_JQ"
  set -- bash -euo pipefail -c "$grant_script" grant \
    "$project" "$user" "$role" "$grant_until" "$GRANT_JQ"
else
  set -- gcloud "$@"
fi

# A bare environment: gcloud sees the token, a fresh config directory and the
# project, and nothing of the caller's. Not exec, so the trap revokes the token.
status=0
(
  cd "$work/run"
  exec setpriv --reuid="$RUN_USER" --regid="$RUN_USER" --init-groups \
    env -i \
    HOME="$work/run" \
    PATH="$RUN_PATH" \
    TERM="${TERM:-dumb}" \
    LANG="${LANG:-C.UTF-8}" \
    CLOUDSDK_CONFIG="$work/run/gcloud" \
    CLOUDSDK_AUTH_ACCESS_TOKEN_FILE="$work/run/token" \
    CLOUDSDK_CORE_PROJECT="$project" \
    CLOUDSDK_CORE_LOG_HTTP_REDACT_TOKEN=true \
    "$@"
) || status=$?
exit "$status"
