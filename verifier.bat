@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Chantier Connect - verification
echo Verification du code (analyse + tests)...
call flutter pub get > "%~dp0verif_pub.log" 2>&1
call flutter analyze > "%~dp0analyze.log" 2>&1
call flutter test > "%~dp0test.log" 2>&1
echo FIN > "%~dp0verif_fin.log"
echo Termine.
timeout /t 10
