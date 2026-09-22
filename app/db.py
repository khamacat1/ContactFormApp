import os
import psycopg2


def get_connection():
    """Open a new connection using values from the environment.

    Locally these come from a .env file. In AWS, the same variable
    names will be populated from AWS Secrets Manager instead — the
    application code does not need to know the difference.
    """
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
    )


def init_db():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS submissions (
                    id SERIAL PRIMARY KEY,
                    name TEXT NOT NULL,
                    email TEXT NOT NULL,
                    message TEXT NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                );
                """
            )
        conn.commit()
    finally:
        conn.close()


def insert_submission(name: str, email: str, message: str):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO submissions (name, email, message) VALUES (%s, %s, %s);",
                (name, email, message),
            )
        conn.commit()
    finally:
        conn.close()


def list_submissions():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, name, email, message, created_at FROM submissions ORDER BY id DESC;"
            )
            return cur.fetchall()
    finally:
        conn.close()
