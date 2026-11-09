@echo off
rem ALB FOREX EMA Scalper - run all backtests automatically (double-click me)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_backtests.ps1" %*
echo.
pause
