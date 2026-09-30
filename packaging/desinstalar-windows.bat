@echo off
rem Atalho de desinstalação (Windows). Duplo clique.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\adr-std\bin\adr-std.ps1" self-uninstall
echo.
pause
