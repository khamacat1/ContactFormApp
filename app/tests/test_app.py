import db


class TestHealthz:
    def test_returns_200_when_db_reachable(self, client):
        resp = client.get("/healthz")
        assert resp.status_code == 200
        assert resp.get_json() == {"status": "ok"}


class TestIndex:
    def test_renders_empty_state(self, client):
        resp = client.get("/")
        assert resp.status_code == 200
        assert b"Recent Submissions" in resp.data

    def test_renders_existing_submissions(self, client):
        db.insert_submission("Alice", "alice@example.com", "Hi there")
        resp = client.get("/")
        assert b"Alice" in resp.data
        assert b"alice@example.com" in resp.data


class TestSubmit:
    def test_valid_submission_is_stored_and_redirects(self, client):
        resp = client.post(
            "/submit",
            data={"name": "Bob", "email": "bob@example.com", "message": "Hello"},
        )
        assert resp.status_code == 302
        rows = db.list_submissions()
        assert len(rows) == 1
        assert rows[0][1:4] == ("Bob", "bob@example.com", "Hello")

    def test_invalid_email_rejected_with_400(self, client):
        resp = client.post(
            "/submit",
            data={"name": "Bob", "email": "not-an-email", "message": "Hello"},
        )
        assert resp.status_code == 400
        assert len(db.list_submissions()) == 0

    def test_empty_name_rejected(self, client):
        resp = client.post(
            "/submit",
            data={"name": "   ", "email": "bob@example.com", "message": "Hello"},
        )
        assert resp.status_code == 400
        assert len(db.list_submissions()) == 0

    def test_error_message_shown_to_user(self, client):
        resp = client.post(
            "/submit",
            data={"name": "", "email": "bob@example.com", "message": "Hello"},
        )
        assert b"required" in resp.data.lower()

    def test_script_tag_is_escaped_not_executed(self, client):
        client.post(
            "/submit",
            data={
                "name": "<script>alert(1)</script>",
                "email": "xss@example.com",
                "message": "test",
            },
        )
        resp = client.get("/")
        assert b"<script>alert(1)</script>" not in resp.data
        assert b"&lt;script&gt;" in resp.data

    def test_missing_fields_rejected(self, client):
        resp = client.post("/submit", data={})
        assert resp.status_code == 400
