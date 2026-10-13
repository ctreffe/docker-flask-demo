# Keep the Python minor version explicit. Hosting admins should review base-image
# updates; this tag can still receive maintenance updates when the image is rebuilt.
FROM python:3.13-slim

# Write logs immediately and avoid writing .pyc files in a read-only container.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Copy dependencies first: Docker can reuse this layer when only app code changes.
COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt \
    && groupadd --gid 10001 app \
    && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

# Copy only runtime files. The image does not contain .env, Git history or CI tokens.
COPY app.py .
COPY templates/ templates/

# Running the app as a normal user limits what it can change inside the container.
USER app
EXPOSE 8000

# Python is already installed, so the health check does not need curl or another tool.
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).close()"

# The JSON form starts Gunicorn directly, so Docker can deliver shutdown signals.
# Logs go to stdout/stderr and are available through `docker compose logs`.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--worker-tmp-dir", "/tmp", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
