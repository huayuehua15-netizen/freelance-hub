@echo off
setlocal
cd /d "C:\dev\freelance_hub\mobile"

echo [1/2] Building debug APK...
call flutter build apk --debug
if errorlevel 1 (
  echo.
  echo BUILD FAILED. See errors above.
  pause
  exit /b 1
)

echo [2/2] Installing to phone (192.168.1.101:5555)...
"C:\Users\niu\AppData\Local\Android\Sdk\platform-tools\adb.exe" -s 192.168.1.101:5555 install -r "build\app\outputs\flutter-apk\app-debug.apk"
if errorlevel 1 (
  echo.
  echo INSTALL FAILED. Make sure WiFi ADB is on and the phone is reachable at 192.168.1.101:5555.
  pause
  exit /b 1
)

echo.
echo DONE. App updated on phone.
pause
endlocal
