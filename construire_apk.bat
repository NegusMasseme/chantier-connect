@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Chantier Connect - construction de l'APK
echo Construction de l'APK (quelques minutes la premiere fois)...
call flutter pub get > "%~dp0apk.log" 2>&1
call flutter build apk --release >> "%~dp0apk.log" 2>&1
if exist "build\app\outputs\flutter-apk\app-release.apk" (
  copy /y "build\app\outputs\flutter-apk\app-release.apk" "%~dp0ChantierConnect-test.apk" >nul
  echo TERMINE >> "%~dp0apk.log"
  echo APK pret : ChantierConnect-test.apk
) else (
  echo ECHEC >> "%~dp0apk.log"
  echo Echec - voir apk.log
)
timeout /t 15
