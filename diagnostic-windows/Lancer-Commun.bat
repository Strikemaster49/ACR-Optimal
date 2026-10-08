@echo off
setlocal
set "ACR_DIAG_SCRIPT=%~dp0%~1"
set "ACR_DIAG_MODE=%~2"
set "ACR_POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if "%~1"=="" goto missing_argument
if not exist "%ACR_DIAG_SCRIPT%" goto missing_script
if not exist "%ACR_POWERSHELL%" goto missing_powershell
echo.
echo Ce diagnostic lance un script PowerShell de ce dossier.
echo Avec votre accord, ExecutionPolicy Bypass sera utilise UNIQUEMENT
echo pour le processus PowerShell lance, jusqu'a sa fermeture.
echo Aucune politique permanente Windows ne sera modifiee.
echo Les politiques imposees par votre administrateur restent prioritaires.
echo Aucun droit administrateur ne sera demande par ce lanceur.
echo N'acceptez que si vous avez verifie la provenance des fichiers.
echo Script : "%ACR_DIAG_SCRIPT%"
choice /C ON /N /M "Autoriser ce lancement temporaire ? [O/N] : "
if errorlevel 2 goto declined
if errorlevel 1 goto approved
goto declined
:approved
if /I "%ACR_DIAG_MODE%"=="PID" (
    set "ACR_DIAG_PID="
    echo Lancez ACR puis relevez son PID dans Gestionnaire des taches, Details.
    set /p "ACR_DIAG_PID=PID du jeu : "
)
"%ACR_POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $policies=Get-ExecutionPolicy -List; $managed=@($policies | Where-Object { ($_.Scope -eq 'MachinePolicy' -or $_.Scope -eq 'UserPolicy') -and $_.ExecutionPolicy -ne 'Undefined' }); if ($managed.Count) { Write-Host 'Une politique administrateur est active et reste prioritaire.'; $managed | Format-Table -AutoSize | Out-Host }; $arguments=@{}; if ($env:ACR_DIAG_MODE -eq 'PID') { $gameId=0; if (-not [int]::TryParse($env:ACR_DIAG_PID,[ref]$gameId) -or $gameId -le 0) { throw 'PID invalide : saisir un entier positif.' }; $arguments.GameProcessId=$gameId }; if (-not (Test-Path -LiteralPath $env:ACR_DIAG_SCRIPT -PathType Leaf)) { throw 'Script introuvable.' }; & $env:ACR_DIAG_SCRIPT @arguments; exit 0 } catch { Write-Host ''; Write-Host 'ECHEC DU DIAGNOSTIC' -ForegroundColor Red; Write-Host $_.Exception.Message; if ($_.Exception -is [System.Management.Automation.PSSecurityException] -or $_.CategoryInfo.Category -eq 'SecurityError' -or $_.FullyQualifiedErrorId -match 'PSSecurityException|UnauthorizedAccess') { Write-Host 'Une politique de securite ou un controle applicatif peut interdire ce script.'; Write-Host 'Le consentement ne permet pas de passer outre une politique administrateur.'; Write-Host 'Contactez votre administrateur pour une autorisation ou une version signee.'; Write-Host 'Ne changez pas la politique permanente et ne relancez pas en administrateur pour contourner ce blocage.'; try { Get-ExecutionPolicy -List | Format-Table -AutoSize | Out-Host } catch {} }; exit 1 }"
set "ACR_EXIT_CODE=%ERRORLEVEL%"
if not "%ACR_EXIT_CODE%"=="0" (
    echo.
    echo PowerShell a echoue avec le code %ACR_EXIT_CODE%.
    echo Si PowerShell ne demarre pas ou est bloque par votre organisation,
    echo demandez une autorisation a l'administrateur. Ce lanceur ne contourne pas ce blocage.
)
echo.
pause
exit /b %ACR_EXIT_CODE%
:declined
echo Lancement annule. Aucun script PowerShell n'a ete execute.
pause
exit /b 2
:missing_argument
echo ERREUR : utilisez un des fichiers Lancer-*.bat, pas Lancer-Commun.bat directement.
pause
exit /b 1
:missing_script
echo ERREUR : fichier requis absent : "%ACR_DIAG_SCRIPT%"
echo Extrayez tous les fichiers du ZIP dans le meme dossier.
pause
exit /b 1
:missing_powershell
echo ERREUR : Windows PowerShell est absent ou inaccessible : "%ACR_POWERSHELL%"
echo Si votre organisation le bloque, contactez votre administrateur.
pause
exit /b 1
