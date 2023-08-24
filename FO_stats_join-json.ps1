## _daily/US/FOSummary*_yyyy-MM-dd.txt
# _daily/US/.batch
# _daily/US/.new
###

param([switch]$ForceBatch,
      [string]$RemoveMatch,   # JSON file to remove $FromJson file
      [string]$FromJson,      # See Remove Match
      [string]$StartDateTime, # Input UTC time to match file names
      [string]$EndDateTime,   # Input UTC time to match file names
      [string]$FilterPath,
      [ValidateSet('ALL','US','BR','EU','OCE','INT')]
              $Region,
      [string]$GenerateHTML,
      [string]$OutFile )

if ($ForceBatch) { $doBatch = $true }

# Update me for -Region parameter and Daily Stats updates
$OCEPaths = @('sydney/','melbourne/')
$USPaths  = @('california/','dallas/','virginia/','miami/','phoenix')
$BRPaths  = @('saopaulo/','fortaleza/')
$EUPaths  = @('ireland/','stockholm/','london/')
$IntPaths = @('bahrain/','guam/','mumbai/','tokyo/')

$script:ClassToStr = @('World','Sco','Snp','Sold','Demo','Med','HwG','Pyro','Spy','Eng', 'SG')
$script:ClassAllowedStr = @('Sco','Sold','Demo','Med','HwG','Pyro','Spy','Eng')
$script:ClassAllowed       = @(1,3,4,5,6,7,8,9)
$script:ClassAllowedWithSG = @(1,3,4,5,6,7,8,9,10)

function Format-MinSec {
  param($sec)

  if ($sec -eq 0) { return '' }
  $ts = New-TimeSpan -Seconds $sec
  $mins = ($ts.Days * 24 + $ts.Hours) * 60 + $ts.minutes
  return "$($mins):$("{0:d2}" -f $ts.Seconds)"
}

function Sum-MinSec {
  param($minSec1,$minSec2,[switch]$Deduct)

  $split1 = $minSec1 -split ':'
  $split2 = $minSec2 -split ':'

  if ($Deduct) { $removeModifier = -1 }
  else { $removeModifier = 1 }

  $secs = (([int]$split1[0] + ($removeModifier * [int]$split2[0])) * 60) + ([int]$split1[1] + ($removeModifier * [int]$split2[1]) )

  return (Format-MinSec $secs)
}

function Table-ClassInfo {
  param([ref]$Table,$Name,$TimePlayed)
  $out = ''
  $classlist = @{}

  $timePlayedSplit = $TimePlayed -split ':'
  $timePlayedSecs  = ([int]$timePlayedSplit[0] * 60) + [int]$timePlayedSplit[1]

  foreach ($p in $Table.Value) {
    if ($p.Name -eq $Name) {
      foreach ($class in $ClassAllowed) {
        $strClass = $ClassToStr[$class]        
        $time     = $p.($strClass)
        if ($time -notin 0,'',$null) {
          $classlist.$strClass = ($time / $timePlayedSecs)
        }
      }

      foreach ($c in ($classlist.GetEnumerator() | Sort-Object Value -Descending)) {        
        $out += "$(($c.Name).PadRight(4)) $(('{0:P0}' -f $c.Value).PadLeft(3))|"
      }
      
      return $out -replace '\|$',''
    }
  }
}

function arrFindPlayer {
  param([ref]$Array,$Name)
  $i = 0
  foreach ($p in $array.Value) {
    if ($p.Name -eq $Name) { return $i }
    $i++
  }

  return -1
}


function arrFindPlayer-Class {
  param([ref]$Array,$Name)
  $i = 0
  foreach ($p in $Array.Value) {
    if ($p.Name -eq $Name) { return $i }
    $i++
  }

  return -1
}


