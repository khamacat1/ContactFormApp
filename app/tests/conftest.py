import os
import sys

# Make `app.py`, `db.py`, `validation.py` importable as top-level modules,
# matching how the app itself imports them (no package structure).
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Point the app at an isolated test database BEFORE app.py/db.py are
# imported anywhere, so no test ever touches local dev data.
os.environ["DB_HOST"] = os.environ.get("DB_HOST", "localhost")
os.environ["DB_PORT"] = os.environ.get("DB_PORT", "5433")
os.environ["DB_NAME"] = "contactform_test"
os.environ["DB_USER"] = os.environ.get("DB_USER", "contactform")
os.environ["DB_PASSWORD"] = os.environ.get("DB_PASSWORD", "localdevpassword")

import pytest  # noqa: E402

import db  # noqa: E402
from app import app as flask_app  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def _init_test_db():
    db.init_db()


@pytest.fixture(autouse=True)
def _clean_table():
    """Every test starts with an empty submissions table."""
    conn = db.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE submissions RESTART IDENTITY;")
        conn.commit()
    finally:
        conn.close()
    yield


@pytest.fixture
def client():
    flask_app.config.update(TESTING=True)
    with flask_app.test_client() as c:
        yield c
