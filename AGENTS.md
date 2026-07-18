# AGENTS.md — 穿搭辅助App 项目指引

## 项目概述

一款面向18-35岁年轻用户的**2D平面风格穿搭辅助App**（Android + iOS），使用 Flutter 跨平台开发。核心功能：虚拟试衣画布、AI智能搭配推荐、虚拟衣柜管理。

---

## 关键文件索引

| 文件 | 路径 | 说明 |
|------|------|------|
| 产品需求文档（PRD） | `docs/PRD.md` | 功能需求、用户角色、界面结构、非功能需求 |
| 技术规格书 | `docs/tech-spec.md` | 技术选型、项目结构、第三方依赖、安全要求 |
| 设计规范 | `docs/design-guidelines.md` | 配色、字体、间距、组件、动效、空状态 |
| 开发路线图 | `docs/development-roadmap.md` | 7个Phase分期计划、任务清单、风险提示 |
| 开发日志目录 | `dev-logs/` | 每日开发记录 |
| 日志模板 | `dev-logs/template.md` | 新建日志时复制此模板 |

---

## 工作约定

### 每次对话结束时
- 更新当天的 `dev-logs/YYYY-MM-DD.md`，记录已完成事项和待办事项
- 如涉及需求/设计/技术变更，同步更新对应 docs 文件

### 开始新任务前
- 先阅读 `docs/development-roadmap.md` 确认当前Phase和任务优先级
- 阅读对应模块的PRD章节和设计规范
- 如有疑问，先沟通再动手

### 代码修改原则
- 每次只做一个Phase内的任务，不跨Phase
- 一个功能点完成后，先验证再进入下一个
- 关键功能（AI抠图、试衣合成）先做POC技术验证，确认可行后再正式开发

### Git提交
- 提交前确认代码可编译运行
- 提交信息格式：`[Phase X] 简短描述`
- 不在代码中提交API Key、证书等敏感信息

### 设计还原
- UI实现前先对照 `docs/design-guidelines.md`
- 颜色/字号/间距使用规范中定义的值，不自行发挥

### AI相关功能
- AI抠图：调用 Remove.bg API 或 RMBG-2.0 自部署服务
- AI试穿合成：Phase 5前先做POC，确认效果达标再集成
- AI搭配推荐：v1.0先用规则引擎过渡，v2.0接入大模型

---

## 当前状态

- **阶段**：Phase 0 — 项目初始化
- **下一步**：确认PRD和设计规范 → 技术POC → 初始化Flutter项目

---

## 技术速查

- **框架**：Flutter (Dart)
- **状态管理**：待定（Riverpod 或 Bloc）
- **后端**：优先 Supabase（认证+数据库+存储+同步）
- **AI抠图**：Remove.bg API / RMBG-2.0
- **AI试穿**：待POC验证（Stable Diffusion / Flutter Canvas 2D合成）
- **最低OS版本**：iOS 15+ / Android 10+
