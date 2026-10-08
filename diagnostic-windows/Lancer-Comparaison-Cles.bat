@echo off
setlocal
if not exist "%~dp0Lancer-Commun.bat" goto missing_launcher
call "%~dp0Lancer-Commun.bat" "Comparer-Cles-Tentatives.ps1"
exit /b %ERRORLEVEL%
:missing_launcher
echo ERREUR : Lancer-Commun.bat absent. Extrayez tous les fichiers du ZIP.
pause
exit /b 1
