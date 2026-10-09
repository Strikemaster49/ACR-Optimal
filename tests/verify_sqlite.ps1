[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ModulePath,
      [Parameter(Mandatory=$true)][string]$WorkDir,
      [string[]]$RealExports=@())
$ErrorActionPreference='Stop'
Import-Module $ModulePath -Force
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
function Assert($Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function SHA([string]$Text) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function JsonFile($Value,[string]$Path) { $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8 }
function Fixture([string]$Path) {
    $times=@(@(30,40),@(32,37),@(20),@(25,35),@(10,20),@(15),@(9,9),@(12,13))
    $rows=@(for ($r=0; $r -lt $times.Count; $r++) {
        $token='0102030405060708'; $stage='fixture-stage'; $car='fixture-car'
        $key=SHA (ConvertTo-Json -InputObject @('acr-attempt-candidate-v1',$token,$stage,$car,[string]$r) -Compress)
        $sum=0
        for ($s=0; $s -lt $times[$r].Count; $s++) {
            $sum+=$times[$r][$s]
            [pscustomobject]@{AttemptKeyCandidate=$key;BlockToken=$token;RawAttemptSHA256=(SHA "run$r");RunIndex=$r;
                StageId=$stage;CarId=$car;SectorIndex=($s+1);DurationSeconds=$times[$r][$s];CumulativeSeconds=$sum;Mode='unverified';Validity='unverified'}
        }
    })
    $rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}
$database=Join-Path $WorkDir 'experimental.sqlite3'
$fixture=Join-Path $WorkDir 'fixture.csv'; Fixture $fixture
$originalHash=(Get-FileHash $fixture).Hash
$db=Open-AcrDatabase $database
try {
    if ($RealExports.Count -gt 0) {
        $hashes=@($RealExports | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash })
        $first=Import-AcrExports $db $RealExports 'real-captures'
        Assert ($first.Inserted -eq 7 -and $first.Conflicts -eq 0) 'Expected seven real captured attempts'
        $again=Import-AcrExports $db $RealExports 'real-captures'
        Assert ($again.Inserted -eq 0) 'Real reimport created duplicates'
        Assert ((Get-AcrCounts $db 'real-captures').Eligible -eq 0) 'Unknown real captures entered statistics'
        $formatted=@(Import-Csv -LiteralPath $RealExports[-1])
        foreach($r in $formatted){
            foreach($field in @('DurationSeconds','CumulativeSeconds')){
                $n=[double]::Parse($r.$field.Replace(',','.'),[Globalization.CultureInfo]::InvariantCulture)
                $r.$field=$n.ToString('G15',[Globalization.CultureInfo]::GetCultureInfo('fr-FR'))
            }
        }
        $formattedPath=Join-Path $WorkDir 'french-format.csv';$formatted|Export-Csv $formattedPath -NoTypeInformation
        $same=Import-AcrExports $db @($formattedPath) 'real-captures'
        Assert ($same.Inserted -eq 0 -and $same.Conflicts -eq 0) 'Locale/decimal precision created false conflicts'
        for ($i=0;$i -lt $RealExports.Count;$i++) { Assert ((Get-FileHash $RealExports[$i]).Hash -eq $hashes[$i]) 'Original real export modified' }
    }
    $result=Import-AcrExports $db @($fixture) 'tests'
    Assert ($result.Inserted -eq 8) 'Fixture not imported'
    Assert ((Get-AcrCounts $db 'tests').Eligible -eq 0) 'Unreviewed attempts eligible'
    $result=Import-AcrExports $db @($fixture,$fixture) 'tests'
    Assert ($result.Inserted -eq 0 -and $result.Repeated -eq 16) 'Repeated imports duplicated attempts'
    Assert ($db.Query('SELECT COUNT(*) AS n FROM observations o JOIN attempts a ON a.id=o.attempt_id WHERE a.profile=?',@('tests'))[0]['n'] -eq 8) 'Repeated provenance duplicated'
} finally {$db.Dispose()}
# A genuinely separate PowerShell process must read the persisted database.
$child=Join-Path $WorkDir 'restart.ps1'
@'
param($Module,$Database,$Output)
$ErrorActionPreference='Stop'
Import-Module $Module
$db=Open-AcrDatabase $Database
try { Get-AcrCounts $db tests | ConvertTo-Json | Set-Content $Output } finally { $db.Dispose() }
'@ | Set-Content $child
$childResult=Join-Path $WorkDir 'restart.json'
$engine=(Get-Process -Id $PID).Path
& $engine -NoProfile -File $child -Module $ModulePath -Database $database -Output $childResult
Assert ($LASTEXITCODE -eq 0) 'Child process failed'
$persisted=Get-Content $childResult -Raw | ConvertFrom-Json
Assert ($persisted.Attempts -eq 8 -and $persisted.Eligible -eq 0) 'Fresh process lost state'
# New connection: persistent state, same counts, no in-memory deduplication.
$db=Open-AcrDatabase $database
try {
    Assert ((Get-AcrCounts $db 'tests').Attempts -eq 8) 'Restart lost attempts'
    $review=Join-Path $WorkDir 'review.json'; New-AcrReviewTemplate $db 'tests' $review
    $document=Get-Content $review -Raw | ConvertFrom-Json
    foreach ($d in $document.Decisions) {
        if ($d.RunIndex -eq 7) {continue}
        $d.ConfirmAgainstGame=$true;$d.Mode='TT';$d.Validity='valid';$d.Complete=$true
        $d.SectorsVerified=$true;$d.ExpectedSectorCount=2;$d.PenaltySeconds=0
        $d.OfficialFinalSeconds=$d.RawFinalSeconds
        switch ([int]$d.RunIndex) {
            2 {$d.Validity='abandoned';$d.Complete=$false;$d.OfficialFinalSeconds=$null}
            3 {$d.PenaltySeconds=5;$d.OfficialFinalSeconds=65}
            4 {$d.Validity='invalid'}
            5 {$d.Complete=$false;$d.OfficialFinalSeconds=$null}
            6 {$d.Mode='other'}
        }
    }
    JsonFile $document $review; Set-AcrReviews $db 'tests' $review
    Assert ((Get-AcrCounts $db 'tests').Eligible -eq 2) 'Abandoned/invalid/incomplete/penalized/other-mode exclusions failed'
    $report=Export-AcrStatistics $db 'tests' (Join-Path $WorkDir 'reports')
    $summary=@(Import-Csv (Join-Path $report 'resume.csv'))[0]
    Assert ([double]$summary.BestCompleteSeconds -eq 69 -and [double]$summary.OptimalSeconds -eq 67 -and [double]$summary.GainSeconds -eq 2) 'Best/optimal incorrect'
    $gains=@(Import-Csv (Join-Path $report 'gains-secteurs.csv'))
    Assert ([double]$gains[0].GainSeconds -eq 2 -and [double]$gains[1].GainSeconds -eq 0) 'Sector gains incorrect'
    $progress=@(Import-Csv (Join-Path $report 'progression.csv'))
    Assert ($progress.Count -eq 2 -and [double]$progress[0].OptimalSoFar -eq 70 -and [double]$progress[1].OptimalSoFar -eq 67) 'Progression leaked future minimum'
    $attemptRows=@(Import-Csv (Join-Path $report 'tentatives.csv'))
    Assert ($attemptRows.Count -eq 8 -and $attemptRows[0].stage -eq 'fixture-stage') 'Attempt report missing actual fields'
    $stable=Import-AcrExports $db @($fixture) 'tests'
    Assert ($stable.Inserted -eq 0 -and (Get-AcrCounts $db 'tests').Eligible -eq 2) 'Repeated import erased review or created records'
    # Review mismatch must roll back all earlier decisions in that invocation.
    $bad=Get-Content $review -Raw | ConvertFrom-Json
    $bad.Decisions[0].Validity='invalid';$bad.Decisions[1].OfficialFinalSeconds=999
    $badPath=Join-Path $WorkDir 'bad-review.json'; JsonFile $bad $badPath
    $rejected=$false;try {Set-AcrReviews $db 'tests' $badPath}catch{$rejected=$true}
    Assert $rejected 'Mismatched final accepted'
    Assert ((Get-AcrCounts $db 'tests').Eligible -eq 2) 'Partial review committed despite failure'
    # A changed source payload for the same identity preserves original values but quarantines it.
    $conflictRows=@(Import-Csv $fixture)
    foreach ($r in $conflictRows) {if($r.RunIndex -eq '0'){$r.RawAttemptSHA256=SHA 'conflicting-source'}}
    $conflictPath=Join-Path $WorkDir 'conflict.csv';$conflictRows|Export-Csv $conflictPath -NoTypeInformation
    $result=Import-AcrExports $db @($conflictPath) 'tests'
    Assert ($result.Conflicts -eq 1) 'Identity conflict not signaled'
    $result=Import-AcrExports $db @($conflictPath) 'tests'
    Assert ((Get-AcrCounts $db 'tests').Conflicts -eq 1) 'Repeated conflict duplicated evidence'
    Assert ((Get-AcrCounts $db 'tests').Eligible -eq 1) 'Conflicted record remained eligible'
    Assert ($db.Query('SELECT raw_final FROM attempts WHERE profile=? AND run_index=0',@('tests'))[0]['raw_final'] -eq 70) 'Conflict overwrote original attempt'
    # Malformed second export must prevent even the first valid new export from being committed.
    $broken=@(Import-Csv $fixture);$broken[0].DurationSeconds='999'
    $brokenPath=Join-Path $WorkDir 'broken.csv';$broken|Export-Csv $brokenPath -NoTypeInformation
    $rejected=$false;try{Import-AcrExports $db @($fixture,$brokenPath) 'new-profile' | Out-Null}catch{$rejected=$true}
    Assert $rejected 'Incoherent sectors accepted'
    Assert ((Get-AcrCounts $db 'new-profile').Attempts -eq 0) 'Invalid batch committed partial input'
    # Same source identities in another explicit profile must remain isolated.
    $otherResult=Import-AcrExports $db @($fixture) 'other-player'
    Assert ($otherResult.Inserted -eq 8) 'Independent player namespace merged identities'
    Assert ((Get-AcrCounts $db 'other-player').Conflicts -eq 0) 'Conflict crossed player namespaces'
    Assert ((Get-AcrCounts $db 'tests').Attempts -eq 8) 'Other player changed original profile counts'
    $otherReview=Get-Content $review -Raw | ConvertFrom-Json
    $otherReview.Profile='other-player'
    $otherReviewPath=Join-Path $WorkDir 'other-review.json';JsonFile $otherReview $otherReviewPath
    Set-AcrReviews $db 'other-player' $otherReviewPath
    Assert ((Get-AcrCounts $db 'other-player').Eligible -eq 2) 'Profile-specific review failed'
    Assert ((Get-AcrCounts $db 'tests').Eligible -eq 1) 'Review affected another profile'
    Assert ((Get-FileHash $fixture).Hash -eq $originalHash) 'Original fixture modified'
} finally {$db.Dispose()}
# Refuse an unrelated database, preserving its tables.
$other=Join-Path $WorkDir 'other.sqlite3';$foreign=New-Object ACROptimal.Experimental.Database($other)
try{$foreign.Exec('CREATE TABLE private_data(value TEXT)',@())}finally{$foreign.Dispose()}
$rejected=$false;try{$unexpected=Open-AcrDatabase $other;$unexpected.Dispose()}catch{$rejected=$true}
Assert $rejected 'Foreign database accepted'
$foreign=New-Object ACROptimal.Experimental.Database($other)
try{Assert ($foreign.Query("SELECT COUNT(*) AS n FROM sqlite_master WHERE type='table'",@())[0]['n'] -eq 1) 'Foreign database modified'}finally{$foreign.Dispose()}
'PASS: real imports, persistence/restart, repeat import, quarantine, invalid/incomplete/abandoned/penalty exclusions, timing consistency, rollback, conflicts, statistics, progression and source preservation.'
