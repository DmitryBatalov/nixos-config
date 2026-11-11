# gcp -- hardware-gated gcloud with an administrator's rights.
#
#   sudo gcp <gcloud arguments>     one gcloud command as the admin account
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

set -euo pipefail

PATH="${GCP_TOOL_PATH:-/run/current-system/sw/bin:/usr/bin:/bin}"
RUN_PATH=${GCP_RUN_PATH:-$PATH}
IDENTITY=${GCP_AGE_IDENTITY:-/etc/k8s/identity.txt}
DIR=${GCP_DIR:-/etc/gcp}
RUN_USER=${GCP_RUN_USER:-gcp-run}
GRANT_JQ=${GCP_GRANT_JQ:-}
KEY=$DIR/admin.gsa.age
SETTINGS=$DIR/settings

die() {
  printf 'gcp: %s\n' "$1" >&2
  exit "${2:-1}"
}

usage() {
  cat >&2 << 'EOF'
usage: sudo gcp <gcloud arguments>
       sudo gcp grant ROLE [DURATION | forever]
       sudo gcp install <service account key.json>

Runs one gcloud command as the admin service account, after the token's PIN
and a touch. The project comes from /etc/gcp/settings unless --project says
otherwise.

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
runs -- container and compute admin, Artifact Registry writes -- are granted
for at most 1h, after you type the role name back. roles/viewer cannot
expire and needs `forever`.
EOF
  exit "${1:-2}"
}

[ $# -gt 0 ] || usage
case $1 in
  -h | --help | help) usage 0 ;;
esac
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
  if [ -s "$work/run/token" ]; then
    { printf 'token='; cat -- "$work/run/token"; } \
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
# and instanceAdmin reach a node and its service account; and writing to
# Artifact Registry is writing what production will run. Typing the name
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
printf 'gcp: unlocked. Running gcloud as the admin account on %s.\n' "$project" >&2

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
