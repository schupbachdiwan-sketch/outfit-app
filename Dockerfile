FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y libgl1-mesa-glx libglib2.0-0 && rm -rf /var/lib/apt/lists/*

COPY tools/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY tools/ ./tools/

# 阿里云函数计算默认端口9000
ENV PORT=9000
EXPOSE 9000

CMD ["python", "tools/ai_proxy_server.py", "--host", "0.0.0.0", "--port", "9000"]