# Compare exported evidence, never import game records or choose the active session.
[CmdletBinding()]
param(
    [string[]]$EvidenceCsv=@(),
    [string]$OutputRoot=(Join-Path $env:LOCALAPPDATA 'ACR-Optimal\KeyEvidence')
)
$ErrorActionPreference='Stop'
if ($EvidenceCsv.Count -eq 0) {
    Write-Host 'Indiquez un dossier DecodedEvidence contenant les exports du NOUVEAU lecteur.'
    $folder=Read-Host 'Chemin du dossier'
    if ([string]::IsNullOrWhiteSpace($folder)) { throw 'Dossier requis.' }
    $item=Get-Item -LiteralPath $folder
    if (-not $item.PSIsContainer) { throw 'Dossier requis.' }
    $EvidenceCsv=@(Get-ChildItem -LiteralPath $item.FullName -Filter secteurs.csv -Recurse -File -ErrorAction Stop | Select-Object -ExpandProperty FullName)
}
if ($EvidenceCsv.Count -eq 0) { throw 'Aucun secteurs.csv.' }
$all=New-Object 'System.Collections.Generic.List[object]'
foreach ($path in $EvidenceCsv) {
    $resolved=(Get-Item -LiteralPath $path).FullName
    foreach ($row in @(Import-Csv -LiteralPath $resolved)) {
        if ($row.AttemptKeyCandidate -notmatch '^[0-9a-f]{64}$' -or $row.RawAttemptSHA256 -notmatch '^[0-9a-f]{64}$') {
            throw "Export ancien ou invalide : $resolved. Refaire avec le nouveau lecteur."
        }
        $all.Add([pscustomobject]@{Key=$row.AttemptKeyCandidate; Content=$row.RawAttemptSHA256; Source=$resolved;
            Sector=$row.SectorIndex; Token=$row.BlockToken; Run=$row.RunIndex})
    }
}
$report=@(foreach ($group in @($all | Group-Object Key)) {
    $variants=@($group.Group | Select-Object -ExpandProperty Content -Unique)
    $sources=@($group.Group | Select-Object -ExpandProperty Source -Unique)
    $status='consistent-observation'
    if ($variants.Count -gt 1) { $status='content-conflict' }
    [pscustomobject]@{AttemptKeyCandidate=$group.Name; BlockToken=$group.Group[0].Token; RunIndex=$group.Group[0].Run;
        SourceExports=$sources.Count; ContentVariants=$variants.Count; Status=$status}
})
$output=Join-Path $OutputRoot ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $output -Force | Out-Null
$report | Export-Csv (Join-Path $output 'cles.csv') -NoTypeInformation -Encoding UTF8
$conflicts=@($report | Where-Object Status -eq 'content-conflict')
Write-Host "$($report.Count) cles observees ; $($conflicts.Count) conflits de contenu. Resultat : $output"
Write-Host 'Ne comparer que les copies du meme profil joueur. Aucun record importe, aucune unicite universelle demontree.'
if ($conflicts.Count -gt 0) { throw 'Conflit : ne pas dedupliquer automatiquement ces tentatives.' }
