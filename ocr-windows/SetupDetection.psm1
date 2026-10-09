Set-StrictMode -Version 2
function Normalize-AcrSetupName([string]$Text) {
 $decomposed=$Text.Normalize([Text.NormalizationForm]::FormD)
 $b=New-Object Text.StringBuilder
 foreach($c in $decomposed.ToCharArray()){if([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [Globalization.UnicodeCategory]::NonSpacingMark){[void]$b.Append($c)}}
 return ([regex]::Replace($b.ToString(),'\s+',' ').Trim().ToUpperInvariant())
}
function New-AcrSetupDetectionState {
 return [pscustomobject]@{State='Selectionne';PreviousName=$null;DetectedName=$null;Candidate=$null;Dirty=$false;LoadedObserved=$false;LastEvidence=$null;Declaration=$null}
}
function Test-AcrSetupTitle([string]$Text) {
 foreach($line in ($Text -split '[\r\n]+')){
  $normalized=Normalize-AcrSetupName $line
  if($normalized -match '^CONFIGURATION DE LA VOITURE\s*\|\s*(.+)$'){
   return [pscustomobject]@{Found=$true;Name=$Matches[1].Trim();Raw=$line}
  }
 }
 return [pscustomobject]@{Found=$false;Name=$null;Raw=$Text}
}
function Update-AcrSetupDetection($State,[string]$Text,[string]$CarId,[bool]$CarConfirmed,$Snapshots,[bool]$LoadConfirmed=$false) {
 $oldDeclarationId=$null;if($null -ne $State.Declaration){$oldDeclarationId=$State.Declaration.Id}
 $title=Test-AcrSetupTitle $Text
 $evidence=[ordered]@{Schema='acr-setup-ocr-evidence-v1';Utc=[DateTime]::UtcNow.ToString('o');Text=$Text;TitleFound=$title.Found;
  Name=$title.Name;CarId=$CarId;CarSource='manual';CarConfirmed=$CarConfirmed;LoadConfirmationSource='not-observed';
  Confidence=[ordered]@{Level='low';Kind='rule-based-not-OCR-probability';Score=$null};State='Selectionne';
  InvalidatesDeclarationId=$oldDeclarationId;MatchedVersionId=$null;Ambiguous=$false;AutomaticAssociation=$false;AppliedVerified=$false;ParametersVerified=$false}
 if($LoadConfirmed){$evidence.LoadConfirmationSource='manual'}
 if(-not $title.Found){$State.State='Selectionne';$State.PreviousName=$null;$State.LoadedObserved=$false;$State.Candidate=$null;$State.LastEvidence=$evidence;$State.Declaration=$null;return [pscustomobject]$evidence}
 $previousName=$State.PreviousName
 $changed=($null -ne $State.PreviousName -and $title.Name -ne $State.PreviousName)
 $evidence['PreviousName']=$previousName;$evidence['TitleChanged']=$changed
 if($changed -or $LoadConfirmed){$State.Candidate=$null;$State.Declaration=$null;$State.LoadedObserved=$true}
 if($LoadConfirmed){$State.Dirty=$false}
 $State.Declaration=$null
 $State.PreviousName=$title.Name;$State.DetectedName=$title.Name
 if(-not $changed -and -not $LoadConfirmed -and -not $State.LoadedObserved){
  $State.Candidate=$null;$State.Declaration=$null;$evidence.State='Selectionne';$State.State='Selectionne';$State.LastEvidence=$evidence;return [pscustomobject]$evidence
 }
 if($State.Dirty){$evidence.State='CorrespondanceInvalidee';$State.State=$evidence.State;$State.LastEvidence=$evidence;return [pscustomobject]$evidence}
 $State.State='ChargeDetecte';$evidence.State='ChargeDetecte'
 if($changed){$evidence.Confidence.Level='medium'}
 $matches=@($Snapshots|Where-Object {$_.CarId -ceq $CarId -and (Normalize-AcrSetupName $_.Name) -ceq $title.Name}|Sort-Object VersionId -Unique)
 if($CarConfirmed -and $matches.Count -eq 1){
  $State.Candidate=$matches[0];$State.State='AppliqueNonConfirme';$evidence.State=$State.State;$evidence.MatchedVersionId=$matches[0].VersionId
  $evidence.Confidence.Level='medium'
 }else{$State.Candidate=$null;$State.Declaration=$null;$evidence.Ambiguous=($matches.Count -gt 1)}
 $State.LastEvidence=$evidence
 return [pscustomobject]$evidence
}
function Invalidate-AcrSetupDetection($State,[string]$Reason) {
 $oldDeclarationId=$null;if($null -ne $State.Declaration){$oldDeclarationId=$State.Declaration.Id}
 $State.Dirty=$true;$State.State='CorrespondanceInvalidee';$State.Candidate=$null;$State.Declaration=$null
 return [pscustomobject]@{Schema='acr-setup-ocr-evidence-v1';Utc=[DateTime]::UtcNow.ToString('o');State=$State.State;Reason=$Reason;InvalidatesDeclarationId=$oldDeclarationId;
  Confidence=@{Level='none';Kind='manual-or-saved-value-divergence';Score=$null};AutomaticAssociation=$false}
}
function Test-AcrSavedSetupMatch($Candidate,$FreshSetups) {
 $matches=@($FreshSetups|Where-Object {$_.CarId -ceq $Candidate.CarId -and (Normalize-AcrSetupName $_.Name) -ceq (Normalize-AcrSetupName $Candidate.Name)}|Sort-Object VersionId -Unique)
 return ($matches.Count -eq 1 -and $matches[0].VersionId -ceq $Candidate.VersionId)
}
function Select-AcrManualSetupCandidate($State,$Snapshot,[string]$CarId,[bool]$CarConfirmed) {
 if(-not $CarConfirmed -or $Snapshot.CarId -cne $CarId){throw 'La voiture du snapshot doit etre confirmee manuellement.'}
 $State.Candidate=$Snapshot;$State.Dirty=$false;$State.Declaration=$null;$State.State='AppliqueNonConfirme'
 $State.LastEvidence=[pscustomobject]@{Schema='acr-setup-ocr-evidence-v1';Utc=[DateTime]::UtcNow.ToString('o');
  State=$State.State;Source='manual-snapshot-choice';CarId=$CarId;Name=$Snapshot.Name;MatchedVersionId=$Snapshot.VersionId;
  Confidence=@{Level='manual';Kind='user-declaration-not-automatic-detection';Score=$null};AutomaticAssociation=$false;AppliedVerified=$false;ParametersVerified=$false}
 return $State.LastEvidence
}
function Confirm-AcrSetupDeclaration($State,[bool]$AppliedConfirmed,[bool]$UnchangedConfirmed) {
 if($State.Dirty -or $null -eq $State.Candidate -or -not $AppliedConfirmed -or -not $UnchangedConfirmed){throw 'Setup applique, voiture, version unique et reglages inchanges doivent etre confirmes.'}
 $State.State='ConfirmePourLaTentative'
 $declaration=[pscustomobject]@{Schema='acr-setup-prospective-declaration-v1';Id=[guid]::NewGuid().ToString('N');Utc=[DateTime]::UtcNow.ToString('o');
  State=$State.State;SetupVersionId=$State.Candidate.VersionId;CarId=$State.Candidate.CarId;Name=$State.Candidate.Name;
  Scope='next-attempt-only';AttemptKey=$null;ConfirmedBy='user';AppliedConfirmed=$true;UnchangedConfirmed=$true;
  AutomaticAssociation=$false;EvidencePath=$null;Confidence=@{Level='manual';Kind='user-attestation-not-automatic-verification';Score=$null}}
 $State.Declaration=$declaration;return $declaration
}
Export-ModuleMember -Function Normalize-AcrSetupName,New-AcrSetupDetectionState,Test-AcrSetupTitle,Update-AcrSetupDetection,Invalidate-AcrSetupDetection,Test-AcrSavedSetupMatch,Select-AcrManualSetupCandidate,Confirm-AcrSetupDeclaration
