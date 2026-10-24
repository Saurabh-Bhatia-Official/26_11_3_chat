@echo off
title Whisper Windows Installer Builder
echo ========================================================
echo   Building Whisper Windows Setup Wizard (.exe)
echo ========================================================
powershell -ExecutionPolicy Bypass -File "%~dp0build-windows-installer.ps1"
pause
