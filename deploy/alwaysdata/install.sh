#!/bin/sh
set -eu

ROOT="${INTERKID_ROOT:-$HOME/interkid-search-next}"
SRC="$ROOT/searxng-src"
VENV="$ROOT/venv"
CONFIG="$ROOT/config"
STAGE="${INTERKID_STAGE:-$HOME/interkid-deploy}"

rm -rf "$ROOT"
mkdir -p "$ROOT" "$CONFIG"

git clone --depth 1 https://github.com/searxng/searxng.git "$SRC"
python -m venv "$VENV"

"$VENV/bin/python" -m pip install -U pip setuptools wheel
"$VENV/bin/python" -m pip install -U pyyaml msgspec typing-extensions pybind11
"$VENV/bin/python" -m pip install --use-pep517 --no-build-isolation -e "$SRC"
"$VENV/bin/python" -m pip install -U granian

# Use the exact Interkid templates that passed the container smoke test.
cp "$STAGE/index.html" "$SRC/searx/templates/simple/index.html"
cp "$STAGE/searxng/templates/simple/base.html" "$SRC/searx/templates/simple/base.html"
cp "$STAGE/searxng/templates/simple/search.html" "$SRC/searx/templates/simple/search.html"
cp "$STAGE/searxng/settings.yml" "$CONFIG/settings.yml"
cp "$STAGE/deploy/alwaysdata/start.sh" "$ROOT/start.sh"
chmod 755 "$ROOT/start.sh"

"$VENV/bin/python" - <<'PY' > "$ROOT/secret"
import secrets
print(secrets.token_hex(32))
PY
chmod 600 "$ROOT/secret"

SEARX_SECRET="$(cat "$ROOT/secret")"
SETTINGS="$CONFIG/settings.yml" SEARX_SECRET="$SEARX_SECRET" "$VENV/bin/python" - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["SETTINGS"])
text = path.read_text()
text = text.replace('secret_key: "ultrasecretkey"', f'secret_key: "{os.environ["SEARX_SECRET"]}"')
path.write_text(text)
PY

printf '%s\n' "Interkid SearXNG installed at $ROOT"
printf '%s\n' "Templates: homepage + base + search copied exactly from the tested repository revision"
