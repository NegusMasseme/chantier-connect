@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Carnet ^& Chantier
set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
if not exist "%ADB%" set ADB=adb
echo Connexion a LDPlayer / telephone...
"%ADB%" connect 127.0.0.1:5555 > "%~dp0adb.log" 2>&1
"%ADB%" connect 127.0.0.1:5554 >> "%~dp0adb.log" 2>&1
"%ADB%" devices >> "%~dp0adb.log" 2>&1
call flutter devices > "%~dp0devices.log" 2>&1
echo Lancement de l'application (journal dans run.log)...
powershell -NoProfile -Command "flutter run 2>&1 | Tee-Object -FilePath '%~dp0run.log' -Encoding utf8"
pause
