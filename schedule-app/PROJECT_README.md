# 项目说明（PROJECT_README）

## 1. 项目目标

将课表信息整理为可视化周课表，支持导入、解析、展示与基础管理。

## 2. 功能范围

- 课表网格展示（按星期/节次）
- `.docx` / `.json` 数据导入
- 导入后课程去重或覆盖
- 本地持久化存储
- Android APK 发布

## 3. 技术架构

### 3.1 客户端（Flutter）

采用分层设计：

- `core`：常量、错误模型、通用结果类型
- `domain`：实体与仓储接口
- `data`：数据源与仓储实现
- `application`：用例与状态注入
- `presentation`：页面与组件

### 3.2 解析服务（Go）

- `cmd/server`：HTTP 服务入口
- `internal/parser`：文档解析逻辑
- `internal/recognizer`：课表规则识别
- `internal/api`：接口处理层
- `internal/model`：领域模型

## 4. 运行与联调

### 4.1 客户端

```bash
cd mobile_app
flutter pub get
flutter run
```

### 4.2 服务端

```bash
cd parsing_service
go mod tidy
go run cmd/server/main.go
```

## 5. 构建发布

### 5.1 本地构建 APK

```bat
build_apk.bat
```

### 5.2 GitHub 发布

- 仓库：`Xio-Shark/aoxiang-kebiao`
- Release 标签：`v1.0.1`
- 发布资产：`aoxiang-kebiao-v1.0.1.apk`

## 6. 已知注意事项

- Android 13/14 设备上，按绝对路径导入文件可能受存储权限限制。
- 推荐使用系统文件选择器导入 `.docx` / `.json`。

## 7. 维护约定

- 新增功能优先补充 `README.md` 与本文件。
- 变更发布包时同步更新 Release 说明和 SHA256。
