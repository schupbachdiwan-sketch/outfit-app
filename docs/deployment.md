# 部署指南

> 更新日期：2026-07-19

---

## 概述

本项目采用 **单容器全栈部署** 方案：
- **前端**：Flutter Web（编译为静态文件）
- **后端**：Python FastAPI AI 代理服务器
- **平台**：Render（免费计划）

访问地址：`https://outfit-ai-app.onrender.com`

---

## 部署步骤

### 1. 准备工作

确保以下文件已更新并提交到 GitHub：

```
├── Dockerfile              # 多阶段构建配置
├── render.yaml             # Render 部署配置
├── tools/
│   ├── ai_proxy_server.py  # AI 服务器（v0.7.0+）
│   └── requirements.txt
└── lib/
    └── core/
        └── network/
            └── api_config.dart  # API 配置
```

### 2. 推送代码

```bash
git add .
git commit -m "[Phase 7] 配置 Render 全栈部署"
git push origin main
```

### 3. 在 Render 创建服务

1. 访问 [render.com](https://render.com) 并登录
2. 点击 **New +** → **Web Service**
3. 连接 GitHub 仓库：`schupbachdiwan-sketch/outfit-app`
4. 配置：
   - **Name**: `outfit-ai-app`
   - **Region**: Singapore（离中国最近）
   - **Branch**: `main`
   - **Runtime**: Docker
   - **Plan**: Free

5. 添加环境变量：
   - `DASHSCOPE_API_KEY` = `sk-你的阿里云DashScope密钥`
   - `PORT` = `10000`

6. 点击 **Create Web Service**

### 4. 等待部署完成

首次部署约需 **10-15分钟**（下载 Flutter SDK + 编译 Web + 安装 Python 依赖）

部署成功后，访问：`https://outfit-ai-app.onrender.com`

---

## 验证部署

### 1. 检查健康状态

```bash
curl https://outfit-ai-app.onrender.com/api/health
```

预期返回：
```json
{
  "status": "ok",
  "service": "OutfitApp AI Proxy",
  "version": "0.7.0",
  "dashscope": {
    "configured": true,
    "key_prefix": "sk-15ca3a***"
  }
}
```

### 2. 测试 AI 功能

- 打开浏览器访问 `https://outfit-ai-app.onrender.com`
- 测试抠图：上传一张衣服图片
- 测试模特生成：输入身材数据
- 测试试衣：上传身体照片和衣服

---

## 手机访问

### iOS (Safari)

1. 打开 Safari，访问 `https://outfit-ai-app.onrender.com`
2. 点击分享按钮（方框+箭头）
3. 选择 **添加到主屏幕**
4. 输入名称（如"穿搭助手"）
5. 点击 **添加**

### Android (Chrome)

1. 打开 Chrome，访问 `https://outfit-ai-app.onrender.com`
2. 点击菜单（三个点）
3. 选择 **添加到主屏幕**
4. 输入名称
5. 点击 **添加**

---

## 常见问题

### Q: 部署失败怎么办？

检查 Render 的 **Logs** 标签页，常见原因：
- Flutter SDK 下载超时：重新部署
- Python 依赖安装失败：检查 `requirements.txt`
- 环境变量未配置：确保 `DASHSCOPE_API_KEY` 已添加

### Q: AI 功能不工作？

1. 访问 `/api/health` 检查 `dashscope.configured` 是否为 `true`
2. 如果为 `false`，在 Render 环境变量中添加 `DASHSCOPE_API_KEY`
3. 重新部署

### Q: 页面空白？

1. 检查浏览器控制台是否有错误
2. 确保访问的是 `https://outfit-ai-app.onrender.com`（不是 `http`）
3. 清除浏览器缓存后重试

### Q: 免费计划有什么限制？

- **自动休眠**：15分钟无请求后休眠，首次访问需等待 30-60 秒唤醒
- **每月 750 小时**：足够个人使用
- **带宽**：100GB/月

---

## 更新部署

推送代码到 `main` 分支会自动触发重新部署：

```bash
git add .
git commit -m "更新描述"
git push origin main
```

Render 会自动检测变更并重新部署（约 5-10 分钟）。

---

## 监控

### 查看日志

1. 登录 Render 控制台
2. 选择 `outfit-ai-app` 服务
3. 点击 **Logs** 标签

### 健康检查

Render 会自动每 30 秒访问 `/api/health` 检查服务状态。

如果连续失败，Render 会自动重启服务。

---

## 回滚

如果新版本有问题：

1. 在 Render 控制台选择服务
2. 点击 **Manual Deploy**
3. 选择 **Clear build cache & deploy** 或选择之前的 commit
4. 等待部署完成

---

## 本地开发

本地开发时，使用独立的 AI 服务器：

```bash
# 终端 1：启动 AI 服务器
python tools/ai_proxy_server.py --port 8080

# 终端 2：启动 Flutter Web
flutter run -d chrome --dart-define=AI_PROXY_URL=http://localhost:8080
```

---

## 技术架构

```
┌─────────────────────────────────────────────────────────┐
│                    Render (Free Plan)                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Docker Container                    │   │
│  │                                                  │   │
│  │  ┌──────────────┐    ┌──────────────────────┐   │   │
│  │  │  Python AI   │    │   Flutter Web        │   │   │
│  │  │  Server      │    │   (Static Files)     │   │   │
│  │  │              │    │                      │   │   │
│  │  │  - remove-bg │◄───│  - index.html        │   │   │
│  │  │  - enhance   │    │  - main.dart.js      │   │   │
│  │  │  - generate  │    │  - assets/           │   │   │
│  │  │  - try-on    │    │                      │   │   │
│  │  └──────────────┘    └──────────────────────┘   │   │
│  │                                                  │   │
│  │  Port: 10000                                     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  URL: https://outfit-ai-app.onrender.com               │
└─────────────────────────────────────────────────────────┘
```

---

## 下一步

- [ ] 配置自定义域名（可选）
- [ ] 设置 GitHub Actions 自动测试
- [ ] 添加错误监控（Sentry）
- [ ] 配置 CDN 加速（Cloudflare）
