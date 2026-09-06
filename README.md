# 翱翔课表（aoxiang-kebiao）

本项目为高校学子打造的现代化课程表与学期日程管理应用，支持翱翔教务系统网页一键嗅探导入及多种格式课表文件解析。采用 Flutter 跨平台框架构建，纯本地离线优先，全方位保护用户隐私。

## 1. 仓库总览

- `schedule-app/mobile_app/`：Flutter 移动端核心应用源码（Clean Architecture 架构）
- `.github/workflows/`：GitHub Actions 自动化多端构建流水线
- `LICENSE`：MIT 开源许可证

## 2. 应用发布信息

- **应用名称**：aoxiang 课表
- **包名**：`com.example.aoxiang_schedule`
- **当前版本**：`1.0.4`
- **支持系统**：Android 7.0+（API 24+） / iOS 12.0+
- **发布页面**：[GitHub Releases v1.0.4](https://github.com/Xio-Shark/aoxiang-kebiao/releases/tag/v1.0.4)
- **最新 APK 下载**：[aoxiang-kebiao-v1.0.4.apk](https://github.com/Xio-Shark/aoxiang-kebiao/releases/download/v1.0.4/aoxiang-kebiao-v1.0.4.apk)

### APK 校验信息

```text
文件名: aoxiang-kebiao-v1.0.4.apk
SHA256: 4ce40e825f5e3fa05cfb6f8215abaa0be49c4de11ad302ace7b8149e4d43839f
```

## 3. 安装与使用

### 3.1 安装方式

**Android 安装**：
- 下载 Release 中的 `.apk` 文件在手机本地直接安装（允许安装未知来源应用）。
- 或使用 ADB 调试安装：
  ```bash
  adb install -r aoxiang-kebiao-v1.0.4.apk
  ```

### 3.2 导入课表

**方式一：翱翔教务系统直接导入（推荐）**
1. 打开应用 -> 点击顶部栏「教务导入」或从「导入课表」进入。
2. 在内嵌浏览器中登录教务系统/统一身份认证，进入个人学期课表页面。
3. 点击底部悬浮按钮「一键导入当前页课表」，应用将自动嗅探解析课程、时间与地点并保存。

**方式二：本地文件导入**
1. 打开应用 -> 进入「导入课程」->「选择本地文件」。
2. 选择本地 `.docx`、`.xlsx`、`.ics` 或 `.json` 格式课表文件，系统将利用本地解析器自动解析入库。

## 4. 核心工程架构

```text
schedule-app/
└─ mobile_app/                    # 移动端源码
   ├─ lib/
   │  ├─ application/             # 状态管理与应用用例 (Riverpod)
   │  ├─ core/                    # 常量、主题调色盘、Result/Failure 抽象
   │  ├─ data/                    # 本地持久化与多源文件/教务解析器
   │  ├─ domain/                  # 核心领域实体 (Course, WeekPattern) 与仓储契约
   │  └─ presentation/            # 界面展示 (日程网格/课程详情/导入/设置)
   ├─ android/                    # Android 原生工程
   ├─ ios/                        # iOS 原生工程
   ├─ test/                       # 单元与解析测试用例
   ├─ pubspec.yaml                # 依赖管理
   └─ BUILD.md                    # 详细构建指南
```

## 5. 本地开发与构建

### 运行环境
- Flutter 3.x+ (Dart 3.x+)
- JDK 17
- Android SDK (API 34+)

### 运行与测试

```bash
cd schedule-app/mobile_app
flutter pub get
flutter run

# 运行自动化测试
flutter test
```

### 构建 APK

```bash
cd schedule-app/mobile_app
flutter build apk --release
```

## 6. 功能特性 (v1.0.4)

- **课表日历融合网格**：按星期与节次排列，自动感知当前公历日期与月份，高亮今日，支持一键「回到本周」。
- **智能重叠课程排版**：多门课程时段冲突时支持横向智能并列排版，杜绝卡片遮挡与信息遗漏。
- **流畅渲染架构**：剔除高开销背景滤镜，采用硬件加速渐变卡片设计，滑动与切换极其流畅。
- **全生命周期课程管理**：支持可视化新增、编辑、删除课程，随时随地灵活调课。
- **学期周次自定义**：支持精准设置开学首周日期，亦可一键「设本周为第1周」。
- **多源本地化导入**：教务网页一键嗅探导入、DOCX/XLSX/ICS/JSON 纯本地解析，数据不经任何第三方服务器。
- **离线沙盒存储**：离线优先，全量数据存放于设备本地沙盒，零隐私泄露风险。
- **云端自动化构建**：GitHub Actions 自动构建，支持推送 tag 自动触发多架构 APK 编译与 Release 发布。

## 7. 许可证

本项目遵循 MIT 开源许可证，详见 [LICENSE](./LICENSE)。
