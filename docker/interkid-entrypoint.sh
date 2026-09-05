#!/bin/sh
set -eu

SETTINGS=/etc/searxng/settings.yml

if [ -z "${SEARXNG_SECRET:-}" ]; then
  SEARXNG_SECRET="$(head -c 48 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 48)"
fi

# Inject a stable production secret when provided, otherwise use the generated one.
sed -i "s/secret_key: \"ultrasecretkey\"/secret_key: \"${SEARXNG_SECRET}\"/" "$SETTINGS"

# Enable limiter only when explicitly requested. This is intended for deployments
# that also provide SEARXNG_VALKEY_URL (for example the included Compose stack).
if [ "${SEARXNG_LIMITER:-false}" = "true" ]; then
  sed -i 's/limiter: false/limiter: true/' "$SETTINGS"
fi

exec /usr/local/searxng/entrypoint.sh
