# BlueGuard 完整配置与启动指南

## 📋 目录

- [环境准备](#环境准备)
- [快速启动 (本地)](#快速启动-本地)
- [ngrok 公网访问](#ngrok-公网访问)
- [访问方式](#访问方式)
- [背景原理](#背景原理)

---

## 环境准备

### 前置要求

1. **Python 3.8+**（推荐 3.10+）
   - 下载：https://www.python.org/downloads/
   - 验证：`python --version`

2. **Node.js & npm**
   - 下载：https://nodejs.org/
   - 验证：`npm --version`

3. **Neo4j 数据库**（可选，用于知识图谱）
   - 下载：https://neo4j.com/download/
   - 或运行：`start-neo4j.bat`

4. **ngrok**（可选，用于公网访问）
   - 下载：https://ngrok.com/download
   - 或使用 npm：`npm install -g ngrok`
   - 账户：访问 https://dashboard.ngrok.com/signup 并获取 authtoken

### 初始化 ngrok（仅第一次需要）

如果需要公网访问功能，运行一次：

```bash
ngrok authtoken <你的-token>
```

获取 token：
1. 登录 https://dashboard.ngrok.com
2. 左侧菜单 → Tunnels → Your Authtoken
3. 复制并运行上述命令

---

## 快速启动 (本地)

### 🎯 方式一：一键启动（最简单）

**Windows:**
```bash
start.bat
```

等待终端输出：
```
📱 前端地址：http://localhost:5173
🔌 后端 API：http://localhost:8000
📚 API 文档：http://localhost:8000/docs
```

### 🎯 方式二：手动启动

#### 终端 1 - 启动后端

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

预期输出：
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete
```

#### 终端 2 - 启动前端

```bash
cd frontend
npm install
npm run dev
```

预期输出：
```
VITE v4.x.x  ready in xx ms

➜  Local:   http://localhost:5173/
➜  press h to show help
```

#### 访问应用

在浏览器中打开：
- **前端**：http://localhost:5173
- **后端 API**：http://localhost:8000
- **API 文档**：http://localhost:8000/docs（可测试 API）

---

## ngrok 公网访问

### 🌍 启动步骤

如果要让其他电脑通过互联网访问你的应用，需要使用 ngrok 隧道。

#### 第一步：启动 Neo4j（可选）

```bash
start-neo4j.bat
```

#### 第二步：一键启动所有服务（推荐）

```bash
start-with-ngrok.bat
```

此脚本会自动在 4 个终端中启动：
- 后端 FastAPI（`localhost:8000`）
- ngrok 隧道（暴露前端 `5173`）
- 前端 Vite（`localhost:5173`）
- 信息提示窗口

> ⚠️ **首次启动提示**：前端可能需要重启一次才能生效
> - 在前端终端中按 `Ctrl+C` 停止
> - 再次运行 `npm run dev`

#### 第三步：获取公网 URL

查看 **ngrok 终端窗口**，找到以下行：

```
Forwarding   https://xxxx-xxxx-xxxx.ngrok-free.dev → http://localhost:5173
```

这个 `https://xxxx-xxxx-xxxx.ngrok-free.dev` 就是你的公网地址。

#### 第四步：分享给其他人

其他人在浏览器中打开这个 URL，就能看到你的完整应用。

---

### 🔧 手动启动（高级）

如果一键脚本不起作用，可以手动启动：

```bash
# 终端 1：后端
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000

# 终端 2：ngrok（暴露前端端口 5173）
ngrok http 5173

# 终端 3：前端
cd frontend
npm run dev
```

**重要：** 暴露 `5173`（前端）而不是 `8000`（后端），原因见下方"背景原理"

---

## 访问方式

### 本地访问（你的电脑）

| 用途 | 地址 |
|------|------|
| 前端/网页 | http://localhost:5173 |
| 后端 API | http://localhost:8000 |
| API 测试页面 | http://localhost:8000/docs |
| 后端监控 | http://localhost:8000/redoc |

### 公网访问（其他电脑）

| 用途 | 地址 |
|------|------|
| 前端/网页 | `https://xxxx-xxxx-xxxx.ngrok-free.dev` |
| 自动转发 | 无需手动配置，前端已设置代理 |

### ngrok 内部监控（调试）

| 用途 | 地址 |
|------|------|
| ngrok 请求监控 | http://127.0.0.1:4040 |

在这个页面可以看到所有通过 ngrok 的请求和响应详情，用于调试。

---

## 背景原理

### 没有 ngrok 时（本地）

```
你的浏览器
   ↓
localhost:5173（前端）
   ↓
localhost:8000（后端）
   ↓
Neo4j 数据库
```

### 使用 ngrok 时（公网）

```
其他电脑浏览器访问 https://xxxx-xxxx-xxxx.ngrok-free.dev
                        ↓
                ngrok 隧道（双向转发）
                        ↓
            你的电脑 localhost:5173（前端）
                        ↓
            前端 JavaScript 代码调用 /api
                        ↓
          Vite 代理转发到 localhost:8000
                        ↓
          你的电脑 localhost:8000（后端）
                        ↓
                Neo4j 数据库
                        ↓
            响应数据给浏览器
```

### 为什么暴露前端（5173）而不是后端（8000）？

1. **前端作为唯一入口**：所有请求都经过前端
2. **代理转发**：前端 Vite 的代理配置会自动转发 `/api` 请求到后端
3. **跨域问题**：直接暴露后端会产生复杂的 CORS 问题
4. **安全性**：后端隐藏在内网，只通过前端访问

### 项目配置文件

| 文件 | 作用 |
|------|------|
| `.env` | CORS 允许的源列表（包含 ngrok 通配符） |
| `backend/main.py` | 后端 CORS 中间件配置 |
| `frontend/vite.config.js` | 前端代理配置（`/api` → `:8000`） |
| `start-with-ngrok.bat` | 一键启动脚本 |

---

## 验证配置

可手动快速检查环境：

```bash
python --version
npm --version
ngrok --version
```

并确认以下文件存在且配置正确：
- ✓ `.env`
- ✓ `backend/main.py`（CORS）
- ✓ `frontend/vite.config.js`（proxy 和 allowedHosts）

---

## 需要帮助？

遇到问题？查看 [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)

常见问题包括：
- ngrok URL 显示"被阻止"
- API 调用返回 CORS 错误
- 端口被占用
- 其他电脑无法访问
- 依赖缺失
