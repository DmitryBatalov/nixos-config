# Tab completion for `gcp` and `sudo gcp`, sourced by bash-completion.
#
# Everything past the wrapper's own words is gcloud's: its completer runs as
# you, with no credentials, from the static command tree that ships with the
# SDK -- the admin key is never touched to complete a word. @gcloud@ is the
# store path, substituted at build time, since gcloud is no longer on PATH.
#
# gcloud's completion file is not sourced whole: it defines the global
# _python_argcomplete, which python-argcomplete's own hook also defines, and
# whichever loaded last would break the other. Only that function is taken,
# under a name of its own.
eval "$(sed -n '/^_python_argcomplete() {/,/^}/p' \
  "@gcloud@/share/bash-completion/completions/gcloud" \
  | sed '1s/^_python_argcomplete()/_gcp_gcloud_complete()/')"

_gcp_roles='
  errorreporting.viewer cloudtrace.user logging.viewer logging.privateLogViewer
  monitoring.viewer compute.viewer compute.admin container.viewer
  container.clusterViewer container.developer container.admin cloudsql.viewer
  cloudsql.client cloudsql.admin artifactregistry.reader artifactregistry.writer
  storage.objectViewer storage.objectAdmin storage.admin secretmanager.viewer
  secretmanager.secretAccessor
  iam.serviceAccountViewer iam.securityReviewer browser viewer'

_gcp() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  case ${COMP_WORDS[1]:-} in
    grant)
      case $COMP_CWORD in
        2) mapfile -t COMPREPLY < <(compgen -W "$_gcp_roles" -- "$cur") ;;
        3) mapfile -t COMPREPLY < <(compgen -W '30m 1h 2h 4h 8h 1d forever' -- "$cur") ;;
      esac
      # -o nospace is for gcloud's sake; whole words here want their space.
      COMPREPLY=("${COMPREPLY[@]/%/ }")
      return
      ;;
    token)
      case $COMP_CWORD in
        2) mapfile -t COMPREPLY < <(compgen -W 'logs' -- "$cur") ;;
        3) mapfile -t COMPREPLY < <(compgen -W '15m 30m 1h' -- "$cur") ;;
      esac
      COMPREPLY=("${COMPREPLY[@]/%/ }")
      return
      ;;
    logs)
      # `gcp logs X` is `gcloud logging X`: completed as that line.
      local COMP_LINE=${COMP_LINE/logs/logging} COMP_POINT=$((COMP_POINT + 3))
      ;;
    install)
      if [ "$COMP_CWORD" -eq 2 ]; then
        compopt -o filenames +o nospace 2> /dev/null
        mapfile -t COMPREPLY < <(compgen -f -- "$cur")
      fi
      return
      ;;
  esac

  # gcloud writes a config directory on every start. Pointed at a cache of its
  # own, so completing a word does not recreate the ~/.config/gcloud this
  # machine got rid of; and kept off the metadata server, which a resource
  # completer would otherwise probe -- slowly -- on every Tab.
  local -x CLOUDSDK_CONFIG=${XDG_CACHE_HOME:-$HOME/.cache}/gcp-completion
  local -x CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=1
  local -x CLOUDSDK_CORE_CHECK_GCE_METADATA=false
  # Scoped here: gcloud's function assigns these without declaring them.
  # shellcheck disable=SC2034
  local lastw flag line match
  _gcp_gcloud_complete "@gcloud@/bin/gcloud" "$cur" "${COMP_WORDS[COMP_CWORD - 1]}"

  # The wrapper refuses these; offering them would only cost a touch.
  local i
  for i in "${!COMPREPLY[@]}"; do
    case ${COMPREPLY[i]} in
      'auth ' | 'config ') unset 'COMPREPLY[i]' ;;
    esac
  done
  if [ "$COMP_CWORD" -eq 1 ]; then
    local w
    for w in grant install shell token logs; do
      [[ $w == "$cur"* ]] && COMPREPLY+=("$w ")
    done
  fi
}
complete -o nospace -F _gcp gcp
