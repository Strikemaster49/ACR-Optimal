# Experimental read-only decoder. Export candidate blocks separately, never infer active session.
[CmdletBinding()]
param(
    [string]$SavePath,
    [string]$StageId='AlsaceS4SaverneShort1Forward',
    [string]$CarId='SkodaFabiaRSRally2',
    [string]$OutputRoot=(Join-Path $env:LOCALAPPDATA 'ACR-Optimal\DecodedEvidence')
)
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($SavePath)) {
    Write-Host 'Lecteur experimental pour Obersteigen / Skoda Fabia RS Rally2.'
    Write-Host 'Utilisez une COPIE .sav du diagnostic, pas le fichier original du jeu.'
    $SavePath=Read-Host 'Chemin complet du fichier .sav copie (sans guillemets)'
}
$item=Get-Item -LiteralPath $SavePath
if ($item.PSIsContainer -or $item.Length -gt 8MB) { throw 'Fichier attendu, limite 8 MiB.' }
$bytes=[IO.File]::ReadAllBytes($item.FullName)
if ($bytes.Length -lt 4 -or [Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'GVAS') { throw 'Signature GVAS absente : format non pris en charge.' }
$script:offset=0
function UInt32 {
    if ($script:offset+4 -gt $bytes.Length) { throw 'Fin inattendue.' }
    $v=[BitConverter]::ToUInt32($bytes,$script:offset); $script:offset+=4; return $v
}
function Float32 {
    if ($script:offset+4 -gt $bytes.Length) { throw 'Fin inattendue.' }
    $v=[BitConverter]::ToSingle($bytes,$script:offset); $script:offset+=4
    if ([single]::IsNaN($v) -or [single]::IsInfinity($v) -or $v -lt 0 -or $v -gt 86400) { throw 'Temps hors limites.' }
    return [double]$v
}
function FString {
    $n=UInt32
    if ($n -lt 2 -or $n -gt 512 -or $script:offset+$n -gt $bytes.Length) { throw 'Chaine non prise en charge.' }
    if ($bytes[$script:offset+$n-1] -ne 0) { throw 'Terminaison de chaine absente.' }
    $s=[Text.Encoding]::UTF8.GetString($bytes,$script:offset,[int]$n-1); $script:offset+=$n
    return $s
}
function HashBytes([byte[]]$Data) {
    $algorithm=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($algorithm.ComputeHash($Data)).Replace('-','').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}
$needle=[Text.Encoding]::UTF8.GetBytes($StageId+[char]0)
$rows=New-Object 'System.Collections.Generic.List[object]'
$blocks=New-Object 'System.Collections.Generic.List[object]'
$candidates=0
for ($position=4; $position -le $bytes.Length-$needle.Length-4; $position++) {
    if ($bytes[$position] -ne $needle[0]) { continue }
    $match=$true
    for ($j=0; $j -lt $needle.Length; $j++) { if ($bytes[$position+$j] -ne $needle[$j]) { $match=$false; break } }
    if (-not $match) { continue }
    if ([BitConverter]::ToUInt32($bytes,$position-4) -ne $needle.Length) { continue }
    $script:offset=$position+$needle.Length
    $candidate=New-Object 'System.Collections.Generic.List[object]'
    try {
        # Observed header: eight zero bytes, eight stable token bytes, FString stage.
        # Token semantics (apparently a timestamp) and universal uniqueness are unproven.
        if ($position -lt 20) { throw 'Entete de bloc absent.' }
        for ($h=$position-20; $h -lt $position-12; $h++) {
            if ($bytes[$h] -ne 0) { throw 'Entete de bloc non pris en charge.' }
        }
        $tokenBytes=New-Object byte[] 8
        [Array]::Copy($bytes,$position-12,$tokenBytes,0,8)
        $blockToken=[BitConverter]::ToString($tokenBytes).Replace('-','').ToLowerInvariant()
        if ($blockToken -eq '0000000000000000') { throw 'Jeton nul non pris en charge.' }
        $attemptCount=UInt32
        if ($attemptCount -lt 1 -or $attemptCount -gt 1000) { throw 'Nombre de tentatives hors limites.' }
        for ($run=0; $run -lt $attemptCount; $run++) {
            $attemptStart=$script:offset
            $firstRow=$candidate.Count
            $runId=UInt32
            if ($runId -ne $run) { throw 'Ordre de tentative non reconnu.' }
            $car=FString
            if ($car -ne $CarId) { throw 'Voiture non correspondante.' }
            $keyMaterial=ConvertTo-Json -InputObject @('acr-attempt-candidate-v1',$blockToken,$StageId,$car,[string]$runId) -Compress
            $attemptKey=HashBytes ([Text.Encoding]::UTF8.GetBytes($keyMaterial))
            $count=UInt32
            if ($count -lt 2 -or $count -gt 32) { throw 'Nombre de passages hors limites.' }
            $prior=0.0
            for ($sector=0; $sector -lt $count; $sector++) {
                $index=UInt32; $cumulative=Float32; $duration=Float32
                if ($index -ne $sector) { throw 'Ordre de secteur non reconnu.' }
                if ($sector -eq 0) {
                    if ($cumulative -ne 0 -or $duration -ne 0) { throw 'Origine non nulle.' }
                } else {
                    if ($duration -le 0 -or [Math]::Abs(($cumulative-$prior)-$duration) -gt 0.005) { throw 'Cumul/duree incoherents.' }
                    $candidate.Add([pscustomobject]@{BlockOffset=$position; BlockToken=$blockToken; AttemptKeyCandidate=$attemptKey;
                        KeyStatus='experimental-per-profile'; RawAttemptSHA256=''; RunIndex=$runId; StageId=$StageId; CarId=$car;
                        SectorIndex=$index; CumulativeSeconds=$cumulative; DurationSeconds=$duration; Mode='unverified'; Validity='unverified'})
                }
                $prior=$cumulative
            }
            # Trailer semantics unknown. Accept only the zero trailer demonstrated by the captures.
            for ($t=0; $t -lt 3; $t++) { if ((UInt32) -ne 0) { throw 'Metadonnees non nulles non prises en charge.' } }
            $attemptBytes=New-Object byte[] ($script:offset-$attemptStart)
            [Array]::Copy($bytes,$attemptStart,$attemptBytes,0,$attemptBytes.Length)
            $attemptHash=HashBytes $attemptBytes
            for ($r=$firstRow; $r -lt $candidate.Count; $r++) { $candidate[$r].RawAttemptSHA256=$attemptHash }
        }
        foreach ($row in $candidate) { $rows.Add($row) }
        $blocks.Add([pscustomobject]@{BlockOffset=$position; BlockToken=$blockToken; KeyStatus='experimental-per-profile';
            RunCount=$attemptCount; SectorRows=$candidate.Count;
            Role='unverified'; StageId=$StageId; CarId=$CarId})
        $candidates++
    } catch { continue }
}
if ($candidates -eq 0) { throw 'Source non reconnue : aucun bloc compatible. Aucun chrono exporte.' }
$hash=HashBytes $bytes
$output=Join-Path $OutputRoot ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $output -Force | Out-Null
$rows | Export-Csv (Join-Path $output 'secteurs.csv') -NoTypeInformation -Encoding UTF8
$blocks | Export-Csv (Join-Path $output 'blocs.csv') -NoTypeInformation -Encoding UTF8
@{SourceSHA256=$hash; Source=$item.FullName; CandidateBlocks=$candidates;
    RunCount=@($rows | Select-Object BlockOffset,RunIndex -Unique).Count; Mode='unverified'; Validity='unverified';
    Blocks=@($blocks.ToArray()); ActiveSession='unverified';
    KeyStatus='Experimental candidate verified on supplied snapshots; not proven unique across all sessions or profiles';
    Layout='Experimental sequential runs, UTF8 car, indexed Float32 cumulative/duration, zero trailer';
    Limitation='Not a production collector. No TT mode or penalty semantics demonstrated.'} |
    ConvertTo-Json -Depth 4 | Set-Content (Join-Path $output 'preuve.json') -Encoding UTF8
Write-Host "Secteurs extraits : $output"
Write-Host "$candidates bloc(s) candidat(s). Consulter blocs.csv : aucun bloc n'est designe comme session active."
Write-Host 'RunIndex est local au bloc ; BlockOffset peut changer entre fichiers et ne constitue pas une cle persistante.'
Write-Host 'BlockToken et AttemptKeyCandidate sont experimentaux. Une cle identique avec un contenu different doit etre signalee, pas ignoree.'
Write-Host 'Verifiez chaque ligne avec le classement. Mode et validite non verifies : aucun record SQLite cree.'
