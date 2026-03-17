FROM python:3.10-slim

WORKDIR /app

# Install system dependencies needed for audio/video processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

# Create models directory to match your worker.py download_root
RUN mkdir -p /models && \
    addgroup --system appgroup && \
    adduser --system --ingroup appgroup appuser && \
    chown -R appuser:appgroup /app /models

USER appuser


CMD ["rq", "worker", "transcriptions"]