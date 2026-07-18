@echo off
taskkill /F /IM python.exe 2>nul
timeout /t 2 /nobreak >nul
cd /d C:\Users\41926\Desktop\CLAUDE
"C:\Users\41926\AppData\Local\Programs\Python\Python311\python.exe" tools\ai_proxy_server.py --port 8080
pause
