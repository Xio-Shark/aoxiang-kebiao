# 翱翔课表（schedule-app）

本目录是翱翔课表（aoxiang-kebiao）的核心应用源码。

当前版本：`v1.0.4`

## 1. 目录结构

```text
schedule-app/
└─ mobile_app/                # Flutter 客户端核心工程
   ├─ lib/                    # 业务源码（Clean Architecture 架构）
   │  ├─ application/         # 状态管理与用例
   │  ├─ core/                # 常量、主题与工具
   │  ├─ data/                # 数据源（本地解析/持久化/教务适配）
   │  ├─ domain/              # 领域模型与实体
   │  └─ presentation/        # UI 页面与组件
   ├─ android/                # Android 原生配置与构建文件
   ├─ ios/                    # iOS 原生配置
   ├─ test/                   # 自动化单元测试
   ├─ pubspec.yaml            # 依赖配置
   └─ BUILD.md                # 构建与打包指引
```

## 2. 核心架构与设计

移动端采用 Clean Architecture 纯本地离线优先架构：

- **数据源自主解析**：内置 DOCX（XML解压提取）、XLSX、ICS、JSON 纯本地解析引擎，无需服务端转发，保障速度与隐私安全。
- **翱翔教务直接导入**：集成内嵌 WebView，支持直接登录翱翔门户并一键嗅探提取课表入库。
- **分层解耦**：
  - `domain`：核心实体（Course、WeekPattern 等）及接口定义。
  - `data`：本地 SharedPreferences 持久化、文件解析与适配器。
  - `application`：Riverpod 状态管理。
  - `presentation`：课表日历融合网格、智能课程重叠并列渲染、个性化设置与课程管理。

## 3. 快速开始

```bash
cd mobile_app
flutter pub get
flutter run
```

## 4. 自动化测试

```bash
cd mobile_app
flutter test
```

## 5. 打包构建

详细打包说明参见 [mobile_app/BUILD.md](./mobile_app/BUILD.md)。

- **Android APK**：`flutter build apk --release`
- **CI/CD**：推送版本标签（`v*`）时，GitHub Actions 自动构建并在 Releases 发布 APK。

## 6. 许可证

本项目遵循 MIT License，详见根目录 [LICENSE](../LICENSE)。
