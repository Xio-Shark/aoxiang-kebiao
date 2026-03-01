# aoxiang 课表（schedule-app）

本目录是翱翔课表的开发源码，包含：

- Flutter 移动端应用（`mobile_app`）
- Go 解析服务（`parsing_service`）

## 目录结构

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
└─ PROJECT_README.md          # 项目说明（详细）
```

## 开发环境

### Flutter 客户端

- Flutter 3.x
- Dart 3.x
- Android SDK（含 platform-tools）

### Go 解析服务

- Go 1.21+

## 快速开始

### 1. 运行 Flutter 客户端

```bash
cd mobile_app
flutter pub get
flutter run
```

### 2. 运行 Go 解析服务

```bash
cd parsing_service
go mod tidy
go run cmd/server/main.go
```

## 打包 APK（Windows）

在 `schedule-app` 目录执行：

```bat
build_apk.bat
```

或：

```powershell
.\build_apk.ps1
```

## 当前命名约定

- 应用标识：`aoxiang_schedule`
- Android 包名：`com.example.aoxiang_schedule`
- Go 模块：`github.com/aoxiang/schedule-parser`

## 许可证

本项目遵循 MIT License，见仓库根目录 `LICENSE`。
