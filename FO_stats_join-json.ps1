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

$OCEPaths = @('sydney/','melbourne/')
$USPaths  = @('california/','dallas/','virginia/','miami/')
$BRPaths  = @('saopaulo/','fortaleza/')
$EUPaths  = @('ireland/','stockholm/')
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
    $htmlBody += ($JSON.SummaryAttack  | Select-Object Name,KPM,KD,Kills,Death,TKill,Dmg,DPM,FlagCap,FlagTake,FlagTime,Win,Draw,Loss,TimePlayed,Classes | Sort-Object Name | ConvertTo-Html -Fragment)  -replace '<table>','<table id="AttackSummary">' -replace '<tr><th>','<thead><tr><th>' -replace '</th></tr>','</th></tr></thead>'        
    $htmlBody += '<h2>Defence Summary</h2>'
    $htmlBody += ($JSON.SummaryDefence  | Select-Object Name,KPM,KD,Kills,Death,TKill,Dmg,DPM,FlagStop,Win,Draw,Loss,TimePlayed,Classes | Sort-Object Name | ConvertTo-Html -Fragment)  -replace '<table>','<table id="DefenceSummary">' -replace '<tr><th>','<thead><tr><th>' -replace '</th></tr>','</th></tr></thead>'        
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
      if ($path + ($f.Name -replace '_blue_vs_red_stats.json','') -in $outJson.Matches.Match) { 
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
    if ($newJson.SummaryAttack.Count -lt 4)  { continue }
    
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


