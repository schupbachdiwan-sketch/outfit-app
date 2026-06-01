# 技术规格书

> 版本：v1.1 | 更新日期：2026-06-01

---

## 1. 技术选型

| 层级 | 技术选型 | 理由 |
|------|---------|------|
| 前端框架 | **Flutter** (Dart) | 一套代码双端运行，2D渲染性能优秀，社区活跃 |
| 状态管理 | **Riverpod** | 2026-06-01选定 |
| 本地存储 | SQLite (sqflite) | 衣物元数据、分类标签等结构化数据 |
| 本地文件 | 设备本地文件系统 | 衣物图片、身材照片等大文件 |
| 云端同步 | **Supabase** | 用户数据跨设备同步 |
| 后端服务 | **Supabase (BaaS)** | 2026-06-01选定，降低运维成本 |
| 认证 | **Supabase Auth** | 邮箱+第三方登录开箱即用 |
| AI抠图 | Remove.bg API / Segment Anything | 衣物去背景 |
| AI试穿合成 | 待评估（Stable Diffusion / 自训练模型 / 第三方API） | 2D衣物贴合身材模板 |
| AI推荐 | OpenAI API / 规则引擎 | 搭配推荐生成 |
| 图片存储 | Supabase Storage / Cloudinary | 衣物图片云端存储 |
| CI/CD | GitHub Actions + Fastlane | 自动构建与发布 |

---

## 2. 项目结构（规划）

```
outfit-app/
├── lib/
│   ├── main.dart                    # 应用入口
│   ├── app.dart                     # MaterialApp 配置
│   ├── core/                        # 核心工具层
│   │   ├── theme/                   # 主题、颜色、字体
│   │   ├── router/                  # 路由配置
│   │   ├── storage/                 # 本地存储抽象
│   │   └── utils/                   # 通用工具函数
│   ├── data/                        # 数据层
│   │   ├── models/                  # 数据模型（dart类）
│   │   ├── repositories/            # 数据仓库
│   │   └── services/                # 远程API服务
│   ├── features/                    # 功能模块（按领域划分）
│   │   ├── auth/                    # 登录注册
│   │   ├── body/                    # 身材模板系统
│   │   ├── wardrobe/                # 衣柜管理
│   │   ├── tryon/                   # 虚拟试衣画布
│   │   ├── recommendation/          # AI搭配推荐
│   │   └── profile/                 # 个人中心
│   └── shared/                      # 共享Widget
│       └── widgets/
├── assets/
│   ├── images/                      # 内置图片资源
│   ├── templates/                   # 身材模板插画文件
│   └── fonts/                       # 字体文件
├── test/                            # 测试
├── docs/                            # 项目文档
├── dev-logs/                        # 开发日志
├── pubspec.yaml                     # 依赖配置
└── CLAUDE.md                        # 项目指引
```

---

## 3. 关键技术难点与应对

### 3.1 AI抠图（衣物去背景）

**方案**：优先接入 Remove.bg API 或使用 `rembg`（Python服务）

**评估指标**：
- 抠图精度：边缘清晰、不残留背景
- 处理速度：< 3秒/张
- 成本：Remove.bg 按调用次数计费

**备选**：使用开源模型 `RMBG-2.0` 自部署

### 3.2 衣物与身材模板合成

**方案**：2D图像分层合成

**流程**：
1. 获取去背景后的衣物PNG
2. 缩放到身体区域参考尺寸
3. 按层级顺序叠加到画布
4. 根据身体区域蒙版裁剪超出部分
5. 用户手动微调位置/大小/旋转

**技术选型**：Flutter `CustomPainter` + `Canvas` API 实现

### 3.3 跨设备同步

**方案**：Supabase Realtime 或 Firebase Firestore

**同步策略**：
- 元数据实时同步（衣物列表、标签、搭配方案）
- 图片文件按需下载（懒加载 + 本地缓存）
- 冲突处理：最后写入为准 + 时间戳

---

## 4. 第三方服务依赖

| 服务 | 用途 | 是否必需 |
|------|------|---------|
| Supabase | 认证、数据库、存储、同步 | 必需 |
| AI抠图API | 衣物去背景 | 必需 |
| OpenAI API | 搭配推荐生成 | v1.0可降级为规则引擎 |
| 电商平台API | 商品信息获取 | v2.0考虑 |

---

## 5. 性能指标

| 指标 | 目标值 |
|------|--------|
| 应用冷启动 | < 2秒 |
| 试衣画布帧率 | ≥ 60fps |
| 衣物加载延迟 | < 200ms |
| AI抠图耗时 | < 3秒 |
| 安装包大小 | < 50MB |

---

## 6. 安全要求

- 所有网络请求使用 HTTPS
- 用户密码 bcrypt 哈希存储
- 用户照片/身材数据仅本人可访问（行级安全策略）
- API Key 不存储在客户端代码中（通过后端代理或 Edge Function）
