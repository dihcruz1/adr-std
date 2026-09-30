@echo off
rem Atalho de instalação (Windows). Duplo clique.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause
