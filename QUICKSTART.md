# ⚡ 快速参考指南

**5 分钟快速上手水生入侵生物平台**

---

## 🚀 启动应用（选择一种方式）

### 方式一：一键启动（推荐）

**Windows:**
```bash
start.bat
```

等待输出显示：
```
📱 前端地址：http://localhost:5173
🔌 后端 API：http://localhost:8000
```

### 方式二：手动启动

**终端 1 - 启动后端：**
```bash
cd backend
pip install -r requirements.txt
# 后端自动加载 api/router.py 中定义的所有路由
# 路由按业务领域分解在 api/routes/ 目录
uvicorn main:app --reload --port 8000
```

后端路由组织已拆分为：
- `api/routes/species.py` → `/api/species`、`/api/locations` 等
- `api/routes/analytics.py` → `/api/heatmap`、`/api/province-data` 等
- `api/routes/geo.py` → `/api/geocode`、`/api/reverse-geocode` 等
- `api/routes/qa.py` → `/api/qa`、`/api/qa/suggestions` 等
- `api/routes/records.py` → `/api/record/location`、`/api/records` 等
- `api/routes/admin.py` → `/api/admin/cache/invalidate` 等
- `api/routes/system.py` → `/api/health` 等

详见 [后端架构说明](./README.md#后端架构分层设计)

**终端 2 - 启动前端：**
```bash
cd frontend
npm install
npm run dev
```

---

## 🌍 功能快速导航

### 📍 Tab 1: 分布识别分析

**用途：** 在地图上查看物种的分布位置

**步骤：**
1. 点击第一个 Tab "🌍 分布识别分析"
2. 在左侧下拉菜单选择物种
3. 地图自动显示该物种的所有分布点
4. 查看统计信息："已记录点位"

**高级功能：**
- 切换底图：OpenStreetMap、ESRI、高德卫星等
- 切换图层：散点图、热力图、省级填色图、MaxEnt 预测

**支持物种：** 豹纹翼甲鲶、大鳄龟、鳄雀鳝、非洲大蜗牛、福寿螺、红耳彩龟、美洲牛蛙、齐氏罗非鱼

---

### 🤖 Tab 2: 智能知识问答

**用途：** 与 AI 助手交流，了解物种信息

**步骤：**
1. 点击第二个 Tab "🤖 智能知识问答"
2. 在右侧选择一个物种（快速提问）
3. 在底部输入框输入问题
4. 按 Enter 或点击"发送"
5. 等待 AI 回答

**预设建议问题：**
- "介绍一下 [物种]"
- "[物种] 的危害是什么？"
- "如何防治 [物种]？"
- "[物种] 属于什么分类？"
- "[物种] 的原产地在哪？"

**快捷操作：**
- 💡 点击建议问题快速提问
- 🔄 点击"清空对话"开始新对话

---

### 📝 Tab 3: 数据上报与更新

**用途：** 上报发现的物种位置

**步骤：**
1. 点击第三个 Tab "📝 数据上报与更新"
2. **左侧表单填写：**
   - 物种名称（必选）- 从下拉菜单选择
   - 详细地名（必选） - 例如"杭州西湖"
   - 经度（必选） - 范围 中国境内
   - 纬度（必选） - 范围 中国境内
   - 发现日期（可选） - 默认为今天

3. 点击"💾 保存记录"
4. 看到"✅ 记录保存成功！"提示
5. 下方表格会显示新记录

**获取坐标的方式：**
- 打开 Google Maps 或高德地图
- 右键点击位置 → 复制坐标
- 粘贴到表单中

**或者：直接点击地图打点**
- 在右侧地图上直接点击位置
- 系统自动填入坐标和地名

**示例数据：**
```
物种: 福寿螺
地名: 杭州西湖
纬度: 30.2741
经度: 120.1551
日期: 2024-04-01
```

---

## 📱 访问应用

| 功能 | 网址 |
|------|------|
| 前端应用 | http://localhost:5173 |
| 后端 API | http://localhost:8000 |
| 自动化文档 | http://localhost:8000/docs |

---

## 🔧 API 使用示例

### 可直接在浏览器中测试的端点

**获取物种列表：**
```
http://localhost:8000/api/species
```

**获取物种分布位置：**
```
http://localhost:8000/api/locations/福寿螺
```

**获取所有上报记录：**
```
http://localhost:8000/api/records
```

### POST 端点使用方法

对于 POST 请求（如提交问题、上报新发现），有以下几种方式：

#### 方式 1：使用 Swagger UI（最简单，推荐）✨

1. 打开：http://localhost:8000/docs
2. 找到对应的 POST 端点（如 `/api/qa`）
3. 点击 "Try it out" 按钮
4. 填入参数和请求体
5. 点击 "Execute" 看到响应结果

#### 方式 2：使用 curl 命令

**提交问题：**
```powershell
curl -X POST http://localhost:8000/api/qa `
  -H "Content-Type: application/json" `
  -d '{\"question\": \"福寿螺有什么危害？\"}'
```

**上报新发现：**
```powershell
curl -X POST http://localhost:8000/api/record/location `
  -H "Content-Type: application/json" `
  -d '{
    \"species\": \"福寿螺\",
    \"latitude\": 30.27,
    \"longitude\": 120.15,
    \"location_name\": \"杭州西湖\",
    \"date\": \"2024-04-01\"
  }'
```

#### 方式 3：使用 Postman 等 API 工具

1. 下载 [Postman](https://www.postman.com/)
2. 新建 POST 请求，填入 URL
3. Body → raw → JSON
4. 输入参数并发送

#### 方式 4：直接在网页应用中使用

你在网页上的聊天、数据上报功能就通过这些 POST 端点实现的。应用已经在使用这些接口。

---

## 📊 数据位置

| 数据元素 | 位置 |
|---------|------|
| 物种分布数据 | `backend/data/gbif_results/*.csv` |
| 用户上报数据 | SQLite: `backend/data/species.db` |
| 物种信息 | `backend/data/animals/` |
| 预测模型结果 | `backend/data/maxent_results/` |

---

## ❌ 常见问题排查

| 问题 | 解决方案 |
|------|---------|
| 地图不显示 | 检查后端是否运行，物种是否正确加载 |
| API 无法连接 | 确保后端在 http://localhost:8000 |
| AI 问答失败 | 检查 API Key 配置，网络连接 |
| npm install 失败 | 删除 `node_modules` 和 `package-lock.json` 后重试 |
| Python 依赖缺失 | 运行 `pip install -r requirements.txt` |

---

## 🛑 停止应用

**Windows:** 直接关闭两个启动的窗口/在启动脚本所在终端按 `Ctrl+C`，然后根据提示按y

---

## 📚 更多信息

详见项目文档：
- **README.md** - 项目概述和部署指南

---