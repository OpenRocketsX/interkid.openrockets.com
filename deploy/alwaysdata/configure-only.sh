#!/usr/bin/env bash
set -euo pipefail

ACCOUNT="${ALWAYSDATA_ACCOUNT:-interkidtest}"
API_ROOT="https://api.alwaysdata.com/v1"
WORKDIR="interkid-search-33972538951"
ADDRESS="${ACCOUNT}.alwaysdata.net"

DEPLOY_COMMENT="$(jq -r '.comment.body // ""' "$GITHUB_EVENT_PATH")"
TOKEN="${DEPLOY_COMMENT#alwaysdata-deploy:}"
TOKEN="$(printf '%s' "$TOKEN" | tr -d '[:space:]')"
if [ -z "$TOKEN" ] || [ "$TOKEN" = "$DEPLOY_COMMENT" ]; then
  echo 'No deployment token found.' >&2
  exit 1
fi

echo "::add-mask::$TOKEN"
AUTH="${TOKEN} account=${ACCOUNT}:"

curl --fail --silent --show-error --basic --user "$AUTH" \
  "$API_ROOT/site/" > /tmp/sites.json

SITE_ID="$(jq -r --arg a "$ADDRESS" '.[] | select((.addresses // []) | index($a)) | .id' /tmp/sites.json | head -n1)"
if [ -z "$SITE_ID" ]; then
  echo "No existing site found for $ADDRESS" >&2
  jq -c '.[] | {id,type,addresses,working_directory,command}' /tmp/sites.json
  exit 1
fi

echo "Found alwaysdata site ID $SITE_ID for $ADDRESS"
jq -c --argjson id "$SITE_ID" '.[] | select(.id==$id) | {id,type,path,addresses,working_directory,command,environment,ssl_force,max_idle_time}' /tmp/sites.json || true

jq -n \
  --arg workdir "$WORKDIR" \
  --arg base_url "https://${ADDRESS}/" \
  '{type:"user_program",command:"./start.sh",working_directory:$workdir,environment:("SEARXNG_BASE_URL="+$base_url),ssl_force:true}' \
  > /tmp/site-patch.json

echo 'Applying minimal User Program configuration...'
STATUS="$(curl --silent --show-error --basic --user "$AUTH" \
  -H 'alwaysdata-synchronous: yes' \
  -H 'Content-Type: application/json' \
  -X PATCH --data-binary @/tmp/site-patch.json \
  -o /tmp/site-response.json -w '%{http_code}' \
  "$API_ROOT/site/$SITE_ID/")"

if [[ "$STATUS" != 2* ]]; then
  echo "alwaysdata site PATCH failed with HTTP $STATUS" >&2
  cat /tmp/site-response.json >&2 || true
  exit 1
fi

echo "Site configuration accepted (HTTP $STATUS)."
cat /tmp/site-response.json | jq -c '{id,type,addresses,working_directory,command,environment,ssl_force}' || true

curl --fail --silent --show-error --basic --user "$AUTH" \
  -H 'alwaysdata-synchronous: yes' \
  -X POST "$API_ROOT/site/$SITE_ID/restart/" >/dev/null

echo 'Site restart requested.'

URL="https://${ADDRESS}/"
for attempt in {1..36}; do
  HTTP_CODE="$(curl --silent --show-error --max-time 15 -o /tmp/home.html -w '%{http_code}' "$URL" || true)"
  if [ "$HTTP_CODE" = 200 ] && grep -qi 'interkid' /tmp/home.html; then
    echo "Homepage OK: $URL"
    break
  fi
  if [ "$attempt" -eq 36 ]; then
    echo "Homepage did not become healthy; last HTTP status: $HTTP_CODE" >&2
    head -c 1000 /tmp/home.html >&2 || true
    exit 1
  fi
  sleep 5
done

curl --fail --silent --show-error --max-time 60 \
  "${URL}search?q=openrockets" > /tmp/search.html
test -s /tmp/search.html
echo "Search endpoint OK: ${URL}search?q=openrockets"

# Revoke the access token after a successful end-to-end deployment when discoverable.
TOKENS_JSON="$(curl --fail --silent --show-error --basic --user "${TOKEN}:" "$API_ROOT/token/" 2>/dev/null || true)"
TOKEN_ID="$(printf '%s' "$TOKENS_JSON" | jq -r '.[] | select(.app_name=="iutuy") | .id' 2>/dev/null | head -n1 || true)"
if [ -n "$TOKEN_ID" ]; then
  curl --silent --show-error --basic --user "${TOKEN}:" -X DELETE "$API_ROOT/token/$TOKEN_ID/" >/dev/null || true
  echo 'Temporary alwaysdata API token revoked.'
else
  echo 'Site is live; token could not be identified automatically for revocation.'
fi
