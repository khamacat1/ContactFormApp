import os

from dotenv import load_dotenv
from flask import Flask, redirect, render_template, request, url_for

load_dotenv()

import db  # noqa: E402  (import after load_dotenv so os.environ is populated)
from validation import ValidationError, validate_submission  # noqa: E402

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 64 * 1024  # 64 KB — well above any legitimate submission

# Runs on import so it executes under both `python app.py` and a WSGI server
# (gunicorn imports this module directly, never hitting __main__ below).
# Idempotent — CREATE TABLE IF NOT EXISTS — safe to call from every worker.
db.init_db()


@app.route("/", methods=["GET"])
def index():
    return render_template("index.html", submitted=request.args.get("submitted") == "1")


@app.route("/submit", methods=["POST"])
def submit():
    try:
        name, email, message = validate_submission(request.form)
    except ValidationError as exc:
        return render_template("index.html", error=exc.message), 400

    db.insert_submission(name, email, message)
    return redirect(url_for("index", submitted="1"))


@app.route("/healthz", methods=["GET"])
def healthz():
    """Liveness/readiness endpoint — used later by Kubernetes probes."""
    try:
        db.get_connection().close()
        return {"status": "ok"}, 200
    except Exception as exc:
        return {"status": "error", "detail": str(exc)}, 503


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)), debug=True)
