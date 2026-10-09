[CmdletBinding()]
param(
    [ValidateSet('Menu','Import','Rapport','ExporterRevue','AppliquerRevue')][string]$Action='Menu',
    [string]$ExportFolder,
    [string]$ReviewPath,
    [string]$Profile='joueur-local',
    [string]$DatabasePath=(Join-Path $env:LOCALAPPDATA 'ACR-Optimal\Experimental\acr-experimental.sqlite3'),
    [string]$ReportRoot=(Join-Path $env:LOCALAPPDATA 'ACR-Optimal\Experimental\Rapports')
)
$ErrorActionPreference='Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Windows 10/11 requis pour ce lanceur.' }
if (-not [Environment]::Is64BitProcess) { throw 'Utiliser Windows PowerShell 64 bits pour cette version x64.' }
foreach ($file in @('Stockage.psm1','SqliteNative.cs','schema.sql')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)) { throw "Fichier requis absent : $file. Extraire tout le ZIP." }
}
if ($Profile -notmatch '^[\p{L}\p{N} _.\-]{1,64}$') { throw 'Nom de profil invalide.' }
Import-Module (Join-Path $PSScriptRoot 'Stockage.psm1') -Force
Write-Host "Base EXPERIMENTALE : $DatabasePath"
Write-Host "Profil : $Profile. Ne pas melanger plusieurs joueurs sous le meme profil."
Write-Host 'Aucune acquisition automatique. Les exports inconnus restent en quarantaine.'
if ($Action -eq 'Menu') {
    Write-Host '1 = Importer les secteurs.csv ; 2 = Rapport ; 3 = Creer une revue ; 4 = Appliquer une revue ; 0 = Quitter'
    switch (Read-Host 'Choix') {
        '1' {$Action='Import'} '2' {$Action='Rapport'} '3' {$Action='ExporterRevue'} '4' {$Action='AppliquerRevue'}
        '0' {return} default {throw 'Choix incorrect.'}
    }
}
$db=Open-AcrDatabase $DatabasePath
try {
    $conflictCount=0
    switch ($Action) {
        'Import' {
            if ([string]::IsNullOrWhiteSpace($ExportFolder)) { $ExportFolder=Read-Host 'Chemin du dossier contenant les nouveaux exports (dossiers complets, pas les .sav)' }
            $root=Get-Item -LiteralPath $ExportFolder
            if (-not $root.PSIsContainer) { throw 'Dossier requis.' }
            $paths=@(Get-ChildItem -LiteralPath $root.FullName -Filter secteurs.csv -Recurse -File -ErrorAction Stop | Sort-Object FullName | Select-Object -ExpandProperty FullName)
            if ($paths.Count -gt 1000) { throw 'Plus de 1000 exports : choisir un dossier plus precis.' }
            $result=Import-AcrExports $db $paths $Profile
            Write-Host "Nouvelles : $($result.Inserted) ; deja presentes : $($result.Repeated) ; conflits : $($result.Conflicts)"
            $conflictCount=$result.Conflicts
        }
        'ExporterRevue' {
            if ([string]::IsNullOrWhiteSpace($ReviewPath)) {
                New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null
                $ReviewPath=Join-Path $ReportRoot ('revue-'+[guid]::NewGuid().ToString('N')+'.json')
            }
            New-AcrReviewTemplate $db $Profile $ReviewPath
            Write-Host "Revue a remplir : $ReviewPath"
            Write-Host 'Lire README.fr.md. Confirmer uniquement les tentatives verifiees a l ecran ; ne pas valider en bloc.'
        }
        'AppliquerRevue' {
            if ([string]::IsNullOrWhiteSpace($ReviewPath)) { $ReviewPath=Read-Host 'Chemin du fichier de revue JSON complete' }
            Set-AcrReviews $db $Profile $ReviewPath
            Write-Host 'Revue appliquee. Validation manuelle enregistree, pas une detection du jeu.'
        }
    }
    $counts=Get-AcrCounts $db $Profile
    Write-Host "Tentatives conservees : $($counts.Attempts) ; admissibles : $($counts.Eligible) ; conflits stockes : $($counts.Conflicts)"
    $output=Export-AcrStatistics $db $Profile $ReportRoot
    Write-Host "Rapport : $output"
    if ($counts.Eligible -eq 0) { Write-Host 'Aucune tentative validee : resume, gains et progression sont vides. Les tentatives sont conservees.' }
    if ($conflictCount -gt 0) { throw 'Conflits sauvegardes et tentatives concernees exclues. Examiner conflits.csv ; aucun ancien contenu remplace.' }
} finally { $db.Dispose() }
