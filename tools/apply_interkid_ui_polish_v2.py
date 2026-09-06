from pathlib import Path
import re
import subprocess

LEGAL = "https://about.openrockets.com/docs/legal/legal-information"
OPENTHREAD = "https://openrockets.com/i/assets/static/openthread_logo_bash-trans-removebg-preview%20(1).png"
BROWSER_ICON = "https://raw.githubusercontent.com/OpenRocketsX/interkid.openrockets.com/main/assets/interkid-browser-icon.png"
BROWSER_SETUP = "https://github.com/OpenRocketsX/InterKid-browser/releases/download/browser-latest/Browser-Setup.exe"


def need(text: str, needle: str, label: str):
    if needle not in text:
        raise RuntimeError(f"missing {label}: {needle[:100]!r}")


# ---------- homepage ----------
p = Path("index.html")
s = p.read_text()
s = s.replace("https://about.openrockets.com/legal/privacy-policy", LEGAL)
s = s.replace("https://about.openrockets.com/legal/terms", LEGAL)

# Bottom ribbon: OpenThread mark, inverted, ~30% smaller.
old = f'<img class="site-ribbon-icon" src="{BROWSER_ICON}" alt="" draggable="false">'
need(s, old, "homepage ribbon browser icon")
s = s.replace(old, f'<img class="site-ribbon-icon" src="{OPENTHREAD}" alt="" draggable="false">', 1)
s = s.replace(
    '.site-ribbon-icon { width: 28px; height: 28px; object-fit: contain; flex: 0 0 auto; }',
    '.site-ribbon-icon { width: 20px; height: 20px; object-fit: contain; flex: 0 0 auto; filter: invert(1); }',
)
s = s.replace('.site-ribbon-icon { width: 24px; height: 24px; }', '.site-ribbon-icon { width: 17px; height: 17px; }')

# Download button: real download continues normally; UI spinner lasts exactly two seconds.
old = f'<a class="browser-download" href="{BROWSER_SETUP}" download="Browser-Setup.exe">Download</a>'
need(s, old, "homepage browser download link")
s = s.replace(
    old,
    f'<a class="browser-download" id="browser-download" href="{BROWSER_SETUP}" download="Browser-Setup.exe"><span class="browser-download-spinner" aria-hidden="true"></span><span class="browser-download-label">Download</span></a>',
)
needle = '    .browser-download:hover, .browser-download:focus-visible { background: #242424; }'
need(s, needle, "browser download hover CSS")
s = s.replace(
    needle,
    needle
    + '''\n    .browser-download-spinner { width: 14px; height: 14px; margin-right: 7px; display: none; flex: 0 0 auto; border: 2px solid rgba(255,255,255,.38); border-top-color: #fff; border-radius: 50%; animation: interkid-download-spin .7s linear infinite; }\n    .browser-download.is-loading .browser-download-spinner { display: inline-block; }\n    @keyframes interkid-download-spin { to { transform: rotate(360deg); } }''',
)

# Mobile promo: smaller than the search bar, top icon/close row, compact copy, button below.
old_mobile = '''      .browser-promo { width: 100%; grid-template-columns: 40px minmax(0,1fr); gap: 9px; padding: 9px 34px 9px 10px; }
      .browser-promo-icon { width: 40px; height: 40px; }
      .browser-download { grid-column: 1 / -1; width: 100%; min-height: 32px; margin-top: 2px; }
      .browser-promo-title { font-size: 0.88rem; }
      .browser-promo-subtitle { font-size: 0.72rem; }'''
need(s, old_mobile, "mobile browser promo CSS")
s = s.replace(
    old_mobile,
    '''      .browser-promo {
        width: min(92%, 520px);
        grid-template-columns: 1fr auto;
        grid-template-areas: "icon close" "copy copy" "download download";
        gap: 7px 10px;
        padding: 9px 10px 10px;
      }
      .browser-promo-icon { grid-area: icon; width: 36px; height: 36px; }
      .browser-promo-close { grid-area: close; position: static; justify-self: end; align-self: start; width: 25px; height: 25px; }
      .browser-promo-copy { grid-area: copy; }
      .browser-download { grid-area: download; width: 100%; min-height: 32px; margin-top: 1px; }
      .browser-promo-title { font-size: 0.82rem; }
      .browser-promo-subtitle { font-size: 0.67rem; }''',
)

