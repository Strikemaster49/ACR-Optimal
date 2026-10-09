@echo off
setlocal
if not exist "%~dp0..\diagnostic-windows\Lancer-Commun.bat" goto missing
call "%~dp0..\diagnostic-windows\Lancer-Commun.bat" "..\collecteur-windows\Collecteur-Experimental.ps1"
exit /b %ERRORLEVEL%
:missing
echo ERREUR : extraire tout le depot, diagnostic-windows absent.
pause
exit /b 1
