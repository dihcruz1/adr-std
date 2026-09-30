@echo off
rem Atalho do comando adr-std no Windows: chama o script PowerShell.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0adr-std.ps1" %*
exit /b %ERRORLEVEL%
