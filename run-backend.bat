@echo off
title Chat Backend (Spring Boot)
cd /d "%~dp0backend"
echo Starting Spring Boot Backend on port 8085 using project-local JDK...
call mvnw.cmd spring-boot:run
pause
