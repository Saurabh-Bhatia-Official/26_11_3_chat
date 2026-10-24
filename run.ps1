# ========================================================
# Next-Gen Chat Application: Activate & Run All Services
# ========================================================

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Next-Gen Chat: Activating & Running All Services" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Write-Host "[1/2] Launching Spring Boot Backend (Port 8085)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot\backend'; .\mvnw spring-boot:run"

Write-Host "[2/2] Launching Flutter Web Client in Chrome..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot\frontend'; flutter run -d chrome --dart-define-from-file=.env"

Write-Host "`nBoth services are active in separate terminals!" -ForegroundColor Green
Write-Host " - Backend API:  http://localhost:8085/api/auth/users" -ForegroundColor Green
Write-Host " - Frontend Web: Chrome will open automatically" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
