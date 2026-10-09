@echo off
setlocal
if not exist "%~dp0..\diagnostic-windows\Lancer-Commun.bat" goto missing_launcher
call "%~dp0..\diagnostic-windows\Lancer-Commun.bat" "..\stockage-windows\Stockage-Experimental.ps1"
exit /b %ERRORLEVEL%
:missing_launcher
echo ERREUR : diagnostic-windows\Lancer-Commun.bat absent. Extraire TOUT le ZIP du depot.
pause
exit /b 1
