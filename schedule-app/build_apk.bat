@echo off
chcp 65001 >nul
echo =========================================
echo   WakeUp课程表 - 构建脚本
echo =========================================
echo.

cd /d C:\Users\XioSh\Desktop\课表\schedule-app\mobile_app

echo [1/5] 检查Flutter...
flutter --version >nul 2>&1
if errorlevel 1 (
    echo 错误: Flutter未安装
    pause
    exit /b 1
)

echo [2/5] 获取依赖...
flutter pub get
if errorlevel 1 (
    echo 错误: 依赖获取失败
    pause
    exit /b 1
)

echo [3/5] 生成代码...
dart run build_runner build --delete-conflicting-outputs

echo [4/5] 构建APK...
flutter build apk --release

if errorlevel 1 (
    echo.
    echo =========================================
    echo   构建失败
    echo =========================================
) else (
    echo.
    echo =========================================
    echo   构建成功!
    echo =========================================
    echo APK位置: build\app\outputs\flutter-apk\app-release.apk
)

pause
