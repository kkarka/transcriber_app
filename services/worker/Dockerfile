# ---------- Builder Stage ----------
FROM python:3.10-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends build-essential

WORKDIR /app

# Create a virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY services/worker/requirements.txt .

RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ---------- Runtime Stage ----------
FROM python:3.10-slim

WORKDIR /app

# Install runtime system dependencies (ffmpeg) and clean up apt cache!
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Bring over the pre-built Python packages
COPY --chown=appuser:appgroup --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY --chown=appuser:appgroup services/worker /app
COPY --chown=appuser:appgroup services/common /shared

# Set up user and permissions
RUN mkdir -p /models && chown appuser:appgroup /models

USER appuser

CMD ["rq", "worker", "transcriptions", "--path", "/app"]