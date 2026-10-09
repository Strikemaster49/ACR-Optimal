Set-StrictMode -Version 2
function ConvertTo-AcrMilliseconds($Seconds) {
    return [long][Math]::Round(([double]$Seconds)*1000,0,[MidpointRounding]::AwayFromZero)
}
function Format-AcrTime($Seconds) {
    if ($null -eq $Seconds) { return '--:--.---' }
    $ms=ConvertTo-AcrMilliseconds $Seconds
    $sign=''; if ($ms -lt 0) { $sign='-'; $ms=-$ms }
    return ('{0}{1}:{2:00}.{3:000}' -f $sign,[long][Math]::Floor($ms/60000),[long][Math]::Floor(($ms%60000)/1000),($ms%1000))
}
function Format-AcrGain($Seconds) {
    $ms=ConvertTo-AcrMilliseconds $Seconds
    return (($ms/1000.0).ToString('0.000',[Globalization.CultureInfo]::InvariantCulture)+' s')
}
function Get-AcrDisplayStatus($Row) {
    if ($Row['conflicted'] -eq 1) { return 'Conflit - exclue' }
    if ($Row['eligible'] -eq 1) { return 'Confirmee - admissible' }
    if ($Row['review_origin'] -eq 'user-attested') { return 'Revue - exclue (voir details)' }
    return 'En attente de validation'
}
Export-ModuleMember -Function ConvertTo-AcrMilliseconds,Format-AcrTime,Format-AcrGain,Get-AcrDisplayStatus
