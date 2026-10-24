@echo off
title ChatGuard Windows Installer Builder
echo ========================================================
echo   Building ChatGuard Windows Setup Wizard (.exe)
echo ========================================================
powershell -ExecutionPolicy Bypass -File "%~dp0build-windows-installer.ps1"
pause
