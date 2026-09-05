#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

export SEARXNG_SETTINGS_PATH="$ROOT/config/settings.yml"
export GRANIAN_INTERFACE="wsgi"
export GRANIAN_HOST="${IP:-::}"
export GRANIAN_PORT="${PORT:-8300}"
export GRANIAN_WORKERS="1"
export GRANIAN_BLOCKING_THREADS="2"
export GRANIAN_WEBSOCKETS="false"

exec "$ROOT/venv/bin/granian" searx.webapp:app