function processFoStatsJSON {
    param( [Parameter(Mandatory=$true)]$CurrentJson,
           [Parameter(Mandatory=$true)]$NewJson,
           [switch]$RemoveMatch
    )

    $removeModifier = 1
    if ($RemoveMatch) {
      $CurrentJson.Matches = ($CurrentJson.Matches | Where-Object Match -ne $NewJson.Matches[0].Match)
      $removeModifier = -1
    } else {
      $CurrentJson.Matches += $NewJson.Matches
    }



    #Add/Minus the JSONs
    foreach ($array in @('SummaryAttack','SummaryDefence')) {
        foreach ($p in $NewJson.$array) {


          $pos = (arrFindPlayer ([ref]$CurrentJson.$array) $p.Name)
          if ($removeModifier -gt 0 -and $pos -lt 0) {
              $CurrentJson.$array += [PSCustomObject]@{
                Name   = $p.Name
                KPM    = $null
                KD     = $null
                Kills  = 0
                Death  = 0
                TKill  = 0
                Dmg    = 0
                DPM    = $null
                SGKills  = 0
                SGDeath  = 0
                FlagCap  = 0
                FlagTake = 0
                FlagTime = 0
                FlagStop = 0
                Win  = 0
                Draw = 0
                Loss = 0
                TimePlayed = 0
                Classes = ''
            }
            $pos = ($CurrentJson.$array.Length) - 1
          }

          $CurrentJson.$array[$pos].Kills  += $p.Kills * $removeModifier
          $CurrentJson.$array[$pos].Death += $p.Death * $removeModifier
          $CurrentJson.$array[$pos].TKill  += $p.TKill * $removeModifier
          $CurrentJson.$array[$pos].Dmg    += $p.Dmg * $removeModifier
          $CurrentJson.$array[$pos].FlagStop += $p.FlagStop * $removeModifier
          $CurrentJson.$array[$pos].FlagTake  += $p.FlagTake * $removeModifier
          $CurrentJson.$array[$pos].FlagCap   += $p.FlagCap * $removeModifier
          $CurrentJson.$array[$pos].SGKills  += $p.SGKills * $removeModifier
          $CurrentJson.$array[$pos].SGDeath  += $p.SGDeath * $removeModifier
          $CurrentJson.$array[$pos].Win   += $p.Win * $removeModifier
          $CurrentJson.$array[$pos].Loss  += $p.Loss * $removeModifier
          $CurrentJson.$array[$pos].Draw  += $p.Draw * $removeModifier

          if ($RemoveMatch) {
            $CurrentJson.$array[$pos].TimePlayed = Sum-MinSec -MinSec1 $CurrentJson.$array[$pos].TimePlayed -MinSec2 ($p.TimePlayed) -Deduct
            $CurrentJson.$array[$pos].FlagTime   = Sum-MinSec -MinSec1 $CurrentJson.$array[$pos].FlagTime   -MinSec2 ($p.FlagTime)   -Deduct
          } else {
            $CurrentJson.$array[$pos].TimePlayed = Sum-MinSec $CurrentJson.$array[$pos].TimePlayed ($p.TimePlayed)
            $CurrentJson.$array[$pos].FlagTime   = Sum-MinSec $CurrentJson.$array[$pos].FlagTime    ($p.FlagTime)
          }

          if ($CurrentJson.$array[$pos].TimePlayed -in '0:00','') {
            $CurrentJson.$array = $CurrentJson.$array | Where-Object Name -ne $p.Name
          }

        }
    }

    foreach ($strTable in @("ClassFragAttack","ClassFragDefence","ClassTimeAttack","ClassTimeDefence")) {
      foreach ($p in $NewJson.$strTable) {
        $pos = (arrFindPlayer-Class ([ref]$CurrentJson.$strTable) $p.Name)
        if ($removeModifier -gt 0 -and $pos -lt 0) {
              $CurrentJson.$strTable +=  [PSCustomObject]@{
                Name = $p.Name
                Sco  = 0
                KPM1 = $p.KPM1
                Sold = 0
                KPM3 = $p.KPM3
                Demo = 0
                KPM4 = $p.KPM4
                Med  = 0
                KPM5 = $p.KPM5
                HwG  = 0
                KPM6 = $p.KPM6
                Pyro = 0
                KPM7 = $p.KPM7
                Spy  = 0
                KPM8 = $p.KPM8
                Eng  = 0
                KPM9 = $p.KPM9
                SG   = 0
                KPM0 = $p.KPM0
              }
          $pos = ($CurrentJson.$strTable.Length) - 1
        }

        foreach ($classID in $ClassAllowedWithSG) {
          if ($classID -eq 10 -and $strTable -like 'ClassTime*') { continue } 
          $class = $ClassToStr[$classID]
          $CurrentJson.$strTable[$pos].$class += $p.$class * $removeModifier
        }

        if (($CurrentJson.$strTable[$pos] | Measure-Object sco,sold,demo,med,hwg,pyro,spy,eng -Sum | foreach { $_.Sum } | Where { $_ -gt 0 }).Count -lt 1) {
          $CurrentJson.$strTable = $CurrentJson.$strTable | Where-Object Name -ne $p.Name 
        }
      }
    }


    #Recalcuted stats - i.e KD, per-min
    $x = 1
    foreach ($table in @($CurrentJson.SummaryAttack,$CurrentJson.SummaryDefence)) {
        if ($x -eq 1) { $classTable = [ref]$CurrentJson.ClassTimeAttack }
        else              { $classTable = [ref]$CurrentJson.ClassTimeDefence  }

        foreach ($player in $table) {
            $timePlayed = $player.TimePlayed -split ':'
            $timeMins   = [double]$timeplayed[0] + ([double]$timePlayed[1] / 60)
            $player.KPM = '{0:0.00}' -f ($player.Kills / $timeMins)
            $player.KD  = '{0:0.00}' -f ($player.Kills / $player.Death)
            $player.DPM = '{0:0}' -f ($player.Dmg / $timeMins)
            $player.Classes    = (Table-ClassInfo ($classTable) $player.Name $player.TimePlayed)
        }
        $x++
    }

    $x = 1
    foreach ($table in @($CurrentJson.ClassFragAttack,$CurrentJson.ClassFragDefence)) {
      foreach ($player in $table) {
        if ($x -eq 1) { $classTable = [ref]$CurrentJson.ClassTimeAttack  }
        else          { $classTable = [ref]$CurrentJson.ClassTimeDefence }

        foreach ($classID in $ClassAllowedWithSG) {
          $class   = $ClassToStr[$classID]
          if ($player.$class -gt 0) {
            $player."KPM$(if ($classID -eq 10) { 0 } else { $classID })" = '{0:0.00}' -f ($player.$class / (($ClassTable.Value | Where Name -EQ $player.Name)."$(if ($classID -eq 10) { $ClassToStr[9] } else { $class })" / 60))
          }
        }
      }
      $x++
    }
    return $CurrentJson
}

