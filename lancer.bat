@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Carnet ^& Chantier - lancement
set LOG=%~dp0lancement.log
echo ===== %date% %time% ===== > "%LOG%"

where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter est introuvable dans le PATH. >> "%LOG%"
  echo Flutter est introuvable dans le PATH.
  pause
  exit /b 1
)

if not exist android (
  echo [1/5] flutter create...
  call flutter create --platforms=android,ios --org com.carnetchantier --project-name carnet_chantier . >> "%LOG%" 2>&1
)

echo [2/5] flutter pub get...
echo ===== PUB GET ===== >> "%LOG%"
call flutter pub get >> "%LOG%" 2>&1

echo [3/5] flutter analyze...
call flutter analyze > "%~dp0analyze.log" 2>&1

echo [4/5] flutter test...
call flutter test > "%~dp0test.log" 2>&1

echo [5/5] Recherche d'un telephone ou emulateur Android...
call flutter devices > "%~dp0devices.log" 2>&1
findstr /i "android" "%~dp0devices.log" >nul
if errorlevel 1 (
  call flutter emulators > "%~dp0emulators.log" 2>&1
  set EMU=
  for /f "tokens=1" %%a in ('findstr /i /c:"android" "%~dp0emulators.log"') do if not defined EMU set EMU=%%a
  call :lancer_emu
)

echo Lancement de l'application (journal dans run.log)...
powershell -NoProfile -Command "flutter run 2>&1 | Tee-Object -FilePath '%~dp0run.log'"
pause
exit /b 0

:lancer_emu
if not defined EMU (
  echo Aucun emulateur Android trouve. Branchez un telephone en debogage USB. >> "%LOG%"
  echo Aucun emulateur Android trouve. Branchez un telephone en debogage USB.
  goto :eof
)
echo Demarrage de l'emulateur %EMU%... >> "%LOG%"
echo Demarrage de l'emulateur %EMU% (environ 1 minute)...
call flutter emulators --launch %EMU% >> "%LOG%" 2>&1
timeout /t 60 /nobreak >nul
goto :eof