old_js = '''      const promo = document.getElementById("browser-promo");
      const promoClose = document.getElementById("browser-promo-close");
      const syncClearButton = () => clearButton.classList.toggle("visible", input.value.length > 0);'''
need(s, old_js, "homepage promo JS declarations")
s = s.replace(
    old_js,
    '''      const promo = document.getElementById("browser-promo");
      const promoClose = document.getElementById("browser-promo-close");
      const browserDownload = document.getElementById("browser-download");
      const browserDownloadLabel = browserDownload ? browserDownload.querySelector(".browser-download-label") : null;
      const syncClearButton = () => clearButton.classList.toggle("visible", input.value.length > 0);''',
)
old_close = '''      promoClose.addEventListener("click", () => { promo.hidden = true; });
      syncClearButton();'''
need(s, old_close, "homepage promo close behavior")
s = s.replace(
    old_close,
    '''      // No localStorage/sessionStorage: dismissal is intentionally only for this page view.
      promoClose.addEventListener("click", () => { promo.hidden = true; });
      if (browserDownload) {
        browserDownload.addEventListener("click", () => {
          browserDownload.classList.add("is-loading");
          browserDownload.setAttribute("aria-busy", "true");
          if (browserDownloadLabel) browserDownloadLabel.textContent = "Downloading";
          window.setTimeout(() => {
            browserDownload.classList.remove("is-loading");
            browserDownload.removeAttribute("aria-busy");
            if (browserDownloadLabel) browserDownloadLabel.textContent = "Download";
          }, 2000);
        });
      }
      syncClearButton();''',
)
p.write_text(s)


# ---------- results base / authoritative OpenRockets footer ----------
p = Path("searxng/templates/simple/base.html")
s = p.read_text()

# Replace info-circle with current OpenThread image; keep normal colors and About wording.
pattern = r'<a href="https://about\.openrockets\.com/" class="link_on_top_about">.*?<span>\{\{ _\([\'\"]About[\'\"]\) \}\}</span></a>'
replacement = f'<a href="https://about.openrockets.com/" class="link_on_top_about"><img class="interkid-about-icon" src="{OPENTHREAD}" alt="" draggable="false"><span>{{{{ _(\'About\') }}}}</span></a>'
s, n = re.subn(pattern, replacement, s, count=1, flags=re.S)
if n != 1:
    raise RuntimeError(f"About link replacement count was {n}")

# Pull the footer directly from the authoritative OpenRockets Press repository.
reference = subprocess.check_output(
    ["curl", "-fsSL", "https://raw.githubusercontent.com/OpenRockets-Press/openrockets.com/main/index.html"],
    text=True,
)
m = re.search(r'<footer class="home-footer"\b.*?</footer>', reference, re.S)
if not m:
    raise RuntimeError("authoritative home-footer not found")
footer = m.group(0)

# User explicitly excluded the OpenRockets-mode logo + horizontal rule row at top of this footer.
footer, n = re.subn(
    r'\s*<div style="display: flex; flex-direction: column; align-items: flex-start; width: 100%; margin-bottom: 10px;">\s*<img src="i/assets/static/brand/DARKMODEFAVICON\.png".*?</div>\s*',
    '\n      ',
    footer,
    count=1,
    flags=re.S,
)
if n != 1:
    raise RuntimeError("authoritative footer logo row was not removed exactly once")
footer = footer.replace('src="i/assets/static/brand/271742354.png"', 'src="https://openrockets.com/i/assets/static/brand/271742354.png"')
footer = footer.replace("https://about.openrockets.com/legal/terms", LEGAL)
footer = footer.replace("https://about.openrockets.com/legal/privacy-policy", LEGAL)

# Insert only that black footer, below all results and above no status/API iframe.
main_end = s.find("</main>")
if main_end < 0:
    raise RuntimeError("results </main> not found")
start = s.find("{% if endpoint == 'results' %}", main_end)
script_marker = '<script type="text/javascript" src="https://www.termsfeed.com/public/cookie-consent/4.2.0/cookie-consent.js" charset="UTF-8"></script>'
end = s.find(script_marker, start)
if start < 0 or end < 0:
    raise RuntimeError("results footer bounds not found after </main>")
indent_footer = "\n".join("  " + line if line else line for line in footer.splitlines())
s = s[:start] + "{% if endpoint == 'results' %}\n" + indent_footer + "\n\n  " + s[end:]

