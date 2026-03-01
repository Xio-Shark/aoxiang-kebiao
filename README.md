# 翱翔课表（aoxiang-kebiao）

Android 课表应用发布仓库，提供 APK 下载、导入说明和源码目录。

## 仓库内容

- `翱翔课表.apk`：本地发布包（仓库根目录）
- `schedule-app/`：Flutter + Go 开发源码
- `LICENSE`：MIT 开源许可证

## 应用信息

- 应用名称：aoxiang 课表
- 包名：`com.example.aoxiang_schedule`
- 版本：`1.0.0`
- 最低系统：Android 7.0（API 24）
- 目标系统：Android 16（API 36）

## 发布下载

- Release 页面：
  `https://github.com/Xio-Shark/aoxiang-kebiao/releases/tag/v1.0.0`
- APK 直链：
  `https://github.com/Xio-Shark/aoxiang-kebiao/releases/download/v1.0.0/aoxiang-kebiao.apk`

## APK 校验

- 文件名：`aoxiang-kebiao.apk`
- SHA256：

```text
ED823B2B3F382EC1C60E5444B8644348CDC16E96AB0457E62B48BAD9A64395DF
```

## 安装

### 方式一：手机本地安装

1. 下载 `aoxiang-kebiao.apk`。
2. 允许“未知来源应用安装”。
3. 安装并启动。

### 方式二：ADB 安装

```bash
adb install -r aoxiang-kebiao.apk
```

## 课表导入

推荐使用系统文件选择器导入：

1. 打开应用，进入 `导入课程`。
2. 点击 `选择文件并导入`。
3. 在系统文件管理器中选择 `.docx` 或 `.json` 文件。

说明：Android 13/14 上“按路径导入 docx”可能因存储权限限制失败。

## 开源许可证

本项目使用 MIT License，见 [LICENSE](./LICENSE)。

## 更新记录

- 2026-03-01：命名统一为 `aoxiang`
- 2026-03-01：新增 MIT 许可证
- 2026-03-01：发布 `v1.0.0`，上传 `aoxiang-kebiao.apk`
