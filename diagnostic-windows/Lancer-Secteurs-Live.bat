@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -Command "& './Diagnostic-Secteurs-Live.ps1'"
if errorlevel 1 echo Consultez l'erreur et TEST-SECTEURS-LIVE.fr.md.
pause
