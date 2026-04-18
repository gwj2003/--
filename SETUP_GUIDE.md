# BlueGuard 安装与启动指南

这份文档面向维护者和首次接手的人，目标是把环境、启动链路、验证方式和常见故障一次说清。

## 目录

- [环境准备](#环境准备)
- [本地启动](#本地启动)
- [ngrok 公网访问](#ngrok-公网访问)
- [验证与检查](#验证与检查)
- [常见故障](#常见故障)

## 环境准备

### 必需项

1. Python 3.12
   - 用于后端服务和数据脚本。
   - 验证：`python --version`

2. Node.js + npm
   - 用于前端依赖安装和 Vite 构建。
   - 验证：`npm --version`

### 可选项

1. Neo4j
   - 用于知识图谱相关能力。
   - 相关脚本：`scripts\start-neo4j.bat` 和 `scripts/start-neo4j.sh`

2. ngrok
   - 用于把本地前端临时暴露到公网。
   - 下载：https://ngrok.com/download

### 环境定义

- Python/Conda 环境定义：`environment.yml`
- 后端依赖列表：`backend/requirements.txt`
- 前端依赖列表：`frontend/package.json`

## 本地启动

### 推荐方式：一键启动

Windows：

```bash
scripts\start.bat
```

这个入口会按顺序处理 Neo4j、后端和前端，并在前端就绪后打开浏览器。

### 分步方式：手动启动

1. 启动后端

```bash
scripts\run_backend.bat
```

2. 启动前端

```bash
scripts\run_frontend.bat
```

3. 访问地址

- 前端：http://localhost:5173
- 后端：http://localhost:8000
- API 文档：http://localhost:8000/docs

### 首次初始化数据库

如果需要重建本地 SQLite 数据，运行：

```bash
cd backend
python migrate_csv_to_db.py
```

## ngrok 公网访问

### 推荐方式：一键启动 ngrok

Windows：

```bash
scripts\start-with-ngrok.bat
```

这个脚本会自动：

1. 检查并尝试拉起 Neo4j
2. 启动后端
3. 启动前端
4. 启动 ngrok，将前端端口 `5173` 暴露到公网

### 为什么暴露前端而不是后端

维护上建议始终暴露前端 `5173`，原因是：

1. 前端是唯一公开入口，所有 `/api` 请求都会经由 Vite 代理转发到后端。
2. 这样可以避免直接暴露后端时的额外 CORS 复杂度。
3. 后端保留在本机内网，结构更清楚。

### 公网访问链路

```text
浏览器 → ngrok → 前端 5173 → Vite 代理 → 后端 8000 → SQLite / Neo4j
```

## 验证与检查

建议在维护时按下面顺序确认：

1. 后端启动后能访问 `http://localhost:8000/docs`
2. 前端启动后能访问 `http://localhost:5173`
3. `npm run build` 在 `frontend/` 下执行成功
4. 需要公网访问时，`scripts\start-with-ngrok.bat` 能正常输出 Forwarding 地址

### 参考命令

```bash
python --version
npm --version
ngrok --version
```

## 常见故障

### 后端启动失败

- 常见原因：8000 端口被占用，或者 Python/环境未准备好。
- 排查：

```bash
netstat -ano | findstr :8000
```

### 前端启动失败

- 常见原因：5173 端口被占用，或者没有在 `frontend/` 目录下执行前端命令。
- 排查：

```bash
netstat -ano | findstr :5173
```

### ngrok 不可用

- 先确认 `ngrok version` 可执行。
- 再确认已经配置过 `ngrok authtoken <token>`。

### 页面资源或路径异常

- 静态资源优先检查 `frontend/public/`。
- Vue 共享逻辑优先检查 `frontend/src/shared/`。
- 旧模板壳优先检查 `frontend/src/legacy/`。

### 构建失败

- 先在 `frontend/` 目录下执行 `npm run build`。
- 如果是导入路径问题，通常是 `frontend/src/shared/`、`frontend/src/api/` 或 `frontend/src/utils/` 的兼容层发生了变化。

## 维护建议

- 新功能优先放进 `frontend/src/shared/` 或 `frontend/src/features/`，不要再新增 `spa/` 级别目录。
- 旧模板页面只做兼容性维护，不再往里面堆业务逻辑。
- 修改入口脚本或 HTML 入口后，务必重新跑构建。