s = s.replace("https://about.openrockets.com/legal/privacy-policy", LEGAL)
s = s.replace("https://about.openrockets.com/legal/terms", LEGAL)

# Last stylesheet wins over obsolete simplified-footer rules while preserving desktop results design.
extra_css = f'''
  <style id="interkid-authoritative-footer-about-mobile-fix">
    body.results_endpoint #main_results {{ display: flow-root !important; min-height: 70vh !important; }}
    body.results_endpoint #results, body.results_endpoint #urls {{ float: none !important; }}
    body.results_endpoint #pagination {{ clear: both !important; }}
    body.results_endpoint #links_on_top .link_on_top_about {{ display: inline-flex !important; align-items: center !important; gap: 6px !important; }}
    .interkid-about-icon {{ width: 22px !important; height: 22px !important; object-fit: contain !important; display: block !important; filter: none !important; }}

    .home-footer {{ position: static !important; clear: both !important; width: 100% !important; margin-top: 3rem !important; box-sizing: border-box !important; }}
    .home-footer .home-shell {{ width: 100% !important; max-width: 1280px !important; margin-inline: auto !important; padding-inline: 16px !important; box-sizing: border-box !important; }}
    .home-footer .footer-content {{ font-size: .875rem !important; }}
    .home-footer a:hover, .home-footer a:focus-visible {{ text-decoration: underline !important; }}

    @media (max-width: 700px) {{
      body.results_endpoint #links_on_top {{ top: 8px !important; right: 9px !important; }}
      body.results_endpoint #links_on_top .link_on_top_about {{ padding: 6px 7px !important; }}
      .interkid-about-icon {{ width: 21px !important; height: 21px !important; }}
      .home-footer {{ margin-top: 2rem !important; padding-left: 1rem !important; padding-right: 1rem !important; }}
      .home-footer .home-shell {{ padding-inline: 0 !important; }}
      .home-footer .footer-top-row {{ grid-template-columns: 1fr !important; gap: 30px !important; }}
      .home-footer .footer-bottom-row {{ flex-direction: column !important; align-items: flex-start !important; }}
    }}
  </style>
'''
need(s, "</head>", "results head close")
s = s.replace("</head>", extra_css + "</head>", 1)
p.write_text(s)


# ---------- results mobile top row ----------
p = Path("searxng/templates/simple/search.html")
s = p.read_text()
mobile_css = '''
<style id="interkid-results-mobile-top-row">
  @media (max-width: 700px) {
    body.results_endpoint #search_header { position: relative !important; padding: 58px 9px 8px !important; }
    body.results_endpoint .interkid-search-unit { width: 100% !important; display: block !important; margin: 0 auto !important; }
    body.results_endpoint #search_logo { position: absolute !important; top: 13px !important; left: 12px !important; width: auto !important; height: 31px !important; z-index: 40 !important; display: flex !important; align-items: center !important; }
    body.results_endpoint .interkid-results-wordmark { font-size: 1.42rem !important; line-height: 31px !important; }
    body.results_endpoint #search_view, body.results_endpoint #search_view:focus-within { position: static !important; width: 100% !important; max-width: 760px !important; margin: 0 auto !important; }
  }
  @media (max-width: 420px) {
    body.results_endpoint #search_logo { left: 10px !important; }
    body.results_endpoint .interkid-results-wordmark { font-size: 1.3rem !important; }
  }
</style>
'''
need(s, '<form id="search"', "results search form")
if "interkid-results-mobile-top-row" not in s:
    s = s.replace('<form id="search"', mobile_css + '\n<form id="search"', 1)
p.write_text(s)


# ---------- static acceptance checks ----------
checks = {
    "index.html": [LEGAL, OPENTHREAD, "browser-download-spinner", "Downloading", "width: min(92%, 520px)"],
    "searxng/templates/simple/base.html": [LEGAL, "An infrastructure service provider for nonprofits run by exceptional minors and teenagers worldwide.", "OpenRockets is a 100% teen-run United States C-Corporation.", "Ping us anytime", "Twitter / X", "OpenRockets Blog", "Crunchbase", "interkid-about-icon"],
    "searxng/templates/simple/search.html": ["interkid-results-mobile-top-row", "top: 13px", "display: block !important"],
}
for name, needles in checks.items():
    text = Path(name).read_text()
    for needle in needles:
        need(text, needle, f"post-patch {name}")

print("Interkid coordinated UI polish checks passed")
