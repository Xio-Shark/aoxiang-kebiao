@echo off
chcp 65001 >nul
echo =========================================
echo   aoxiang璇剧▼琛?- 鏋勫缓鑴氭湰
echo =========================================
echo.

cd /d C:\Users\XioSh\Desktop\璇捐〃\schedule-app\mobile_app

echo [1/5] 妫€鏌lutter...
flutter --version >nul 2>&1
if errorlevel 1 (
    echo 閿欒: Flutter鏈畨瑁?    pause
    exit /b 1
)

echo [2/5] 鑾峰彇渚濊禆...
flutter pub get
if errorlevel 1 (
    echo 閿欒: 渚濊禆鑾峰彇澶辫触
    pause
    exit /b 1
)

echo [3/5] 鐢熸垚浠ｇ爜...
dart run build_runner build --delete-conflicting-outputs

echo [4/5] 鏋勫缓APK...
flutter build apk --release

if errorlevel 1 (
    echo.
    echo =========================================
    echo   鏋勫缓澶辫触
    echo =========================================
) else (
    echo.
    echo =========================================
    echo   鏋勫缓鎴愬姛!
    echo =========================================
    echo APK浣嶇疆: build\app\outputs\flutter-apk\app-release.apk
)

pause


