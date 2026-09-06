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
PY

# Use the exact result-page search template that already passed Interkid CI.
cat > "$ROOT/search-template.b64" <<'EOF'
PGZvcm0gaWQ9InNlYXJjaCIgbWV0aG9kPSJ7eyBtZXRob2QgfX0iIGFjdGlv
bj0ie3sgdXJsX2Zvcignc2VhcmNoJykgfX0iIHJvbGU9InNlYXJjaCI+CiAg
PGRpdiBpZD0ic2VhcmNoX2hlYWRlciI+CiAgICA8YSBpZD0ic2VhcmNoX2xv
Z28iIGhyZWY9Int7IHVybF9mb3IoJ2luZGV4JykgfX0iIHRhYmluZGV4PSIw
IiB0aXRsZT0ie3sgXygnRGlzcGxheSB0aGUgZnJvbnQgcGFnZScpIH19Ij4K
ICAgICAgPHNwYW4gY2xhc3M9ImludGVya2lkLXJlc3VsdHMtd29yZG1hcmsi
IGRyYWdnYWJsZT0iZmFsc2UiPmludGVya2lkPC9zcGFuPgogICAgPC9hPgoK
ICAgIDxkaXYgaWQ9InNlYXJjaF92aWV3Ij4KICAgICAgPGRpdiBjbGFzcz0i
c2VhcmNoX2JveCI+CiAgICAgICAgPGlucHV0IGlkPSJxIiBuYW1lPSJxIiB0
eXBlPSJ0ZXh0IiBwbGFjZWhvbGRlcj0ie3sgXygnU2VhcmNoIGZvci4uLicp
IH19IiB0YWJpbmRleD0iMSIKICAgICAgICAgIGF1dG9jb21wbGV0ZT0ib2Zm
IiBhdXRvY2FwaXRhbGl6ZT0ibm9uZSIgc3BlbGxjaGVjaz0iZmFsc2UiIGF1
dG9jb3JyZWN0PSJvZmYiCiAgICAgICAgICBlbnRlcmtleWhpbnQ9InNlYXJj
aCIgZGlyPSJhdXRvIiB2YWx1ZT0ie3sgcSBvciAnJyB9fSI+CiAgICAgICAg
PGJ1dHRvbiBpZD0iY2xlYXJfc2VhcmNoIiB0eXBlPSJyZXNldCIgYXJpYS1s
YWJlbD0ie3sgXygnY2xlYXInKSB9fSIgY2xhc3M9ImhpZGVfaWZfbm9qcyI+
CiAgICAgICAgICA8c3Bhbj57eyBpY29uX2JpZygnY2xvc2UnKSB9fTwvc3Bh
bj48c3BhbiBjbGFzcz0ic2hvd19pZl9ub2pzIj57eyBfKCdjbGVhcicpIH19
PC9zcGFuPgogICAgICAgIDwvYnV0dG9uPgogICAgICAgIDxidXR0b24gaWQ9
InNlbmRfc2VhcmNoIiB0eXBlPSJzdWJtaXQiIHslLSBpZiBzZWFyY2hfb25f
Y2F0ZWdvcnlfc2VsZWN0IC0lfW5hbWU9ImNhdGVnb3J5X3t7IHNlbGVjdGVk
X2NhdGVnb3JpZXNbMF18cmVwbGFjZSgnICcsICdfJykgfX0ieyUtIGVuZGlm
IC0lfSBhcmlhLWxhYmVsPSJ7eyBfKCdzZWFyY2gnKSB9fSI+CiAgICAgICAg
ICA8c3BhbiBjbGFzcz0iaGlkZV9pZl9ub2pzIj57eyBpY29uX2JpZygnc2Vh
cmNoJykgfX08L3NwYW4+PHNwYW4gY2xhc3M9InNob3dfaWZfbm9qcyI+e3sg
Xygnc2VhcmNoJykgfX08L3NwYW4+CiAgICAgICAgPC9idXR0b24+CiAgICAg
ICAgPGRpdiBjbGFzcz0iYXV0b2NvbXBsZXRlIGhpZGVfaWZfbm9qcyI+PHVs
PjwvdWw+PC9kaXY+CiAgICAgIDwvZGl2PgogICAgPC9kaXY+CgogICAgeyUg
c2V0IGRpc3BsYXlfdG9vbHRpcCA9IHRydWUgJX0KICAgIHslIGluY2x1ZGUg
J3NpbXBsZS9jYXRlZ29yaWVzLmh0bWwnICV9CiAgPC9kaXY+CgogIDxkaXYg
Y2xhc3M9InNlYXJjaF9maWx0ZXJzIj4KICAgIHslIGluY2x1ZGUgJ3NpbXBs
ZS9maWx0ZXJzL2xhbmd1YWdlcy5odG1sJyAlfQogICAgeyUgaW5jbHVkZSAn
c2ltcGxlL2ZpbHRlcnMvdGltZV9yYW5nZS5odG1sJyAlfQogIDwvZGl2PgoK
ICA8aW5wdXQgdHlwZT0iaGlkZGVuIiBuYW1lPSJzYWZlc2VhcmNoIiB2YWx1
ZT0iMiI+CiAgPGlucHV0IHR5cGU9ImhpZGRlbiIgbmFtZT0idGhlbWUiIHZh
bHVlPSJ7eyB0aGVtZSB9fSI+CiAgeyUgaWYgdGltZW91dF9saW1pdCAlfTxp
bnB1dCB0eXBlPSJoaWRkZW4iIG5hbWU9InRpbWVvdXRfbGltaXQiIHZhbHVl
PSJ7eyB0aW1lb3V0X2xpbWl0fGUgfX0iPnslIGVuZGlmICV9CjwvZm9ybT4K
EOF
base64 -d "$ROOT/search-template.b64" > "$SRC/searx/templates/simple/search.html"
rm -f "$ROOT/search-template.b64"

# Atomically repoint the existing alwaysdata working directory name to the new build.
if [ -e "$LIVE_ALIAS" ] || [ -L "$LIVE_ALIAS" ]; then
  mv "$LIVE_ALIAS" "$HOME/interkid-search-backup-$(date +%s)"
fi
ln -s "$ROOT" "$LIVE_ALIAS"

printf '%s\n' "Interkid SearXNG installed at $ROOT"
printf '%s\n' "Live alias now points to $ROOT"
