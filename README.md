# 翱翔课表（aoxiang-kebiao）

本仓库包含翱翔课表的发布包与完整开发源码。

## 1. 仓库总览

- `apk_output/aoxiang-kebiao-v1.0.2.apk`：最终发布 APK
- `schedule-app/`：开发源码
  - `mobile_app/`：Flutter Android/iOS 客户端
  - `parsing_service/`：Go 课表解析服务
- `LICENSE`：MIT 开源许可证

## 2. 应用发布信息

- 应用名称：aoxiang 课表
- 包名：`com.example.aoxiang_schedule`
- 版本：`1.0.4`
- 最低系统：Android 7.0（API 24） / iOS 12.0
- 目标系统：Android 16（API 36）

### Release

- 页面：`https://github.com/Xio-Shark/aoxiang-kebiao/releases/tag/v1.0.4`
- Android APK：`https://github.com/Xio-Shark/aoxiang-kebiao/releases/download/v1.0.4/aoxiang-kebiao-v1.0.4.apk`
- iOS IPA：`https://github.com/Xio-Shark/aoxiang-kebiao/releases/download/v1.0.4/aoxiang-kebiao-v1.0.4-ios-unsigned.ipa`

### APK 校验

- 文件名：`aoxiang-kebiao-v1.0.2.apk`
- SHA256：

```text
ED823B2B3F382EC1C60E5444B8644348CDC16E96AB0457E62B48BAD9A64395DF
```

## 3. 安装与使用

### 3.1 安装

**Android 安装**：

```bash
adb install -r apk_output/aoxiang-kebiao-v1.0.2.apk
```

或在手机本地直接安装 APK（允许未知来源安装）。

**iOS 安装（支持未签名 IPA 侧载与巨魔商店）**：

- 本仓库已配置 GitHub Actions 自动构建未签名 iOS IPA。
- 巨魔商店（TrollStore）用户：直接下载 Release 中的 `aoxiang-kebiao-ios-unsigned.ipa` 即可安装。
- 普通 iOS 用户：可通过 AltStore / SideStore / 爱思助手等工具导入 IPA 进行 Apple ID 自签名安装。

### 3.2 导入课表

**方式一：教务系统直接导入（推荐）**

1. 打开应用 -> 点击顶部导航栏「教务导入」或进入「导入课表 -> 教务系统直接导入」
2. 在内嵌浏览器中登录翱翔教务 / 统一身份认证，导航至课表页面
3. 点击底部悬浮按钮「一键导入当前页课表」，系统将自动嗅探提取课表并入库

**方式二：文件导入**

1. 打开应用 -> `导入课程` -> `选择本地文件`
2. 在系统文件管理器选择 `.docx`、`.xlsx`、`.ics` 或 `.json` 文件完成导入

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

## 7. 功能特性 (v1.0.4)

- **课表日历融合网格**：按星期/节次排布，顶栏实时感知真实月份与日期，高亮今日「Today」，支持一键「回到本周」
- **智能重叠课程排版**：多门课程时段冲突时支持横向并列排版，杜绝完全遮挡
- **渲染性能提升**：剔除高开销 BackdropFilter，采用硬件加速渐变卡片设计，滑动顺滑流畅
- **全生命周期课程管理**：支持手动新增、编辑、删除课程，无需完全依赖解析脚本
- **学期与周次设置**：可自由调整开学第一周日期，或快捷「设本周为第1周」
- **多源数据导入**：支持翱翔教务系统直接导入嗅探、`.docx` / `.xlsx` / `.ics` / `.json` 文件本地导入
- **本地持久化存储**：离线优先，数据保存在手机本地沙盒
- **云端多端自动化构建**：GitHub Actions 自动构建发布 Android APK 与 iOS IPA

## 8. 维护约定

- 变更发布包时同步更新：Release 说明、APK 链接、SHA256
- 变更架构或流程时同步更新：
  - 根目录 `README.md`
  - `schedule-app/README.md`
  - `schedule-app/PROJECT_README.md`

## 9. 许可证

本项目遵循 MIT License，见 [LICENSE](./LICENSE)。
