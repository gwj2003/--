# 水生入侵生物综合平台

一个面向维护和演示的前后端分离项目。后端使用 FastAPI + SQLite + 可选 Neo4j，前端使用 Vue 3 + Vite + Leaflet。当前仓库不是传统单页 SPA，而是多页面入口加共享模块的结构。

## 维护者视角

这个仓库最重要的不是页面本身，而是三条链路：

1. 启动链路：`scripts/` 下的批处理和 shell 脚本负责本地启动、Neo4j 拉起和 ngrok 暴露。
2. 后端链路：`backend/` 负责 API、服务层、仓储层、模型和模式定义。
3. 前端链路：`frontend/` 负责多页面入口、旧模板壳、共享模块和案例页功能组件。

## 根目录职责

- `backend/` 后端服务、数据迁移、图谱与问答逻辑
- `frontend/` 前端多页面应用与静态资源
- `scripts/` 本地启动、Neo4j、ngrok 相关脚本
- `environment.yml` Python/Conda 环境定义
- `README.md` 维护者总览
- `SETUP_GUIDE.md` 安装与启动操作手册

## 文件名 → 作用

### 根目录

| 文件名 | 作用 |
|---|---|
| `.gitignore` | 忽略构建产物、依赖目录、本地环境和临时文件 |
| `environment.yml` | 定义后端 Python/Conda 环境，便于重建运行环境 |
| `README.md` | 项目总览，面向维护者说明架构和职责边界 |
| `SETUP_GUIDE.md` | 安装、启动、验证和故障排查手册 |

### 后端

| 文件名 | 作用 |
|---|---|
| `backend/main.py` | FastAPI 入口，负责创建应用并挂载路由 |
| `backend/config.py` | 管理数据库、Neo4j、API Key 等配置 |
| `backend/database.py` | 负责数据库连接、会话和初始化相关逻辑 |
| `backend/api/router.py` | 汇总并注册所有业务路由 |
| `backend/api/errors.py` | 统一 API 异常与错误响应 |
| `backend/api/routes/*.py` | 各业务接口：管理、统计、地理、问答、记录、物种、系统 |
| `backend/services/*.py` | 业务逻辑层，承接路由与数据访问之间的处理 |
| `backend/repositories/*.py` | 数据访问层，封装 SQL 或查询逻辑 |
| `backend/models/*.py` | SQLAlchemy ORM 模型定义 |
| `backend/schemas/*.py` | 请求/响应模式定义 |
| `backend/migrate_csv_to_db.py` | 将 CSV 数据导入 SQLite |
| `backend/import_to_neo4j.py` | 将数据导入 Neo4j 图数据库 |
| `backend/graph_chain.py` | 图谱问答/推理链路相关逻辑 |
| `backend/qa_cache.py` | 问答缓存，减少重复计算 |
| `backend/geo_data.py` | 地理或行政区划数据处理 |
| `backend/species_data.py` | 物种数据整理、读取或映射 |
| `backend/runtime/README.md` | 说明运行时目录的用途 |

### 前端

| 文件名 | 作用 |
|---|---|
| `frontend/index.html` | 首页 HTML 入口 |
| `frontend/privacy-policy.html` | 隐私说明页入口 |
| `frontend/terms-conditions.html` | 服务条款页入口 |
| `frontend/basin-monitoring.html` | 流域监测项目页入口 |
| `frontend/knowledge-graph.html` | 知识图谱应用页入口 |
| `frontend/mobile-monitoring.html` | 移动端监测页入口 |
| `frontend/vite.config.js` | Vite 构建、入口页、别名和代理配置 |
| `frontend/jsconfig.json` | 编辑器路径别名和 JS 感知配置 |
| `frontend/package.json` | 前端依赖、脚本和项目元数据 |
| `frontend/public/` | 旧版页面使用的静态资源 |
| `frontend/src/entries/*.js` | 各 HTML 页面的挂载脚本 |
| `frontend/src/legacy/*.vue` | 首页、法律页和案例页的旧模板壳 |
| `frontend/src/legacy/templates/*.html` | 旧模板的原始 HTML 资源 |
| `frontend/src/features/*.vue` | 三个案例页的功能包装组件 |
| `frontend/src/shared/*` | 可复用的 API、面板、composables 和工具 |
| `frontend/src/api/*.js` | 向旧导入路径提供兼容转发 |
| `frontend/src/utils/*.js` | 向旧工具路径提供兼容转发 |

### 脚本

