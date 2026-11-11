# gcp -- hardware-gated gcloud with an administrator's rights.
#
#   sudo gcp <gcloud arguments>     one gcloud command as the admin account
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
# gcloud runs as root, in your terminal, with HOME and CLOUDSDK_CONFIG in that
# directory: nothing it caches survives, and nothing of yours is read. Keep to
# commands that finish; a long interactive one is a root process anything
# running as you could try to drive.

set -euo pipefail

PATH="${GCP_TOOL_PATH:-/run/current-system/sw/bin:/usr/bin:/bin}"
RUN_PATH=${GCP_RUN_PATH:-$PATH}
IDENTITY=${GCP_AGE_IDENTITY:-/etc/k8s/identity.txt}
DIR=${GCP_DIR:-/etc/gcp}
KEY=$DIR/admin.gsa.age
SETTINGS=$DIR/settings

die() {
  printf 'gcp: %s\n' "$1" >&2
  exit "${2:-1}"
}

usage() {
  cat >&2 << 'EOF'
usage: sudo gcp <gcloud arguments>
       sudo gcp install <service account key.json>

Runs one gcloud command as the admin service account, after the token's PIN
and a touch. The project comes from /etc/gcp/settings unless --project says
otherwise.

  sudo gcp projects get-iam-policy PROJECT
  sudo gcp projects add-iam-policy-binding PROJECT \
    --member user:you@example.com --role roles/container.admin \
    --condition='expression=request.time < timestamp("2030-01-01T12:00:00Z"),title=temporary'

Basic roles (owner, editor, viewer) cannot carry a condition: granted, they
stay until removed.
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

# The project is deployment state -- it names a customer -- so it lives beside
# the key, root-owned, rather than in this public repository. Parsed, not
# sourced, and checked: it reaches gcloud's environment.
load_settings() {
  local line key val
  project=''
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
}

# /run is tmpfs and cleared at boot, so a directory a SIGKILL leaves behind
# dies with the next reboot rather than lingering on disk.
umask 077
work=$(mktemp -d /run/gcp.XXXXXXXX)
chmod 700 "$work"
export HOME="$work"
trap 'rm -rf "$work"' EXIT
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
  sudo -u "$target_user" cat "$src" > "$work/key.json"
  jq -e '.type == "service_account"' "$work/key.json" > /dev/null 2>&1 \
    || die "$src is not a service account key"
  email=$(jq -r .client_email "$work/key.json")
  key_project=$(jq -r .project_id "$work/key.json")
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
  install -m 0400 -o root -g root "$work/settings" "$SETTINGS"
  install -m 0400 -o root -g root "$work/admin.gsa.age" "$KEY"
  sudo -u "$target_user" shred -u "$src" 2> /dev/null \
    || sudo -u "$target_user" rm -f "$src"
  printf 'gcp: installed %s for %s; destroyed %s\n' "$KEY" "$key_project" "$src" >&2
  exit 0
fi

# -------------------------------------------------------------------- run ---
load_settings
[ -r "$KEY" ] || die "cannot read $KEY; run sudo gcp install first"

printf 'gcp: sudo accepted the touch. Unlocking the admin key takes the PIN and\n' >&2
printf '     a touch once more. The plugin overwrites its own prompt line, so\n' >&2
printf '     this PIN request can look like a blank line. Type it anyway.\n' >&2
# Written straight to a root-only file: gcloud reads its token from a file,
# and a shell variable would only add a copy.
age -d -i "$IDENTITY" "$KEY" | google_access_token > "$work/token" \
  || exit 1
[ -s "$work/token" ] || die "no access token"
printf 'gcp: unlocked. Running gcloud as the admin account on %s.\n' "$project" >&2

# A bare environment: gcloud sees the token, a fresh config directory and the
# project, and nothing of the caller's. Not exec, so the trap removes the token.
status=0
env -i \
  HOME="$work" \
  PATH="$RUN_PATH" \
  TERM="${TERM:-dumb}" \
  LANG="${LANG:-C.UTF-8}" \
  CLOUDSDK_CONFIG="$work/gcloud" \
  CLOUDSDK_AUTH_ACCESS_TOKEN_FILE="$work/token" \
  CLOUDSDK_CORE_PROJECT="$project" \
  gcloud "$@" || status=$?
exit "$status"
