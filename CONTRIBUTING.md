# 开发指南 (Contributing)

感谢你对水生入侵生物平台的贡献！本文档将帮助你快速上手开发。

---

## 开发环境设置

### 前置要求

- Python 3.8+
- Node.js 16+
- Git

### 步骤 1：克隆仓库

```bash
git clone https://github.com/gwj2003/BlueGuard.git
cd BlueGuard
```

### 步骤 2：安装后端依赖

```bash
cd backend
pip install -r requirements.txt
pip install -e .  # 如果有 setup.py
```

### 步骤 3：安装前端依赖

```bash
cd ../frontend
npm install
```

---

## 代码规范

### 统一代码格式（Pre-commit Hooks）

我们使用 **pre-commit** 自动化代码检查，确保代码质量。

#### 安装 Pre-commit

```bash
pip install pre-commit
```

#### 初始化钩子

在项目根目录运行：

```bash
pre-commit install
```

这将在 `.git/hooks/` 中安装钩子脚本，**每次提交代码时自动执行**。

#### 手动运行（可选）

检查所有文件：
```bash
pre-commit run --all-files
```

检查某个文件：
```bash
pre-commit run --files <file_path>
```

跳过钩子提交（不推荐）：
```bash
git commit --no-verify
```

### 检查内容

Pre-commit 会自动检查和修复以下问题：

#### Python

| 工具 | 用途 | 自动修复? |
|------|------|---------|
| **Black** | 代码格式化 | ✅ 是 |
| **isort** | 导入排序 | ✅ 是 |
| **flake8** | PEP8 检查、质量检查 | ❌ 否（警告） |

#### JavaScript/Vue

| 工具 | 用途 | 自动修复? |
|------|------|---------|
| **Prettier** | 代码格式化 | ✅ 是 |

#### 通用

| 检查项 | 用途 |
|-------|------|
| 尾部空格 | 删除行末空白 |
| 文件末尾缺失换行符 | 自动添加 |
| JSON/YAML 语法 | 验证 |
| 大文件（>1MB） | 警告 |
| 合并冲突标记 | 检查 |

#### 提交信息

| 工具 | 用途 |
|------|------|
| **commitizen** | 按照 Conventional Commits 规范检查提交信息 |

**提交信息格式：**
```
<type>(<scope>): <subject>

<body>

<footer>
```

示例：
```
feat(map): 添加省级填色图缩放优化

- 将省级图层缩放改为固定中国范围
- 新增 CHINA_BOUNDS 常量
- 确保视角一致性

Closes #123
```

**可用的 type:**
- `feat` - 新功能
- `fix` - 修复 bug
- `refactor` - 代码重构
- `style` - 样式/格式修改（不改逻辑）
- `docs` - 文档修改
- `test` - 测试用例
- `chore` - 依赖更新、工具配置等

---

## 前端开发指南

### 项目结构

```
frontend/src/
├── components/          # 功能组件
│   ├── chat/
│   ├── report/
│   └── species/
├── composables/         # 业务逻辑（组合函数）
├── api/                 # API 通信
├── views/               # 页面视图
├── utils/               # 工具函数
└── assets/              # 静态资源
```

### 运行开发服务器

```bash
cd frontend
npm run dev
```

访问 http://localhost:5173

### 编码规范

- 使用 **Composition API** 编写 Vue 组件
- 业务逻辑提取到 `composables/` 中的 `use*` 函数
- 组件只负责 UI 渲染和交互
- 使用 `const` 而非 `let` 或 `var`
- 事件处理器前缀统一为 `handle` 或 `on`

### 示例组件结构

```vue
<script setup>
import { ref, computed } from 'vue'
import { useMyLogic } from '@/composables/useMyLogic'

const props = defineProps({
  title: String,
})

const emit = defineEmits(['update:value'])

const { data, loading, fetch } = useMyLogic()
</script>

<template>
  <div class="my-component">
    <!-- 内容 -->
  </div>
</template>

<style scoped>
/* 组件样式 */
</style>
```

---

## 后端开发指南

### 项目结构（分层架构）

```
backend/
├── api/
│   ├── router.py       # 路由汇聚器
│   ├── errors.py       # 异常处理
│   └── routes/         # 按业务分解
├── services/           # 业务逻辑层
├── repositories/       # 数据访问层
├── models/             # ORM 模型定义
└── schemas/            # 请求/响应模式
```

### 添加新的 API 端点

假设要添加 `/api/my-feature` 端点：

#### 1. 创建路由文件 `backend/api/routes/my_feature.py`

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
from services.my_feature import my_service

router = APIRouter(prefix="/api", tags=["my-feature"])

@router.get("/my-feature")
def get_my_feature(db: Session = Depends(get_db)):
    return my_service.fetch_data(db)
```

#### 2. 创建服务文件 `backend/services/my_feature.py`

```python
from fastapi import HTTPException
from sqlalchemy.orm import Session

from repositories.my_feature_repo import MyFeatureRepo

class MyFeatureService:
    @staticmethod
    def fetch_data(db: Session):
        try:
            data = MyFeatureRepo.query_all(db)
            return {"data": data}
        except Exception as exc:
            raise HTTPException(status_code=500, detail=str(exc))

my_service = MyFeatureService()
```

#### 3. 在 `backend/api/router.py` 中注册

```python
from api.routes.my_feature import router as my_feature_router

api_router.include_router(my_feature_router)
```

### 编码规范

- 遵循 **PEP8** 规范（通过 Black 和 isort 自动检查）
- 使用类型提示（Type Hints）
- 函数应有文档字符串
- 异常统一使用 `HTTPException`
- 避免直接在路由层写业务逻辑，应提取到 `services/`

### 运行开发服务器

```bash
cd backend
uvicorn main:app --reload --port 8000
```

访问 http://localhost:8000/docs 查看 OpenAPI 文档

---

## 提交工作流

### 1. 创建分支

```bash
git checkout -b feat/my-feature
```

分支名规范：`<type>/<description>`
- `feat/` - 新功能
- `fix/` - 修复
- `docs/` - 文档

### 2. 进行开发

编写代码后，pre-commit 钩子会自动检查并修复格式问题。

### 3. 提交代码

```bash
git add .
git commit -m "feat(map): 添加新的地图图层"
```

如果提交信息不符合规范，钩子会拒绝提交。

### 4. 推送并发起 PR

```bash
git push origin feat/my-feature
```

在 GitHub 上发起 Pull Request，等待 code review。

---

## 常见问题

### Q: Pre-commit 检查失败怎么办？

**A:** 大多数工具会自动修复问题（Black、isort、Prettier 等）。

- 查看哪些文件被修改
- 重新 `git add .` 并提交
- 如果仍有问题，按照错误信息修改代码

### Q: 特定文件不想使用某个检查？

**A:** 在 `.pre-commit-config.yaml` 中排除文件或修改规则。

### Q: 如何更新 pre-commit 钩子？

**A:**
```bash
pre-commit autoupdate
git add .pre-commit-config.yaml
git commit -m "chore: update pre-commit hooks"
```

---

## 测试

### 运行测试

```bash
# 后端
cd backend
pytest

# 前端（如果有测试）
cd frontend
npm test
```

详见 `TESTING.md`。

---

## 获得帮助

- 提问：在 GitHub Issues 中提问
- 反馈：通过 Pull Request 提交改进
- 讨论：参与 Discussions 板块

感谢你的贡献！🎉