function Generate-DailyStatsHTML {
    param([array]$JSON)
    
    $htmlBody  = '<div class=row><div class=column><h2>Match Log</h2>'
    $htmlBody += ($JSON.Matches       | Sort-Object Name   | ConvertTo-Html -Fragment ) -replace '<table>','<table id="MatchLog">' -replace '<tr><th>','<thead><tr><th>' -replace '</th></tr>','</th></tr></thead>'
    $htmlBody += '<h2>Attack Summary</h2>'
    $htmlBody += ($JSON.SummaryAttack  | Select-Object Name,KPM,KD,Kills,Death,TKill,Dmg,SGKills,DPM,FlagCap,FlagTake,FlagTime,Win,Draw,Loss,TimePlayed,Classes | Sort-Object Name | ConvertTo-Html -Fragment)  -replace '<table>','<table id="AttackSummary">' -replace '<tr><th>','<thead><tr><th>' -replace '</th></tr>','</th></tr></thead>'        
    $htmlBody += '<h2>Defence Summary</h2>'
    $htmlBody += ($JSON.SummaryDefence  | Select-Object Name,KPM,KD,Kills,Death,TKill,Dmg,DPM,SGDeath,FlagStop,Win,Draw,Loss,TimePlayed,Classes | Sort-Object Name | ConvertTo-Html -Fragment)  -replace '<table>','<table id="DefenceSummary">' -replace '<tr><th>','<thead><tr><th>' -replace '</th></tr>','</th></tr></thead>'        
    $htmlBody += '<h2>Class Kills - Attack</h2>'
    $htmlBody += ($JSON.ClassFragAttack | Sort-Object Name | ConvertTo-Html -Fragment)   -replace '<table>','<table id="ClassKillsAttack">' -replace '<tr><th>','<thead><tr><th>' -replace '</th></tr>','</th></tr></thead>'
    $htmlBody += '<h2>Class Kills - Defence</h2>'
    $htmlBody += ($JSON.ClassFragDefence | Sort-Object Name | ConvertTo-Html -Fragment)  -replace '<table>','<table id="ClassKillsDefence">' -replace '<tr><th>','<thead><tr><th>' -replace '</th></tr>','</th></tr></thead>'
    $htmlBody += '</div></div><div class=row><div class=column style="width:580">'
    $htmlBody += '<h2>Class Time - Attack</h2>'
    $htmlBody += ($JSON.ClassTimeAttack | Select-Object Name, `
                                        @{L='Sco' ; E={Format-MinSec $_.Sco}}, `
                                        @{L='Sold'; E={Format-MinSec $_.Sold}}, `
                                        @{L='Demo'; E={Format-MinSec $_.Demo}}, `
                                        @{L='Med' ; E={Format-MinSec $_.Med}}, `
                                        @{L='HwG' ; E={Format-MinSec $_.HwG}}, `
                                        @{L='Pyro'; E={Format-MinSec $_.Pyro}}, `
                                        @{L='Spy' ; E={Format-MinSec $_.Spy}}, `
                                        @{L='Eng' ; E={Format-MinSec $_.Eng}}  | Sort-Object Name | ConvertTo-Html -Fragment)  -replace '<table>','<table id="ClassTimeAttack">' -replace '<tr><th>','<thead><tr><th>' -replace '</th></tr>','</th></tr></thead>'
    $htmlBody += '</div><div class=column style="width:580"> '
    $htmlBody += '<h2>Class Time - Defence</h2>'
    $htmlBody += ($JSON.ClassTimeDefence | Select-Object Name, `
                                        @{L='Sco' ; E={Format-MinSec $_.Sco}}, `
                                        @{L='Sold'; E={Format-MinSec $_.Sold}}, `
                                        @{L='Demo'; E={Format-MinSec $_.Demo}}, `
                                        @{L='Med' ; E={Format-MinSec $_.Med}}, `
                                        @{L='HwG' ; E={Format-MinSec $_.HwG}}, `
                                        @{L='Pyro'; E={Format-MinSec $_.Pyro}}, `
                                        @{L='Spy' ; E={Format-MinSec $_.Spy}}, `
                                        @{L='Eng' ; E={Format-MinSec $_.Eng}}  | Sort-Object Name | ConvertTo-Html -Fragment)  -replace '<table>','<table id="ClassTimeDefence">' -replace '<tr><th>','<thead><tr><th>' -replace '</th></tr>','</th></tr></thead>'
    $htmlBoyd += '</div></div>'

    $htmlHeader = @"
    <link rel="stylesheet" href="fo_daily.css">
    <link rel="stylesheet" href="../../fo_daily.css">
    <link rel="stylesheet" href="http://haze.fortressone.org/.css/fo_daily.css">
    <script src="http://haze.fortressone.org/.css/fo_daily.js"></script>
    <script src="http://haze.fortressone.org/.css/tablesort.min.js"></script>
    <script src="http://haze.fortressone.org/.css/tablesort.number.min.js"></script>

"@
    $htmlPost += '<script>fo_daily_post();</script>'

    return (ConvertTo-Html -Body $htmlBody -Head $htmlHeader -PostContent $htmlPost)
} # end Generate HTML