| 文件名 | 作用 |
|---|---|
| `scripts/run_backend.bat` | Windows 启动后端 |
| `scripts/run_backend.sh` | Linux/macOS 启动后端 |
| `scripts/run_frontend.bat` | Windows 启动前端 |
| `scripts/run_frontend.sh` | Linux/macOS 启动前端 |
| `scripts/start-neo4j.bat` | Windows 启动 Neo4j |
| `scripts/start-neo4j.sh` | Linux/macOS 启动 Neo4j |
| `scripts/start.bat` | Windows 一键启动总入口 |
| `scripts/start.sh` | Linux/macOS 一键启动总入口 |
| `scripts/start-with-ngrok.bat` | Windows 一键启动并暴露 ngrok |
| `scripts/start-with-ngrok.sh` | Linux/macOS 一键启动并暴露 ngrok |

## 当前结构总览

```text
BlueGuard/
├── backend/
│   ├── api/           # 路由与错误封装
│   ├── services/      # 业务逻辑
│   ├── repositories/  # 数据访问
│   ├── models/        # ORM 模型
│   ├── schemas/       # 请求/响应模式
│   └── *.py           # 配置、入口、导入、迁移、图谱、缓存
├── frontend/
│   ├── *.html         # 多页面 HTML 入口
│   ├── public/        # 旧站点静态资源
│   └── src/
│       ├── entries/   # HTML 对应的挂载脚本
│       ├── legacy/    # 旧模板壳与模板解析层
│       ├── features/  # 三个案例页功能包装
│       └── shared/    # 可复用面板、composables、api、工具
└── scripts/           # 启动脚本
```

## 前端分层

- `frontend/src/entries/`：每个 HTML 页面对应一个入口脚本。
- `frontend/src/legacy/`：保留首页、隐私页、条款页这类旧模板壳，以及模板加载逻辑。
- `frontend/src/features/`：流域监测、知识图谱、移动端监测三个案例页的功能包装。
- `frontend/src/shared/`：真正可复用的模块，包含请求封装、地图工具、问答/上报/物种面板和 composables。
- `frontend/src/api/`、`frontend/src/utils/`：兼容旧导入路径的转发层，后续可逐步收敛。

## 后端分层

- `backend/api/`：路由汇总、错误处理、按业务拆分的端点。
- `backend/services/`：业务逻辑与跨仓储编排。
- `backend/repositories/`：数据库访问封装。
- `backend/models/`：SQLAlchemy 基类与 ORM 定义。
- `backend/schemas/`：Pydantic 请求/响应模式。

## 维护常用命令

```bash
# Windows 一键启动
scripts\start.bat

# Windows 启动后端
scripts\run_backend.bat

# Windows 启动前端
scripts\run_frontend.bat

# Windows ngrok 启动
scripts\start-with-ngrok.bat
```

启动后常用地址：

- 前端：http://localhost:5173
- 后端：http://localhost:8000
- API 文档：http://localhost:8000/docs

## 数据与初始化

- 主运行库：`backend/data/species.db`
- 原始导入数据：`backend/data/gbif_results/*.csv`
- 地理数据：`backend/data/geo/china_100000_full.json`
- 运行时说明：`backend/runtime/README.md`

从 CSV 重建本地数据时：

```bash
cd backend
python migrate_csv_to_db.py
```

## 依赖与规范

- Python 环境以 `environment.yml` 为准，仓库内的 `requirements.txt` 主要用于后端 Python 依赖列举。
- 前端依赖以 `frontend/package.json` 为准。
- 推荐使用 `pre-commit` 保持 Python 和前端基础格式一致。

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

## 维护提示

- `frontend/public/` 下的旧版静态资源仍被老模板页面引用，删除前要先全局确认。
- `frontend/src/shared/` 是当前复用层，优先在这里放可共享逻辑，不要再把新代码塞回 `spa/`。
- `dist/` 和 `node_modules/` 属于构建/依赖产物，不应手工维护。
- 如果后端或前端改动了入口文件，优先重新跑一次生产构建再合并。

## 验证标准

维护侧最基本的验证是：

1. 后端能启动并访问 `/docs`。
2. 前端能在 `5173` 正常打开。
3. `npm run build` 成功。
4. 需要公网时，`scripts\start-with-ngrok.bat` 能正常拉起前端隧道。

## 说明

- Neo4j 和部分 API Key 是可选能力，不可用时系统会降级。
- 这是研究和演示用途项目，不建议直接对外暴露生产入口。
