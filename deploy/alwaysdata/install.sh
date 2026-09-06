#!/bin/sh
set -eu

ROOT="${INTERKID_ROOT:-$HOME/interkid-search-next}"
SRC="$ROOT/searxng-src"
VENV="$ROOT/venv"
CONFIG="$ROOT/config"
STAGE="${INTERKID_STAGE:-$HOME/interkid-deploy}"
LIVE_ALIAS="$HOME/interkid-search-33972538951"

rm -rf "$ROOT"
mkdir -p "$ROOT" "$CONFIG"

git clone --depth 1 https://github.com/searxng/searxng.git "$SRC"
python -m venv "$VENV"

"$VENV/bin/python" -m pip install -U pip setuptools wheel
"$VENV/bin/python" -m pip install -U pyyaml msgspec typing-extensions pybind11
"$VENV/bin/python" -m pip install --use-pep517 --no-build-isolation -e "$SRC"
"$VENV/bin/python" -m pip install -U granian

cp "$STAGE/index.html" "$SRC/searx/templates/simple/index.html"
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

SRC_DIR="$SRC" "$VENV/bin/python" - <<'PY'
import os
import re
from pathlib import Path

src = Path(os.environ["SRC_DIR"])
base_path = src / "searx/templates/simple/base.html"
search_path = src / "searx/templates/simple/search.html"

base = base_path.read_text()
base = base.replace(
    'href="{{ url_for(\'info\', pagename=\'about\') }}"',
    'href="https://openrockets.com/"'
)
base = re.sub(
    r'<link rel="icon"[^>]*>\s*<link rel="icon"[^>]*>\s*<link rel="apple-touch-icon"[^>]*>',
    '<link rel="icon" href="https://openrockets.com/favicon.ico" sizes="any">\n'
    '  <link rel="shortcut icon" href="https://openrockets.com/favicon.ico">\n'
    '  <link rel="apple-touch-icon" href="https://openrockets.com/favicon.ico">',
    base,
    count=1,
    flags=re.S,
)
style = r'''
<style id="interkid-branding">
@font-face{font-family:"Google Sans Flex";src:url("https://fonts.gstatic.com/s/googlesans/v29/4UaGrENHsxJlGDuGo1OIlL3Owp5eKQtG.woff2") format("woff2");font-display:swap}
body,input,button,select,textarea{font-family:"Google Sans Flex","Outfit","Google Sans",Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
#search_header{grid-template-columns:7.3rem minmax(0,1fr);gap:.8rem 1rem}
#search_logo{width:auto;min-width:0;padding:.45rem .35rem 0;justify-content:flex-start;text-decoration:none;overflow:visible}
.interkid-results-wordmark{display:inline-block;color:var(--color-base-font);font-family:"Google Sans Flex","Outfit",sans-serif;font-size:1.62rem;font-weight:500;line-height:1;letter-spacing:-.055em;white-space:nowrap;user-select:none;-webkit-user-select:none;-webkit-user-drag:none}
#search_view{min-width:0}.search_box{border-radius:999px;overflow:hidden}#q{border-radius:999px 0 0 999px}#send_search{border-radius:0 999px 999px 0}
body.results_endpoint footer{margin-top:2.25rem;padding-bottom:max(1.25rem,env(safe-area-inset-bottom))}body.results_endpoint footer p{font-size:.82rem;opacity:.72}
@media screen and (max-width:720px){#search_header{padding:.9rem .75rem 0;grid-template-columns:1fr;grid-template-areas:"logo" "search" "categories";gap:.55rem}#search_logo{padding:.15rem .35rem;justify-content:center}.interkid-results-wordmark{font-size:1.48rem}#search_view,body.results_endpoint #search_view{padding:.15rem 0}.search_box{max-width:none}#q,#send_search{font-size:1rem}.search_filters{margin-left:.75rem!important;margin-right:.75rem!important}}
</style>
'''
base = base.replace('</head>', style + '</head>', 1)
base = re.sub(
    r'<footer>.*?</footer>',
    '<footer><p>© 2024–2026 OpenRockets Inc. All rights reserved. · Powered by '
    '<a href="https://github.com/searxng/searxng">SearXNG</a></p></footer>',
    base,
    count=1,
    flags=re.S,
)
base_path.write_text(base)

search = search_path.read_text()
search = re.sub(
    r'(<a id="search_logo".*?>).*?(</a>)',
    r'\1\n      <span class="interkid-results-wordmark" draggable="false">interkid</span>\n    \2',
    search,
    count=1,
    flags=re.S,
)
search = re.sub(r"\s*\{% include ['\"]simple/filters/safesearch\.html['\"] %\}", "", search)
if 'name="safesearch" value="2"' not in search:
    search = search.replace(
        '<input type="hidden" name="theme"',
        '<input type="hidden" name="safesearch" value="2">\n  <input type="hidden" name="theme"',
        1,
    )
search_path.write_text(search)
PY

# Atomically repoint the existing alwaysdata working directory name to the new build.
if [ -e "$LIVE_ALIAS" ] || [ -L "$LIVE_ALIAS" ]; then
  mv "$LIVE_ALIAS" "$HOME/interkid-search-backup-$(date +%s)"
fi
ln -s "$ROOT" "$LIVE_ALIAS"

printf '%s\n' "Interkid SearXNG installed at $ROOT"
printf '%s\n' "Live alias now points to $ROOT"