if ($GenerateHTML) {
  Generate-DailyStatsHTML -JSON (Get-Content $GenerateHTML -Raw | ConvertFrom-Json) | Out-File ($GenerateHTML -replace '.json$','.html')
  write-host "Generated HTML:- $GenerateHTML"
  return
}

if ($RemoveMatch) {
  if (!$FromJson) { Write-Host '-FromJson required'; return}

  $keepJson  = ((Get-Content -LiteralPath $FromJson -Raw)    | ConvertFrom-Json)
  $remJson   = ((Get-Content -LiteralPath $RemoveMatch -Raw) | ConvertFrom-Json)
  $outJson = (processFoStatsJSON -CurrentJson ($keepJson) -NewJson ($remJson) -RemoveMatch)
  
  if ($keepJson -eq $null -or $remJson -eq $null) { Write-Host "NULL JSON ERROR"; return }
  ($outJson | ConvertTo-Json) | Out-File -LiteralPath $FromJson -Encoding utf8
  Generate-DailyStatsHTML -JSON $outJson | Out-File -LiteralPath ($FromJson -replace '\.json$','.html')  -Encoding utf8
  Write-Host "Removed: $RemoveMatch"
  return
}

if ($StartDateTime) {
  if ($Region) {  
    if     ($Region -eq 'ALL') { $LatestPaths = $OCEPaths + $USPaths + $EUPaths + $IntPaths }
    elseif ($Region -eq 'US')  { $LatestPaths = $USPaths  }
    elseif ($Region -eq 'BR')  { $LatestPaths = $BRPaths  }
    elseif ($Region -eq 'EU')  { $LatestPaths = $EUPaths  }
    elseif ($Region -eq 'OCE') { $LatestPaths = $OCEPaths }
    elseif ($Region -eq 'INT') { $LatestPaths = $IntPaths }

    $FilterPath = ''
    foreach ($p in $LatestPaths) { 
        if ($FilterPath -ne '') { $FilterPath = (@($FilterPath,"$($p)quad/","$($p)staging/") -join ',') }
        else                    { $FilterPath = "$($p)quad/,$($p)staging/" }
    }
  }

  $StartDT = [DateTime]::Parse($StartDateTime)
  if (!$EndDateTime) { $EndDT = $StartDT.AddDays(1) }
  else {
    $EndDT = [DateTime]::Parse($EndDateTime)

    if ($EndDT -lt $StartDT) {
      $temp = $StartDT
      $StartDT = $EndDT
      $EndDT   = $temp
      Remove-Variable $temp
    }
  }
 
  if ($OutFile -and (Test-Path -LiteralPath $OutFile)) {
    $outJson = (Get-Content -LiteralPath $OutFile -Raw) | ConvertFrom-Json
  } else {
    $outJson = $null
  }

  $filesBatched = @()
  foreach ($path in ($FilterPath -split ',')) {
    if (!(Test-Path $PSScriptRoot/$path/*_stats.json)) { continue }
    foreach ($f in (Get-ChildItem $PSScriptRoot/$path/*_stats.json)) {
      $fileDT = [datetime]::ParseExact(($f.Name -replace '^(\d\d\d\d-\d\d-\d\d-\d\d-\d\d-\d\d).*$','$1'),'yyyy-MM-dd-HH-mm-ss',$null)
      if ($fileDT -lt $StartDT -or $fileDT -gt $EndDT ) { continue } 
      if ($path + ($f.Name -replace '_blue_vs_red_stats.json','') -in $outJson.Matches.Match `
              -or ($f.Name -replace '_blue_vs_red_stats.json','') -in $outJson.Matches.Match) { 
        Write-Host "SKIPPED - Match already in the JSON: $path$($f.Name -replace '_blue_vs_red_stats.json','')"
        continue 
      }
      $filesBatched += @($f)
    }
  }

  
  $filesBatched = $filesBatched | Sort-Object Name
  $i = 0
  foreach ($f in $filesBatched) {
    $newJson = (Get-Content -LiteralPath $f -Raw) | ConvertFrom-Json
    if ($newJson.SummaryAttack.Count -lt 4)   { continue }
    elseif ('' -in $newJson.Matches.Match)    { continue }   
    elseif ($null -in $newJson.Matches.Match) { continue }

    Write-Host "Adding file to JSON:- $f"
    if (!$outJson) { $outJson = (Get-Content -LiteralPath $f -Raw) | ConvertFrom-Json }
    else { $outJson = processFoStatsJSON -CurrentJson $outJson -NewJson ((Get-Content -LiteralPath $f -Raw) | ConvertFrom-Json) }
    $i++
  }

  if (!$OutFile) {
    if ($Region) {
      $OutFile = "statsjoin_$region_$('{0:yyyy-MM-dd_HHmmss}' -f (Get-Date))_$($i)matches.json"
    } else {
      $OutFile = "statsjoin_$('{0:yyyy-MM-dd_HHmmss}' -f (Get-Date))_$($i)matches.json"
    }
  } 

  if ($i -lt 1) { Write-Host "No batch files found to be added to $region" }
  
  if ($outJson) { 
    if ($OutFile -match '[\\/]' -and !(Test-Path -LiteralPath (Split-Path -LiteralPath $OutFile))) {
      New-Item -Path (Split-Path -LiteralPath $OutFile) -ItemType Directory
    }
    $outJson | ConvertTo-Json | Out-File $OutFile  -Encoding utf8
    Write-Host "JSON has been generated - $i files added"
    Generate-DailyStatsHTML -JSON $outJson | Out-File -LiteralPath ($OutFile -replace '\.json$','.html') -Encoding utf8
    Write-Host "Batch HTML - Generated :- $($OutFile -replace '\.json$','.html')"
    return
  }
} 



# SIG # Begin signature block
# MIIboAYJKoZIhvcNAQcCoIIbkTCCG40CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUpZvtABt33/fegen1CIDvX3R9
# DDygghYVMIIDCDCCAfCgAwIBAgIQVxZN0cTEa7NFKtjIhSbFETANBgkqhkiG9w0B
# AQsFADAcMRowGAYDVQQDDBFIYXplIEF1dGhlbnRpY29kZTAeFw0yMzAyMTAwNTM3
# MzRaFw0yNDAyMTAwNTU3MzRaMBwxGjAYBgNVBAMMEUhhemUgQXV0aGVudGljb2Rl
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1M46e4LcpTytNDpPe4AN
# aUJrafdLCl23kH5G7qTsBRRwI6qpRhZc5TBI19oEwulC4t8h7nI6D78kYx8FdI2h
# tb0wWmhcPBAAT7iywe0G0Q3NgZxZKOyI0yto69Z7TMPnbGKhCegPuvAT0LejgTrK
# +OAH0a/uGBVCGgu1EsIOtVitWsuxTKNR5bX3b2Zoc1xaEVOMFGy74IvXzIx+VyaN
# pSH6JYo3iSLWmQNRMBvMPsRfcvkh9R1DXemAJX3LHEm0Bei3xco+20zhRQtCO1Md
# rAEAL3aq3oFDQ2KV1RCNqo5kvnwBBDumAveg7JnjuUd3DvqCF0+Hs+q2KjRy02vt
# MQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMw
# HQYDVR0OBBYEFFwWkpE7S3mEJiqQ8mTrbI0pUNm+MA0GCSqGSIb3DQEBCwUAA4IB
# AQC9XvfYZgwF/9CysiCloHccqkH8T+AJJCX1Uq1lZ9DTO7olZfTmrI/JQWrSDdrK
# hsEi9wp6uTjfapE18EQW9CBIAMNLFjhFv/uLGEp9vZpUWpuG+2hqVu0thtZbw/Gm
# gMh8yhm/lTXUj1tcltPDkgWnd2u44O2fdF2kE6hevBEXM71a45OiMic3SgpLi6m3
# nMrsdQ0wu3qDm5I2Tm/Htq7Telmq0V3Lu1CKK6lYxxR1+Epsxumyiu0q9IKeKLMR
# RlbKKqHPcKoOadWNfZ1kR+5sO4q3+Tnc1evHS4HbJHQVZtR2k/tdsOvNi8qk9Sh9
# +GFTkJDGhZR9TsyW2Se2KTUMMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAY
# WjANBgkqhkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNl
# cnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdp
# Q2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5
# MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVz
# dGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBz
# aN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbr
# VsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTR
# EEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJ
# z82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyO
# j4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6R
# AXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k
# 98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJ
# tppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUa
# dmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZB
# dd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVf
# nSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0T
# AQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0j
# BBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsG
# AQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9j
# cmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYD
# VR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3Qb
# PbYW1/e/Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5
# +KH38nLeJLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+n
# BgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc
# /RzY9HdaXFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVr
# zyerbHbObyMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o
# 4rmUMIIGrjCCBJagAwIBAgIQBzY3tyRUfNhHrP0oZipeWzANBgkqhkiG9w0BAQsF
# ADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQL
# ExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJv
# b3QgRzQwHhcNMjIwMzIzMDAwMDAwWhcNMzcwMzIyMjM1OTU5WjBjMQswCQYDVQQG
# EwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0
# IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxoY1BkmzwT1ySVFVxyUDxPKRN6mX
# UaHW0oPRnkyibaCwzIP5WvYRoUQVQl+kiPNo+n3znIkLf50fng8zH1ATCyZzlm34
# V6gCff1DtITaEfFzsbPuK4CEiiIY3+vaPcQXf6sZKz5C3GeO6lE98NZW1OcoLevT
# sbV15x8GZY2UKdPZ7Gnf2ZCHRgB720RBidx8ald68Dd5n12sy+iEZLRS8nZH92GD
# Gd1ftFQLIWhuNyG7QKxfst5Kfc71ORJn7w6lY2zkpsUdzTYNXNXmG6jBZHRAp8By
# xbpOH7G1WE15/tePc5OsLDnipUjW8LAxE6lXKZYnLvWHpo9OdhVVJnCYJn+gGkcg
# Q+NDY4B7dW4nJZCYOjgRs/b2nuY7W+yB3iIU2YIqx5K/oN7jPqJz+ucfWmyU8lKV
# EStYdEAoq3NDzt9KoRxrOMUp88qqlnNCaJ+2RrOdOqPVA+C/8KI8ykLcGEh/FDTP
# 0kyr75s9/g64ZCr6dSgkQe1CvwWcZklSUPRR8zZJTYsg0ixXNXkrqPNFYLwjjVj3
# 3GHek/45wPmyMKVM1+mYSlg+0wOI/rOP015LdhJRk8mMDDtbiiKowSYI+RQQEgN9
# XyO7ZONj4KbhPvbCdLI/Hgl27KtdRnXiYKNYCQEoAA6EVO7O6V3IXjASvUaetdN2
# udIOa5kM0jO0zbECAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYD
# VR0OBBYEFLoW2W1NhS9zKXaaL3WMaiCPnshvMB8GA1UdIwQYMBaAFOzX44LScV1k
# TN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcD
# CDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0
# cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmww
# IAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUA
# A4ICAQB9WY7Ak7ZvmKlEIgF+ZtbYIULhsBguEE0TzzBTzr8Y+8dQXeJLKftwig2q
# KWn8acHPHQfpPmDI2AvlXFvXbYf6hCAlNDFnzbYSlm/EUExiHQwIgqgWvalWzxVz
# jQEiJc6VaT9Hd/tydBTX/6tPiix6q4XNQ1/tYLaqT5Fmniye4Iqs5f2MvGQmh2yS
# vZ180HAKfO+ovHVPulr3qRCyXen/KFSJ8NWKcXZl2szwcqMj+sAngkSumScbqyQe
# JsG33irr9p6xeZmBo1aGqwpFyd/EjaDnmPv7pp1yr8THwcFqcdnGE4AJxLafzYeH
# JLtPo0m5d2aR8XKc6UsCUqc3fpNTrDsdCEkPlM05et3/JWOZJyw9P2un8WbDQc1P
# tkCbISFA0LcTJM3cHXg65J6t5TRxktcma+Q4c6umAU+9Pzt4rUyt+8SVe+0KXzM5
# h0F4ejjpnOHdI/0dKNPH+ejxmF/7K9h+8kaddSweJywm228Vex4Ziza4k9Tm8heZ
# Wcpw8De/mADfIBZPJ/tgZxahZrrdVcA6KYawmKAr7ZVBtzrVFZgxtGIJDwq9gdkT
# /r+k0fNX2bwE+oLeMt8EifAAzV3C+dAjfwAL5HYCJtnwZXZCpimHCUcr5n8apIUP
# /JiW9lVUKx+A+sDyDivl1vupL0QVSucTDh3bNzgaoSv27dZ8/DCCBsIwggSqoAMC
# AQICEAVEr/OUnQg5pr/bP1/lYRYwDQYJKoZIhvcNAQELBQAwYzELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBU
# cnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTAeFw0yMzA3
# MTQwMDAwMDBaFw0zNDEwMTMyMzU5NTlaMEgxCzAJBgNVBAYTAlVTMRcwFQYDVQQK
# Ew5EaWdpQ2VydCwgSW5jLjEgMB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0YW1wIDIw
# MjMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCjU0WHHYOOW6w+VLMj
# 4M+f1+XS512hDgncL0ijl3o7Kpxn3GIVWMGpkxGnzaqyat0QKYoeYmNp01icNXG/
# OpfrlFCPHCDqx5o7L5Zm42nnaf5bw9YrIBzBl5S0pVCB8s/LB6YwaMqDQtr8fwkk
# lKSCGtpqutg7yl3eGRiF+0XqDWFsnf5xXsQGmjzwxS55DxtmUuPI1j5f2kPThPXQ
# x/ZILV5FdZZ1/t0QoRuDwbjmUpW1R9d4KTlr4HhZl+NEK0rVlc7vCBfqgmRN/yPj
# yobutKQhZHDr1eWg2mOzLukF7qr2JPUdvJscsrdf3/Dudn0xmWVHVZ1KJC+sK5e+
# n+T9e3M+Mu5SNPvUu+vUoCw0m+PebmQZBzcBkQ8ctVHNqkxmg4hoYru8QRt4GW3k
# 2Q/gWEH72LEs4VGvtK0VBhTqYggT02kefGRNnQ/fztFejKqrUBXJs8q818Q7aESj
# pTtC/XN97t0K/3k0EH6mXApYTAA+hWl1x4Nk1nXNjxJ2VqUk+tfEayG66B80mC86
# 6msBsPf7Kobse1I4qZgJoXGybHGvPrhvltXhEBP+YUcKjP7wtsfVx95sJPC/QoLK
# oHE9nJKTBLRpcCcNT7e1NtHJXwikcKPsCvERLmTgyyIryvEoEyFJUX4GZtM7vvrr
# kTjYUQfKlLfiUKHzOtOKg8tAewIDAQABo4IBizCCAYcwDgYDVR0PAQH/BAQDAgeA
# MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYDVR0gBBkw
# FzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1NhS9zKXaa
# L3WMaiCPnshvMB0GA1UdDgQWBBSltu8T5+/N0GSh1VapZTGj3tXjSTBaBgNVHR8E
# UzBRME+gTaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQBggrBgEFBQcB
# AQSBgzCBgDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMFgG
# CCsGAQUFBzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3
# DQEBCwUAA4ICAQCBGtbeoKm1mBe8cI1PijxonNgl/8ss5M3qXSKS7IwiAqm4z4Co
# 2efjxe0mgopxLxjdTrbebNfhYJwr7e09SI64a7p8Xb3CYTdoSXej65CqEtcnhfOO
# HpLawkA4n13IoC4leCWdKgV6hCmYtld5j9smViuw86e9NwzYmHZPVrlSwradOKmB
# 521BXIxp0bkrxMZ7z5z6eOKTGnaiaXXTUOREEr4gDZ6pRND45Ul3CFohxbTPmJUa
# VLq5vMFpGbrPFvKDNzRusEEm3d5al08zjdSNd311RaGlWCZqA0Xe2VC1UIyvVr1M
# xeFGxSjTredDAHDezJieGYkD6tSRN+9NUvPJYCHEVkft2hFLjDLDiOZY4rbbPvlf
# sELWj+MXkdGqwFXjhr+sJyxB0JozSqg21Llyln6XeThIX8rC3D0y33XWNmdaifj2
# p8flTzU8AL2+nCpseQHc2kTmOt44OwdeOVj0fHMxVaCAEcsUDH6uvP6k63llqmjW
# Iso765qCNVcoFstp8jKastLYOrixRoZruhf9xHdsFWyuq69zOuhJRrfVf8y2OMDY
# 7Bz1tqG4QyzfTkx9HmhwwHcK1ALgXGC7KP845VJa1qwXIiNO9OzTF/tQa/8Hdx9x
# l0RBybhG02wyfFgvZ0dl5Rtztpn5aywGRu9BHvDwX+Db2a2QgESvgBBBijGCBPUw
# ggTxAgEBMDAwHDEaMBgGA1UEAwwRSGF6ZSBBdXRoZW50aWNvZGUCEFcWTdHExGuz
# RSrYyIUmxREwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAw
# GQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisG
# AQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFHnPPEzxdl5V+kNkLQUfRyt4K8bmMA0G
# CSqGSIb3DQEBAQUABIIBACv0W9Etwgiq8Hm0BSFfv+JwADrd2UlVOh9fUKb7Ejeo
# O7cliZNojdndN0rSRkJxet+To2ZbmgzefPUSzxsChQvEcGDoDgrBvGAi1zgGGmPb
# shpyhsRRIrxQ7zSs/FeYZ5ao0P9CLPJ2DIWpsJV17Bv+oUoTAxkgNfAfaw6wEe/4
# uubetLFaws4KDdwzkzlkh5veT12sDDvnP0W9fBYCXsVMqhNDN0Tn78p8Nl4lH8OY
# cCmvq1u4ZHl30Y8c0MBPdQLitMjb9CU9/n0z9d+T4/i6py40OmqjzEzgG16yqzFk
# +3AFT5MlXpese7u8gXQqMF25Hn64zqVYD++qeZog2iGhggMgMIIDHAYJKoZIhvcN
# AQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNl
# cnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBT
# SEEyNTYgVGltZVN0YW1waW5nIENBAhAFRK/zlJ0IOaa/2z9f5WEWMA0GCWCGSAFl
# AwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUx
# DxcNMjMwODIyMDUyOTAwWjAvBgkqhkiG9w0BCQQxIgQgIvSAORWs8v2L0/1SzAIg
# OXyuk4gDFBB6pN2J+wilLKYwDQYJKoZIhvcNAQEBBQAEggIAUhu9RGgkZcIXgc+C
# njenTCL0kZPRD0k5wsiaXyNdPkIwvSqjqG+oVPTtasBNEmf/nnEIuQ9bsJeOTxlU
# vBDP1a7SDUBwhe0VSG17u37Gv9bRIJFylmZ/97iysfv/eWb2GBNzg7MPWlAfujMV
# cetnxRvt7QCH9HgNEpxGBufjPj+EvFsdu8BX8GrIS3ckc0O/5nKskcjcC3Xz9ucY
# 04kf9SLpMseYYkYrt8PnlmgkhNOzahxUSxoPhfhIViCBh+o5nXqQrywNCVux6zeV
# 6uNCln4SUsTPCf2fdse88dDI3E6UiDJy4ygvzd6+HAK7ZDgWwvFJc0O7NFenqNLa
# bYuj2q3ZHP3XkLsQAHyWBkefsGOOnYLKi6Y/wPdEwK72w8X/IwTvKrdyl6oixrsQ
# qe1cgenh5eHBaETbfQD8ShESh1+ZQtIy9XU0GRhhidmjeEQeySFcgRsC5B2DJ3IH
# tDoyXxxA6JzL3Q8P3WxTlUnsT7uJuyeiiJ1IA6ZkCdFN4CHNVqAZj27x3UgQOWzV
# ELq3YPWR5PfItjioyuDiuNL7QzUxIbODBfRFuSgw89fXJVn7opkwSYO4FnCe56U+
# sAdQeacyXJbGZZFCU9Tpl1t2OrfmTrmbOar2lj2iUP4DIvTyrCdgRMlzQ5ieRWVR
# b8HP8/o9CMN40c2wfgUhTGrvx0Y=
# SIG # End signature block
