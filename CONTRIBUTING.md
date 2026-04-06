# 开发指南

## 快速开始

详见 [QUICKSTART.md](QUICKSTART.md) 完整的环境设置步骤。

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

使用 Conventional Commits 格式：
```
<type>(<scope>): <subject>
```

类型：`feat` | `fix` | `refactor` | `docs` | `style` | `test` | `chore`

示例：
```
feat(map): 添加省级填色图缩放优化
fix(report): 修复消息框高度问题
docs(readme): 更新架构说明
```

---

## 开发规范

### 前端
- 使用 **Composition API** 编写 Vue 3 组件
- 业务逻辑提取到 `composables/` 中(
`use*` 函数)
- 遵循 Prettier 格式规范（自动检查）

### 后端
- 后端采用分层架构：Route → Service → Repository → Model
- 遵循 **PEP8** 规范（Black、isort 自动检查）
- 业务逻辑应在 `services/` 层处理
- 详见 [README.md](README.md) 的架构说明

---

## 提交工作流

### 1. 创建分支

```bash
git checkout -b feat/my-feature
```

分支名规范：`<type>/<description>`（feat/、fix/、docs/）

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

详见 [QUICKSTART.md](QUICKSTART.md#-验证服务运行正常) 的验证部分。

---

## 获得帮助

- 提问：在 GitHub Issues 中提问
- 反馈：通过 Pull Request 提交改进
- 讨论：参与 Discussions 板块

感谢你的贡献！🎉
