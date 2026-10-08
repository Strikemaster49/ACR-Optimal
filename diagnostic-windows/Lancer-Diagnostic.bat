@echo off
setlocal
cd /d "%~dp0"
echo Lancez ACR puis relevez le PID de son processus dans le Gestionnaire des taches.
set /p "ACR_PID=PID du jeu : "
powershell.exe -NoProfile -Command "& './Diagnostic-ACR.ps1' -GameProcessId ([int]$env:ACR_PID)"
if errorlevel 1 echo Echec : consultez le message ci-dessus et les instructions README.fr.md.
pause
