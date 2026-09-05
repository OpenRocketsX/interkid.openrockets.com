#!/bin/sh
set -eu

ROOT="$HOME/interkid-search"
SRC="$ROOT/searxng-src"
VENV="$ROOT/venv"
CONFIG="$ROOT/config"
STAGE="$HOME/interkid-deploy"

mkdir -p "$ROOT" "$CONFIG"

if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 https://github.com/searxng/searxng.git "$SRC"
else
  git -C "$SRC" fetch --depth 1 origin master
  git -C "$SRC" reset --hard FETCH_HEAD
fi

if [ ! -x "$VENV/bin/python" ]; then
  python -m venv "$VENV"
fi

"$VENV/bin/python" -m pip install -U pip setuptools wheel
"$VENV/bin/python" -m pip install -U pyyaml msgspec typing-extensions pybind11
"$VENV/bin/python" -m pip install --use-pep517 --no-build-isolation -e "$SRC"
"$VENV/bin/python" -m pip install -U granian

cp "$STAGE/index.html" "$SRC/searx/templates/simple/index.html"
cp "$STAGE/searxng/settings.yml" "$CONFIG/settings.yml"
cp "$STAGE/deploy/alwaysdata/start.sh" "$ROOT/start.sh"
chmod 755 "$ROOT/start.sh"

if [ ! -s "$ROOT/secret" ]; then
  "$VENV/bin/python" - <<'PY' > "$ROOT/secret"
import secrets
print(secrets.token_hex(32))
PY
  chmod 600 "$ROOT/secret"
fi

SEARX_SECRET="$(cat "$ROOT/secret")"
SETTINGS="$CONFIG/settings.yml" SEARX_SECRET="$SEARX_SECRET" "$VENV/bin/python" - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["SETTINGS"])
text = path.read_text()
text = text.replace('secret_key: "ultrasecretkey"', f'secret_key: "{os.environ["SEARX_SECRET"]}"')
path.write_text(text)
PY

# If the alwaysdata User Program is already configured, stopping the current
# process lets the platform supervisor immediately start the freshly deployed code.
pkill -f "$VENV/bin/granian searx.webapp:app" 2>/dev/null || true

printf '%s\n' "Interkid SearXNG installed at $ROOT"
printf '%s\n' "User Program command: $ROOT/start.sh"
