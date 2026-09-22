import os
from flask import Flask, render_template, request, redirect, url_for
from dotenv import load_dotenv

load_dotenv()

import db  # noqa: E402  (import after load_dotenv so os.environ is populated)
from validation import validate_submission, ValidationError  # noqa: E402

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 64 * 1024  # 64 KB — well above any legitimate submission


@app.route("/", methods=["GET"])
def index():
    return render_template("index.html", submissions=db.list_submissions())


@app.route("/submit", methods=["POST"])
def submit():
    try:
        name, email, message = validate_submission(request.form)
    except ValidationError as exc:
        return render_template(
            "index.html",
            submissions=db.list_submissions(),
            error=exc.message,
        ), 400

    db.insert_submission(name, email, message)
    return redirect(url_for("index"))


@app.route("/healthz", methods=["GET"])
def healthz():
    """Liveness/readiness endpoint — used later by Kubernetes probes."""
    try:
        db.get_connection().close()
        return {"status": "ok"}, 200
    except Exception as exc:
        return {"status": "error", "detail": str(exc)}, 503


if __name__ == "__main__":
    db.init_db()
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)), debug=True)
