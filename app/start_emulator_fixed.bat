@echo off
echo Stopping existing emulator...
adb emu kill >nul 2>&1

echo Starting emulator with optimized settings...
cd /d "E:\AndroidAVD"
start "" "emulator\emulator.exe" -avd Pixel_6a_2 -gpu swiftshader_indirect -no-boot-anim -memory 4096 -skin 1080x2400 -no-snapshot-save

echo Waiting for emulator to boot...
timeout /t 30 /nobreak >nul

echo Checking emulator status...
adb devices

echo Emulator should be ready now!
pause