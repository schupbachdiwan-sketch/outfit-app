# ═══════════════════════════════════════════════════════════
#  多阶段构建：Flutter Web + Python AI Server
# ═══════════════════════════════════════════════════════════

# ── Stage 1: 编译 Flutter Web ──────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-builder

WORKDIR /app

# 复制依赖文件
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 复制源码
COPY lib/ ./lib/
COPY assets/ ./assets/
COPY web/ ./web/

# 编译 Flutter Web（Release模式）
RUN flutter build web --release --dart-define=AI_PROXY_URL=

# ── Stage 2: Python AI Server ─────────────────────────────
FROM python:3.11-slim

WORKDIR /app

# 安装系统依赖（rembg 需要）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 复制 Python 依赖
COPY tools/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制 AI 服务器
COPY tools/ ./tools/

# 从 Flutter 构建阶段复制编译好的 Web 文件
COPY --from=flutter-builder /app/build/web/ ./static/

# 环境变量
ENV PORT=10000
ENV PYTHONUNBUFFERED=1

EXPOSE $PORT

# 启动命令
CMD ["python", "tools/ai_proxy_server.py", "--host", "0.0.0.0", "--port", "10000", "--static-dir", "static"]
