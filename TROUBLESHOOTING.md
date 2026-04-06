# BlueGuard 常见问题与解决方案

## 🔍 快速诊断

遇到问题？按以下步骤诊断：

1. **先做环境自检**：运行 `python --version`、`npm --version`、`ngrok --version`
2. **查看错误信息**：记录完整的错误文本
3. **在本页面搜索**：Ctrl+F 搜索关键词
4. **检查浏览器控制台**：F12 打开开发者工具 → Console 标签

---

## 启动相关

### ❌ 错误：`python: command not found` 或 `'python' 不是内部或外部命令`

**原因**：Python 未安装或未添加到系统 PATH

**解决**：
1. 下载并安装 Python（https://www.python.org/downloads/）
2. **重要**：安装时勾选 "Add Python to PATH"
3. 重启 VS Code 或终端
4. 验证：`python --version`

---

### ❌ 错误：`npm: command not found` 或 `'npm' 不是内部或外部命令`

**原因**：Node.js 未安装或未添加到 PATH

**解决**：
1. 下载并安装 Node.js（https://nodejs.org/）
2. Node.js 安装时会自动安装 npm
3. 重启 VS Code 或终端
4. 验证：`npm --version`

---

### ❌ 错误：后端启动失败 - `Uvicorn running on ... ERROR`

**原因**：通常是端口 8000 被占用

**解决**：

**Windows（查找占用的进程）**：
```bash
netstat -ano | findstr :8000
```

输出示例：
```
TCP  0.0.0.0:8000  LISTENING  12345
```

关闭占用的进程（替换 `12345` 为实际 PID）：
```bash
taskkill /PID 12345 /F
```

或者更换后端端口：
```bash
uvicorn main:app --host 0.0.0.0 --port 8001
```

---

### ❌ 错误：前端启动失败 - npm 相关

**原因 1**：依赖缺失

**解决**：
```bash
cd frontend
npm install
npm run dev
```

**原因 2**：端口 5173 被占用

**解决**：查找并关闭占用端口的进程
```bash
netstat -ano | findstr :5173
taskkill /PID <PID> /F
```

或者更换前端端口：
```bash
npm run dev -- --port 5174
```

---

### ❌ 错误：`start.bat` 或 `start-with-ngrok.bat` 无法运行

**原因**：脚本文件路径问题或权限问题

**解决**：
1. 确保在项目根目录运行这些命令
2. 如果显示"无法识别"，尝试：
   ```bash
   .\start.bat
   ```
3. 如果依然失败，改用手动启动（见 SETUP_GUIDE.md）

---

## ngrok 相关

### ❌ 错误：`ngrok: command not found`

**原因**：ngrok 未安装或未添加到 PATH

**解决**：
1. 下载 ngrok：https://ngrok.com/download
2. 或使用 npm：`npm install -g ngrok`
3. 重启终端
4. 验证：`ngrok version`

---

### ❌ 错误：`ngrok authtoken invalid` 或 `Unauthorized`

**原因**：token 错误或过期

**解决**：
1. 登录 https://dashboard.ngrok.com
2. 从左侧菜单 → "Your Authtoken" 获取新 token
3. 运行命令：
   ```bash
   ngrok authtoken <你的-新-token>
   ```
4. 重启 ngrok

---

### ❌ 访问 ngrok URL 显示："Blocked request. This host is not allowed"

**原因**：Vite 接收到不认识的主机名

**解决**：
1. 前端文件 `frontend/vite.config.js` 已配置（应该不会出现）
2. 如果还是出现，尝试：
   - 重启前端服务：按 `Ctrl+C` 后运行 `npm run dev`
   - 清除浏览器缓存：F12 → 右键刷新 → "清空缓存并硬性重新加载"
   - 检查 ngrok URL 是否输入正确（复制粘贴，不要手动输入）

---

### ❌ ngrok 显示 " offline"

**原因**：网络连接问题或 ngrok 后台故障

**解决**：
1. 检查网络连接
2. 重启 ngrok：按 `Ctrl+C` 后重新运行 `ngrok http 5173`
3. 如果持续 offline，检查 ngrok 状态页：https://status.ngrok.com

---

### ⚠️ ngrok URL 经常变化（免费版本正常现象）

**说明**：
- 免费版本每次重启时都会分配新 URL
- 这是正常的，不需要担心

**解决方案**：
- 升级到 ngrok 付费账户可获得固定域名
- 或者每次启动时告知其他用户新 URL

---

## 前后端通信

### ❌ 前端报错：`CORS error` 或 `Access to XMLHttpRequest has been blocked by CORS policy`

**原因**：后端 CORS 配置不允许前端域名

**解决**：
1. 检查 `.env` 文件中的 `ALLOW_ORIGINS` 配置：
   ```
   ALLOW_ORIGINS=["http://localhost:5173", "https://*.ngrok.io"]
   ```

2. 确保包含你使用的前端地址（本地或 ngrok URL）

