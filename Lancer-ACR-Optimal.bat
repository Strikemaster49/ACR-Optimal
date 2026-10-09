@echo off
setlocal
if not exist "%~dp0diagnostic-windows\Lancer-Commun.bat" goto missing
call "%~dp0diagnostic-windows\Lancer-Commun.bat" "..\interface-windows\Interface.ps1"
exit /b %ERRORLEVEL%
:missing
echo ERREUR : extraire tout le depot ACR-Optimal.
pause
exit /b 1
