# ---------- Builder Stage ----------
FROM python:3.10-slim AS builder

WORKDIR /install

COPY requirements.txt .

RUN pip install --upgrade pip && \
    pip install --prefix=/install --no-cache-dir -r requirements.txt


# ---------- Runtime Stage ----------
FROM python:3.10-slim

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

WORKDIR /app

# 1. Manually create the uploads directory
RUN mkdir -p /app/uploads

COPY --from=builder /install /usr/local
COPY . .

# 2. Ensure appuser owns the whole /app directory, including uploads
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]