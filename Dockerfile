# Multi-stage build: Flutter Web + Python AI Server

# === Stage 1: Flutter Web ===
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-builder

WORKDIR /app

# Copy dependencies
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source code
COPY lib/ ./lib/
COPY web/ ./web/

# Build Flutter Web (Release mode)
RUN flutter build web --release --dart-define=AI_PROXY_URL= --no-tree-shake-icons 2>&1
RUN ls -la build/web/

# === Stage 2: Python AI Server ===
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies (rembg needs)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy Python dependencies
COPY tools/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy AI server
COPY tools/ ./tools/

# Copy built web files from Flutter build stage
COPY --from=flutter-builder /app/build/web/ ./static/

# Environment variables
ENV PORT=10000
ENV PYTHONUNBUFFERED=1

EXPOSE $PORT

# Start command
CMD ["python", "tools/ai_proxy_server.py", "--host", "0.0.0.0", "--port", "10000", "--static-dir", "static"]