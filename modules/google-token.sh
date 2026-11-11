# Shared by the k8s and gcp wrappers: concatenated into each script, not run.
#
# A Google service account's JSON key, read on stdin, traded for an hour-long
# access token, printed on stdout. The exchange is the OAuth JWT-bearer grant:
# sign a short assertion with the key, post it, get a token back. Done by hand
# rather than through gcloud, which would persist the account in a config
# directory and drag a Python runtime into a closure that runs as root.
#
# Every secret travels through pipes and process substitutions fed by the
# printf builtin, never through an external program's argv, where /proc would
# show it to the user. Needs die, jq, openssl, curl, base64, tr and date.
#
# Both scopes, as gke-gcloud-auth-plugin asks: GKE answers a userinfo.email-only
# token with 401, and without userinfo.email names the account by its numeric
# id, which no RBAC binding by email matches. The token can then reach any
# Google API, but only as far as the account's IAM roles go.
google_access_token() {
  local key email kid now header claims jwt resp access
  key=$(cat)
  # Empty when age failed -- a wrong PIN, a missed touch. Its own message has
  # already said why; a second one about the key would only mislead.
  [ -n "$key" ] || exit 1
  b64url() { base64 -w0 | tr '+/' '-_' | tr -d '='; }
  email=$(printf '%s' "$key" | jq -r '.client_email // empty')
  kid=$(printf '%s' "$key" | jq -r '.private_key_id // empty')
  case $email in
    *[!A-Za-z0-9.@-]* | "") die "the decrypted key is not a service account key" ;;
  esac
  # Backdated a little: Google rejects an assertion issued in its future, and
  # this clock may run ahead.
  now=$(($(date +%s) - 30))
  header=$(jq -nc --arg kid "$kid" '{alg: "RS256", typ: "JWT", kid: $kid}' | b64url)
  claims=$(jq -nc --arg iss "$email" --argjson iat "$now" '{
      iss: $iss,
      scope: "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/userinfo.email",
      aud: "https://oauth2.googleapis.com/token",
      iat: $iat,
      exp: ($iat + 330)}' | b64url)
  jwt=$header.$claims.$(printf '%s.%s' "$header" "$claims" \
    | openssl dgst -sha256 -binary \
      -sign <(printf '%s' "$key" | jq -r '.private_key') \
    | b64url)
  unset key
  resp=$(printf 'grant_type=urn%%3Aietf%%3Aparams%%3Aoauth%%3Agrant-type%%3Ajwt-bearer&assertion=%s' "$jwt" \
    | curl -q -sS --proto =https --fail-with-body --max-time 30 \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-binary @- https://oauth2.googleapis.com/token) \
    || die "Google refused the key: $(printf '%s' "$resp" | jq -r '.error_description // .error // empty' 2> /dev/null)"
  access=$(printf '%s' "$resp" | jq -r '.access_token // empty')
  case $access in
    *[!A-Za-z0-9._-]* | "") die "Google returned no usable access token" ;;
  esac
  printf '%s' "$access"
}
