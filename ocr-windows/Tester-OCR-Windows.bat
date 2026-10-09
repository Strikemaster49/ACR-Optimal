@echo off
setlocal
if not exist "%~dp0..\diagnostic-windows\Lancer-Commun.bat" goto missing
if not exist "%~dp0..\tests\verify_windows_title_ocr.ps1" goto missing
call "%~dp0..\diagnostic-windows\Lancer-Commun.bat" "..\ocr-windows\Tester-OCR-Windows.ps1"
exit /b %ERRORLEVEL%
:missing
echo ERREUR : extraire tout le depot pour obtenir le test Windows.
pause
exit /b 1
