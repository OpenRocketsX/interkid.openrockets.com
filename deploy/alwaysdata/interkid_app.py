from pathlib import Path

from flask import redirect, request, send_file
from searx.webapp import app

COOKIE_NAME = "interkid_verification_seen"
VERIFICATION_PAGE = Path(__file__).resolve().parents[2] / "verification.html"


@app.before_request
def interkid_verification_gate():
    if request.path == "/" and request.cookies.get(COOKIE_NAME) != "1":
        return redirect("/verification", code=302)
    return None


@app.get("/verification")
def interkid_verification_page():
    return send_file(VERIFICATION_PAGE, mimetype="text/html")
