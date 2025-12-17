@echo off
echo Flutter App Launcher - Fire Alert System
echo =====================================

cd /d "e:\HeThongBaoChay\app"

echo Checking Flutter devices...
flutter devices

echo.
echo Choose platform:
echo 1. Android Emulator (if running)
echo 2. Chrome Web
echo 3. Exit

set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" (
    echo Launching on Android Emulator...
    flutter run -d emulator-5554 --hot
) else if "%choice%"=="2" (
    echo Launching on Chrome Web...
    flutter run -d chrome --web-port=8080 --hot
) else (
    echo Goodbye!
    exit /b
)

pause