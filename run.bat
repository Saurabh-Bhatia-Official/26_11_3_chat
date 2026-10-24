@echo off
title Next-Gen Chat Launcher
echo ========================================================
echo   Next-Gen Chat: Activating ^& Running All Services
echo ========================================================

echo [1/2] Launching Spring Boot Backend on port 8085...
start "Chat Backend (Spring Boot :8085)" cmd /k "cd backend && mvnw.cmd spring-boot:run"

echo [2/2] Launching Flutter Web Client in Chrome...
start "Chat Frontend (Flutter Web)" cmd /k "cd frontend && flutter run -d chrome --dart-define-from-file=.env"

echo.
echo ========================================================
echo  Both services are now running in dedicated windows!
echo   - Backend URL:   http://localhost:8085/api/auth/users
echo   - Frontend:      Chrome will launch automatically
echo ========================================================
timeout /t 5
