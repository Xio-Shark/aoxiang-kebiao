# 课程表应用 - WakeUp Schedule

基于 Flutter Clean Architecture + Go 解析服务的课程表应用。

## 项目结构

```
schedule-app/
├── mobile_app/          # Flutter 移动端
│   ├── lib/
│   │   ├── core/        # 核心模块（错误处理、结果类型、常量）
│   │   ├── domain/      # 领域层（实体、Repository接口）
│   │   ├── data/        # 数据层（Models、本地存储）
│   │   ├── application/ # 应用层（UseCases、Providers）
│   │   └── presentation/# 表现层（页面、组件、ViewModels）
│   ├── test/            # 单元测试
│   └── integration_test/# 集成测试
│
└── parsing_service/     # Go 解析微服务
    ├── internal/        # 内部实现
    │   ├── parser/      # DOCX解析
    │   ├── recognizer/  # 文本识别
    │   ├── api/         # HTTP API
    │   └── model/       # 数据模型
    ├── pkg/             # 公共包
    └── cmd/             # 入口点
```

## 技术栈

### 移动端 (Flutter)
- **状态管理**: Riverpod 2.x
- **架构模式**: Clean Architecture
- **不可变数据**: Freezed
- **本地存储**: SharedPreferences
- **网络请求**: Dio / HTTP

### 后端 (Go)
- **DOCX解析**: unioffice/v2
- **HTTP框架**: Gin
- **日志**: Logrus
- **配置**: YAML

## 快速开始

### Flutter 移动端

```bash
cd mobile_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Go 解析服务

```bash
cd parsing_service
go mod tidy
go run cmd/server/main.go
```

## 功能特性

- ✅ 课程表展示（按周次、星期、节次）
- ✅ 单双周课程显示
- ✅ 从Word文档导入课程表
- ✅ 周次自动计算
- ✅ 课程详情查看与编辑
- ✅ 学期设置

## 代码规范

- 遵循 Clean Architecture 分层原则
- Presentation层不直接访问Data层
- Repository通过接口调用
- Domain层不依赖Flutter框架

## 许可证

MIT
