FROM python:3.11-slim

WORKDIR /app

COPY tools/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY tools/ ./tools/
COPY .env* ./

EXPOSE 8080

CMD ["python", "tools/ai_proxy_server.py", "--host", "0.0.0.0", "--port", "8080"]