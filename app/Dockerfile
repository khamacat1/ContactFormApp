FROM python:3.11-slim

WORKDIR /app

RUN groupadd --system appuser && useradd --system --gid appuser --no-create-home appuser

COPY requirements.txt .
RUN pip install --no-cache-dir --no-compile -r requirements.txt

COPY app.py db.py validation.py ./
COPY templates/ ./templates/

RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 5000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:5000/healthz', timeout=2).status == 200 else 1)"


# --preload imports app.py (and its module-level db.init_db() call) once in
# the master process before forking workers. Without it, each worker
# imports independently and races on CREATE TABLE IF NOT EXISTS, which
# Postgres does not make atomic — two concurrent creates can both pass the
# existence check and collide on the table's catalog entry.
CMD ["gunicorn", "--preload", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
