# 水生入侵生物综合平台

一个前后端分离的水生入侵物种分析系统：
- 后端：FastAPI + SQLite + 地理分析 + 图谱问答
- 前端：Vue 3 + Leaflet 地图可视化

## 目录

- `backend/` 后端服务与数据处理
- `frontend/` 前端界面
- `start.bat` Windows 一键启动

## 快速启动

### 方式一：一键启动（推荐）

Windows:
```bash
start.bat
```

### 方式二：手动启动

后端：
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

前端（新终端）：
```bash
cd frontend
npm install
npm run dev
```

访问地址：

## 项目架构

## 📚 文档

- **[SETUP_GUIDE.md](./SETUP_GUIDE.md)** - 完整配置与启动指南（环境准备、ngrok 公网访问、工作原理）
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - 常见问题与解决方案
- **[CONTRIBUTING.md](./CONTRIBUTING.md)** - 开发指南与代码规范

## 项目架构
### 前端架构（组件化设计）

从 2026-04-06 起，前端采用组件化架构提升可维护性：

```
frontend/src/
├── components/                      # 功能组件
│   ├── chat/ChatPanel.vue          # 知识问答面板
│   ├── report/ReportPanel.vue      # 数据上报面板
│   └── species/SpeciesMapPanel.vue # 物种分析面板
├── composables/                    # 组合函数（业务逻辑）
│   ├── useChatQa.js               # 问答交互逻辑
│   ├── useReportMap.js            # 上报地图逻辑
│   └── useSpeciesMap.js           # 分析地图逻辑
├── api/                           # API 通信
│   ├── client.js                  # 统一请求客户端
│   └── geocoding.js               # 地理编码服务
└── utils/                         # 工具函数
    └── maps.js                    # 地图底图配置
```

**设计优势：**
- ✅ 组件职责清晰，易于单元测试
- ✅ 业务逻辑剥离到 composables，复用率高
- ✅ API 调用统一管理，便于拦截器和错误处理

### 后端架构（分层设计）

后端采用经典分层架构，自上而下分别是：

```
backend/
├── api/                          # 最上层：API 入口
│   ├── router.py                # 路由汇聚器
│   ├── errors.py                # 异常处理器
│   └── routes/                  # 按业务领域分解
│       ├── admin.py             # 管理端点
│       ├── analytics.py         # 分析与可视化
│       ├── geo.py               # 地理编码
│       ├── qa.py                # 知识问答
│       ├── records.py           # 记录管理
│       ├── species.py           # 物种管理
│       └── system.py            # 系统健康检查
├── services/                    # 业务逻辑层
│   ├── admin.py                # 管理服务
│   ├── analytics.py            # 分析服务
│   ├── geocoding.py            # 地理编码（包含速率限制）
│   ├── qa.py                   # 问答服务
│   ├── records.py              # 记录服务
│   └── species.py              # 物种服务
├── repositories/               # 数据访问层（DAL）
│   ├── species_repository.py   # 物种数据访问
│   ├── records_repository.py   # 记录数据访问
│   └── stats_repository.py     # 统计数据访问
├── models/                     # 数据模型层
│   ├── base.py                # SQLAlchemy Base
│   └── species.py             # ORM 模型定义
└── schemas/                    # 请求/响应模式
    ├── qa.py                  # 问答模式
    └── records.py             # 记录模式
```

**分层说明：**
1. **API 层**：接收请求、参数验证、统一错误处理
2. **服务层**：核心业务逻辑、缓存、数据验证
3. **数据访问层**：SQL 执行、事务管理、结果映射
4. **模型层**：ORM 定义、关系映射

**调用流向：** `Request` → `Route` → `Service` → `Repository` → `Database` → `Response`

## 核心功能

- 分布识别分析：地图点位、热力图、省级统计、MaxEnt 图层
- 智能知识问答：图谱问答 + LLM 降级
- 数据上报：前端表单新增记录，落库保存

## 数据与数据库

### 当前存储

- 主数据库：`backend/data/species.db`
- 原始分布数据：`backend/data/gbif_results/*.csv`（用于初始化/迁移）
- 用户上报记录：写入 SQLite 的 `location_records` 表

### 初始化数据库（从 CSV 导入）

```bash
cd backend
python migrate_csv_to_db.py
```

## 常用 API

### 物种管理（species.py）
- `GET /api/species` - 获取所有物种列表
- `GET /api/species/{species}` - 获取物种详细信息
- `GET /api/locations/{species}` - 获取物种分布位置

### 分析与可视化（analytics.py）
- `GET /api/heatmap/{species}` - 热力图数据
- `GET /api/province-data/{species}` - 省级填色图数据
- `GET /api/maxent-image/{species}` - MaxEnt 预测图像

### 地理编码（geo.py）
- `GET /api/geocode?address=...` - 地点转经纬度
- `GET /api/reverse-geocode?lat=...&lon=...` - 经纬度转地点

### 知识问答（qa.py）
- `POST /api/qa` - 提交问题，获取答案
- `GET /api/qa/suggestions/{species}` - 获取建议问题列表

### 记录管理（records.py）
- `POST /api/record/location` - 新增分布记录
- `GET /api/records` - 获取所有记录

### 系统管理（admin.py、system.py）
- `POST /api/admin/cache/invalidate` - 清除所有缓存（需 X-Admin-Key）
- `GET /api/health` - 系统健康检查

## 测试

详细测试步骤见 `TESTING.md`。

## 说明

- Neo4j 和 API Key 可选，不可用时系统会降级到普通 LLM 回答。
- 本项目是研究用途示例，不建议直接暴露到公网。
