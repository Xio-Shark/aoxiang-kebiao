# 翱翔课表（aoxiang-kebiao）

本仓库包含翱翔课表的发布包与完整开发源码。

## 1. 仓库总览

- `翱翔课表.apk`：本地发布 APK（根目录）
- `schedule-app/`：开发源码
  - `mobile_app/`：Flutter Android 客户端
  - `parsing_service/`：Go 课表解析服务
- `LICENSE`：MIT 开源许可证

## 2. 应用发布信息

- 应用名称：aoxiang 课表
- 包名：`com.example.aoxiang_schedule`
- 版本：`1.0.0`
- 最低系统：Android 7.0（API 24）
- 目标系统：Android 16（API 36）

### Release

- 页面：`https://github.com/Xio-Shark/aoxiang-kebiao/releases/tag/v1.0.0`
- APK：`https://github.com/Xio-Shark/aoxiang-kebiao/releases/download/v1.0.0/aoxiang-kebiao.apk`

### APK 校验

- 文件名：`aoxiang-kebiao.apk`
- SHA256：

```text
ED823B2B3F382EC1C60E5444B8644348CDC16E96AB0457E62B48BAD9A64395DF
```

## 3. 安装与使用

### 3.1 安装

```bash
adb install -r aoxiang-kebiao.apk
```

或在手机本地直接安装 APK（允许未知来源安装）。

### 3.2 导入课表

推荐流程：

1. 打开应用 -> `导入课程`
2. 点击 `选择文件并导入`
3. 在系统文件管理器选择 `.docx` 或 `.json`

说明：Android 13/14 上“按绝对路径导入 docx”可能因存储权限限制失败。

## 4. 开发源码说明（schedule-app）

### 4.1 目录结构

```text
schedule-app/
├─ mobile_app/                # Flutter 客户端
│  ├─ lib/                    # 业务代码
│  ├─ android/                # Android 工程
│  ├─ pubspec.yaml            # Flutter 依赖
│  └─ BUILD.md                # 移动端构建说明
├─ parsing_service/           # Go 解析服务
│  ├─ cmd/server/             # 服务入口
│  ├─ internal/               # 业务实现
│  ├─ go.mod                  # Go 依赖声明
│  └─ Dockerfile              # 容器构建文件
├─ build_apk.bat              # Windows 一键构建脚本
├─ build_apk.ps1              # PowerShell 构建脚本
├─ README.md                  # 源码目录说明
└─ PROJECT_README.md          # 项目详细说明
```

### 4.2 命名约定

- Flutter 应用标识：`aoxiang_schedule`
- Android 包名：`com.example.aoxiang_schedule`
- Go 模块：`github.com/aoxiang/schedule-parser`

## 5. 技术架构

### 5.1 客户端（Flutter）

分层结构：

- `core`：常量、错误模型、通用结果
- `domain`：实体与仓储接口
- `data`：数据源与仓储实现
- `application`：用例与状态注入
- `presentation`：页面与组件

### 5.2 解析服务（Go）

- `cmd/server`：HTTP 入口
- `internal/parser`：文档解析
- `internal/recognizer`：规则识别
- `internal/api`：接口处理
- `internal/model`：领域模型

## 6. 本地开发与联调

### 6.1 Flutter 客户端

```bash
cd schedule-app/mobile_app
flutter pub get
flutter run
```

### 6.2 Go 服务端

```bash
cd schedule-app/parsing_service
go mod tidy
go run cmd/server/main.go
```

### 6.3 Windows 打包 APK

```bat
cd schedule-app
build_apk.bat
```

## 7. 功能范围

- 课表网格展示（按星期/节次）
- `.docx` / `.json` 导入
- 导入后去重或覆盖
- 本地持久化存储
- Android APK 发布

## 8. 维护约定

- 变更发布包时同步更新：Release 说明、APK 链接、SHA256
- 变更架构或流程时同步更新：
  - 根目录 `README.md`
  - `schedule-app/README.md`
  - `schedule-app/PROJECT_README.md`

## 9. 许可证

本项目遵循 MIT License，见 [LICENSE](./LICENSE)。
