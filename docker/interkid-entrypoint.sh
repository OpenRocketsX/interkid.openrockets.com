#!/bin/sh
set -eu

if [ -z "${SEARXNG_SECRET:-}" ]; then
  SEARXNG_SECRET="$(head -c 48 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 48)"
  export SEARXNG_SECRET
fi

exec /usr/local/searxng/entrypoint.sh