3. 重启后端服务：
   ```bash
   cd backend
   uvicorn main:app --reload --port 8000
   ```

4. 清除浏览器缓存并重新加载页面

---

### ❌ 前端无法调用 API - 404 or 500 错误

**排查步骤**：

1. **检查后端是否运行**：
   在浏览器中访问 http://localhost:8000/docs
   - ✓ 出现 API 文档页面 → 后端正常运行
   - ✗ 无响应 → 后端未启动，运行后端命令

2. **检查 API 路由是否存在**：
   在 API 文档页面（/docs）中查找你要调用的端点

3. **检查请求 URL 是否正确**：
   - 本地：`http://localhost:8000/api/...`
   - ngrok：前端应该自动代理，检查 `frontend/vite.config.js`

4. **查看浏览器网络标签**：
   - F12 → Network 标签
   - 看被调用的 URL 和响应状态
   - 记录错误信息便于调试

---

### ❌ 前端可以访问但 API 返回空数据

**原因**：
- 后端数据库为空
- 数据查询逻辑问题

**解决**：
1. 检查 Neo4j 数据库是否已启动并有数据
2. 查看后端日志信息
3. 在 API 文档页面（/docs）中手动测试 API
4. 检查后端服务器的控制台输出

---

## 数据库相关

### ❌ 后端连接数据库失败

**原因**：Neo4j 数据库未启动或连接配置错误

**解决**：
1. 启动 Neo4j：
   ```bash
   start-neo4j.bat
   ```
   或者手动启动 Neo4j Desktop 应用

2. 验证 Neo4j 运行状态：
   - 访问 http://localhost:7474（Neo4j Web 界面）
   - 或检查 docker 容器（如果使用 Docker）：`docker ps | grep neo4j`

3. 检查连接配置 `backend/config.py`：
   ```python
   NEO4J_URI = "bolt://localhost:7687"
   NEO4J_USER = "neo4j"
   NEO4J_PASSWORD = "your-password"  # 确保密码正确
   ```

4. 重启后端服务

---

## 其他常见问题

### ❌ 浏览器显示白屏或加载失败

**解决步骤**：
1. 打开浏览器开发者工具：F12
2. 查看 Console 标签的错误信息
3. 查看 Network 标签，检查哪些请求返回错误
4. 根据具体信息查找本文档中对应的解决方案

### ❌ 某个 npm 包版本冲突

**解决**：
```bash
cd frontend
rm -r node_modules
rm package-lock.json
npm install
npm run dev
```

或者（Windows）：
```bash
cd frontend
del /s node_modules
del package-lock.json
npm install
npm run dev
```

---

## 调试技巧

### 1. 监控 ngrok 流量

打开浏览器访问 ngrok 监控页面：http://127.0.0.1:4040

可以看到：
- 所有通过 ngrok 的请求
- 请求头和响应内容
- 用于调试跨域和数据传输问题

### 2. 查看后端日志

后端终端会实时显示：
- 请求日志
- 错误堆栈跟踪
- 数据库查询等

仔细阅读这些日志可以快速定位问题。

### 3. 使用 API 文档测试后端

访问 http://localhost:8000/docs，可以：
- 查看所有可用的 API 端点
- 直接测试 API（无需前端）
- 查看请求参数和响应格式

### 4. 使用浏览器网络标签

F12 → Network 标签：
- 查看请求 URL、方法、状态码
- 查看请求头和响应体
- 模拟网络延迟、错误等

### 5. 检查 Neo4j 查询

如果怀疑数据库问题，访问 Neo4j Web 界面：http://localhost:7474
- 手动运行 Cypher 查询
- 检查数据是否正确存储

---

## 仍然无法解决？

1. **收集信息**：
   - 完整的错误信息
   - `python --version`、`npm --version`、`ngrok --version` 的输出
   - 后端和前端的完整日志

2. **查看官方文档**：
   - FastAPI CORS：https://fastapi.tiangolo.com/tutorial/cors/
   - Vite 配置：https://vite.dev/config/
   - ngrok 文档：https://ngrok.com/docs/
   - Neo4j 官网：https://neo4j.com/docs/

3. **社区资源**：
   - FastAPI 讨论：https://discuss.encode.io/
   - Vite 讨论：https://github.com/vitejs/vite/discussions
   - ngrok 支持：https://ngrok.com/contact

---

## 快速参考命令

```bash
# 检查环境
python --version
npm --version
ngrok version

# 清理和重新安装
cd backend && pip install -r requirements.txt
cd frontend && npm install

# 查找占用的端口（Windows）
netstat -ano | findstr :8000
netstat -ano | findstr :5173

# 关闭占用的进程（Windows）
taskkill /PID <PID> /F

# 重新启动 ngrok authtoken
ngrok authtoken <你的-token>

# 访问 API 文档
# 在浏览器中打开：http://localhost:8000/docs

# 访问 Neo4j Web 界面
# 在浏览器中打开：http://localhost:7474
```
