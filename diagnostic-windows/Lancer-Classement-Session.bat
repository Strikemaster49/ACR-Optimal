@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -Command "& './Diagnostic-Classement-Session.ps1'"
if errorlevel 1 echo Consultez l'erreur ci-dessus et TEST-CLASSEMENT-SESSION.fr.md.
pause
