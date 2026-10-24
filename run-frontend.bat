@echo off
title Chat Frontend (Flutter Web)
cd /d "%~dp0frontend"
echo Starting Flutter Web Client...
flutter run -d chrome --dart-define-from-file=.env
pause
