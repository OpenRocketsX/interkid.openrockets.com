#!/usr/bin/env bash
set -euo pipefail

ACCOUNT="${ALWAYSDATA_ACCOUNT:-interkidtest}"
TOKEN_APP="iutuy"
API_ROOT="https://api.alwaysdata.com/v1"

TOKEN="${DEPLOY_COMMENT#alwaysdata-deploy:}"
TOKEN="$(printf '%s' "$TOKEN" | tr -d '[:space:]')"
if [ -z "$TOKEN" ] || [ "$TOKEN" = "$DEPLOY_COMMENT" ]; then
  echo 'No deployment token found.' >&2
  exit 1
fi

echo "::add-mask::$TOKEN"
AUTH="${TOKEN} account=${ACCOUNT}:"
SSH_USER="${ACCOUNT}_deploy"
SSH_PASS="$(openssl rand -hex 24)"
echo "::add-mask::$SSH_PASS"
TEMP_SSH_ID=""

api() {
  local method="$1" url="$2"
  shift 2
  curl --fail --silent --show-error --basic --user "$AUTH" \
    -H 'alwaysdata-synchronous: yes' \
    -X "$method" "$url" "$@"
}

cleanup() {
  set +e
  if [ -n "$TEMP_SSH_ID" ]; then
    api DELETE "$API_ROOT/ssh/$TEMP_SSH_ID/" >/dev/null 2>&1 || true
  fi
  rm -f /tmp/interkid-alwaysdata.tgz /tmp/sites.json /tmp/site.json /tmp/search.html /tmp/home.html
}
trap cleanup EXIT

sudo apt-get update -qq
sudo apt-get install -y -qq sshpass jq >/dev/null

api GET "$API_ROOT/site/" > /tmp/sites.json
echo 'alwaysdata API access verified.'

# Replace any stale temporary deploy user.
api GET "$API_ROOT/ssh/" > /tmp/ssh-users.json
OLD_ID="$(jq -r --arg n "$SSH_USER" '.[] | select(.name==$n) | .id' /tmp/ssh-users.json | head -n1)"
if [ -n "$OLD_ID" ]; then
  api DELETE "$API_ROOT/ssh/$OLD_ID/" >/dev/null
fi

jq -n \
  --arg name "$SSH_USER" \
  --arg password "$SSH_PASS" \
  '{name:$name,password:$password,home_directory:"/",shell:"BASH",can_use_password:true,annotation:"Temporary Interkid deployment user"}' \
  > /tmp/ssh-create.json

api POST "$API_ROOT/ssh/" \
  -H 'Content-Type: application/json' \
  --data-binary @/tmp/ssh-create.json > /tmp/ssh-created.json
TEMP_SSH_ID="$(jq -r '.id' /tmp/ssh-created.json)"
test -n "$TEMP_SSH_ID" && test "$TEMP_SSH_ID" != null

SSH_HOST="ssh-${ACCOUNT}.alwaysdata.net"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20)

for attempt in {1..12}; do
  if sshpass -p "$SSH_PASS" ssh "${SSH_OPTS[@]}" "$SSH_USER@$SSH_HOST" 'printf ready' >/dev/null 2>&1; then
    break
  fi
  if [ "$attempt" -eq 12 ]; then
    echo 'Temporary alwaysdata SSH access did not become available.' >&2
    exit 1
  fi
  sleep 5
done

tar -czf /tmp/interkid-alwaysdata.tgz \
  index.html \
  searxng/settings.yml \
  deploy/alwaysdata/install.sh \
  deploy/alwaysdata/start.sh

sshpass -p "$SSH_PASS" scp "${SSH_OPTS[@]}" \
  /tmp/interkid-alwaysdata.tgz \
  "$SSH_USER@$SSH_HOST:~/interkid-alwaysdata.tgz"

sshpass -p "$SSH_PASS" ssh "${SSH_OPTS[@]}" "$SSH_USER@$SSH_HOST" <<'REMOTE'
set -eu
rm -rf "$HOME/interkid-deploy"
mkdir -p "$HOME/interkid-deploy"
tar -xzf "$HOME/interkid-alwaysdata.tgz" -C "$HOME/interkid-deploy"
sh "$HOME/interkid-deploy/deploy/alwaysdata/install.sh"
REMOTE

# Configure the account's supplied alwaysdata.net hostname as a User Program site.
api GET "$API_ROOT/site/" > /tmp/sites.json
ADDRESS="${ACCOUNT}.alwaysdata.net"
SITE_ID="$(jq -r --arg a "$ADDRESS" '.[] | select((.addresses // []) | index($a)) | .id' /tmp/sites.json | head -n1)"

jq -n \
  --arg address "$ADDRESS" \
  --arg base_url "https://${ADDRESS}/" \
  '{type:"user_program",addresses:[$address],command:"./start.sh",working_directory:"interkid-search",environment:("SEARXNG_BASE_URL="+$base_url),ssl_force:true,max_idle_time:0,annotation:"Interkid SearXNG"}' \
  > /tmp/site.json

if [ -n "$SITE_ID" ]; then
  api PATCH "$API_ROOT/site/$SITE_ID/" \
    -H 'Content-Type: application/json' \
    --data-binary @/tmp/site.json > /tmp/site-result.json
else
  api POST "$API_ROOT/site/" \
    -H 'Content-Type: application/json' \
    --data-binary @/tmp/site.json > /tmp/site-result.json
  SITE_ID="$(jq -r '.id' /tmp/site-result.json)"
fi

api POST "$API_ROOT/site/$SITE_ID/restart/" >/dev/null

URL="https://${ADDRESS}/"
for attempt in {1..36}; do
  if curl --fail --silent --show-error --max-time 15 "$URL" > /tmp/home.html 2>/dev/null && grep -qi 'interkid' /tmp/home.html; then
    echo "Homepage OK: $URL"
    break
  fi
  if [ "$attempt" -eq 36 ]; then
    echo 'Interkid homepage did not become healthy.' >&2
    exit 1
  fi
  sleep 5
done

curl --fail --silent --show-error --max-time 60 \
  "${URL}search?q=openrockets" > /tmp/search.html
test -s /tmp/search.html
echo "Search endpoint OK: ${URL}search?q=openrockets"

# Revoke the temporary API token when it can be identified by its app name.
# The deployment still succeeds if the token listing omits the matching record.
TOKEN_AUTH="${TOKEN}:"
TOKENS_JSON="$(curl --fail --silent --show-error --basic --user "$TOKEN_AUTH" "$API_ROOT/token/" 2>/dev/null || true)"
TOKEN_ID="$(printf '%s' "$TOKENS_JSON" | jq -r --arg app "$TOKEN_APP" '.[] | select(.app_name==$app) | .id' 2>/dev/null | head -n1 || true)"
if [ -n "$TOKEN_ID" ]; then
  curl --silent --show-error --basic --user "$TOKEN_AUTH" -X DELETE "$API_ROOT/token/$TOKEN_ID/" >/dev/null || true
  echo 'Temporary alwaysdata API token revoked.'
else
  echo 'Deployment complete; automatic API-token revocation could not identify the token.'
fi
