## _daily/US/FOSummary*_yyyy-MM-dd.txt
# _daily/US/.batch
# _daily/US/.new
###

param([switch]$ForceBatch,
      [string]$RemoveMatch,
      [string]$FromJson,
      [string]$StartDateTime,
      [string]$EndDateTime,
      [string]$TimeZone,
      [string]$FilterPath,
      [ValidateSet('ALL','US','EU','OCE','INT')]
              $Region,
      [string]$OutFile )

if ($ForceBatch) { $doBatch = $true }

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
          $CurrentJson.$array[$pos].Loss  += $p.Draw * $removeModifier
          $CurrentJson.$array[$pos].Draw  += $p.Loss * $removeModifier

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
    $htmlBody += $JSON.Matches       | Sort-Object Name   | ConvertTo-Html -Fragment
    $htmlBody += '<h2>Attack Summary</h2>'
    $htmlBody += $JSON.SummaryAttack  | Select-Object Name,KPM,KD,Kills,Death,TKill,Dmg,DPM,FlagCap,FlagTake,FlagTime,Win,Draw,Loss,TimePlayed,Classes | Sort-Object Name | ConvertTo-Html -Fragment
    $htmlBody += '<h2>Defence Summary</h2>'
    $htmlBody += $JSON.SummaryDefence | Select-Object Name,KPM,KD,Kills,Death,TKill,Dmg,DPM,FlagStop,Win,Draw,Loss,TimePlayed,Classes | Sort-Object Name  | ConvertTo-Html -Fragment
    $htmlBody += '<h2>Class Kills - Attack</h2>'
    $htmlBody += $JSON.ClassFragAttack | Sort-Object Name | ConvertTo-Html -Fragment
    $htmlBody += '<h2>Class Kills - Defence</h2>'
    $htmlBody += $JSON.ClassFragDefence | Sort-Object Name | ConvertTo-Html -Fragment
    $htmlBody += '</div></div><div class=row><div class=column style="width:580">'
    $htmlBody += '<h2>Class Time - Attack</h2>'
    $htmlBody += $JSON.ClassTimeAttack | Sort-Object Name | ConvertTo-Html -Fragment
    $htmlBody += '</div><div class=column style="width:580"> '
    $htmlBody += '<h2>Class Time - Defence</h2>'
    $htmlBody += $JSON.ClassTimeDefence| Sort-Object Name | ConvertTo-Html -Fragment
    $htmlBoyd += '</div></div>'

    $htmlHeader = @"
    <style>
     body {
            font-family: Verdana, Arial, Geneva, Helvetica, sans-serif;
            font-size: 12px;
            color: black;
        }
        table, td, th {
            border-color: black;
            border-style: solid;
            font-family: Verdana, Arial, Geneva, Helvetica, sans-serif;
            font-size: 11px;
        }
        table {
            border-width: 0 0 1px 1px;
            border-spacing: 0;
            border-collapse: collapse;
        }
        tr:nth-child(odd){
            background-color: lightgrey;
        }
        td, th {
            margin: 0;
            padding: 4px;
            border-width: 1px 1px 0 0;
            text-align: left;
        }
        th {
            color: white;
            background-color: black;
            font-weight: bold;
        }
        div {
          padding-top: 1px;
          padding-right: 5px;
          padding-bottom: 1x;
          padding-left: 1px;
        }
    </style>
"@
    
    return (ConvertTo-Html -Body $htmlBody -Head $htmlHeader)
} # end Generate HTML


if ($RemoveMatch) {
  if (!$FromJson) { Write-Host '-FromJson required'; return}

  $keepJson  = ((Get-Content -LiteralPath $FromJson -Raw)    | ConvertFrom-Json)
  $remJson   = ((Get-Content -LiteralPath $RemoveMatch -Raw) | ConvertFrom-Json)
  $outJson = (processFoStatsJSON -CurrentJson ($keepJson) -NewJson ($remJson) -RemoveMatch)
  
  if ($keepJson -eq $null -or $remJson -eq $null) { Write-Host "NULL JSON ERROR"; return }
  ($outJson | ConvertTo-Json) | Out-File -LiteralPath $FromJson
  Generate-DailyStatsHTML -JSON $outJson | Out-File -LiteralPath ($FromJson -replace '\.json$','.html')
  Write-Host "Removed: $RemoveMatch"
  return
}

if ($StartDateTime) {
  if ($Region) {
    $OCEPaths = @('sydney/','melbourne/','sydney-gz/','snoozer/')
    $USPaths  = @('california/','coach/','dallas/','dallas2/','iowa/','phoenix/','virginia/')
    $EUPaths  = @('dublin/','ireland/','stockholm/')
    $IntPaths = @('bahrain/','guam/','mumbai/','nz/','timbuktu/','tokyo/')
  
    if     ($Region -eq 'ALL') { $LatestPaths = $OCEPaths + $USPaths + $EUPaths + $IntPaths }
    elseif ($Region -eq 'US')  { $LatestPaths = $USPaths  }
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

  if ($TimeZone -in 'EU','OCE','US') {
    switch ($TimeZone) {
      'EU'  { $timeZoneID = [System.TimeZoneInfo]::GetSystemTimeZones() | Where-Object DisplayName -like '*Belgrade*'}
      'OCE' { $timeZoneID = [System.TimeZoneInfo]::GetSystemTimeZones() | Where-Object DisplayName -like '*Sydney*' }
      'US'  { $timeZoneID = [System.TimeZoneInfo]::GetSystemTimeZones() | Where-Object { $_.DisplayName -like '*Los?Angeles*' -or $_.DisplayName -like '*California*' } }
      else  { $timeZoneID = [System.TimeZoneInfo]::Utc }
    }
    
    $StartDT = [System.TimeZoneInfo]::ConvertTime($StartDT, $timeZoneID, [System.TimeZoneInfo]::Utc)
    $EndDT   = [System.TimeZoneInfo]::ConvertTime($EndDT  , $timeZoneID, [System.TimeZoneInfo]::Utc)
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
    $outJson | ConvertTo-Json | Out-File $OutFile 
    Write-Host "JSON has been generated - $i files added"
    Generate-DailyStatsHTML -JSON $outJson | Out-File -LiteralPath ($OutFile -replace '\.json$','.html')
    Write-Host "Batch HTML - Generated :- $($OutFile -replace '\.json$','.html')"
    return
  }
} 

foreach ($r in @('oceania','north-america','europe')) {
    if ($ForceBatch) { $doBatch = $true  }
    else             { $dobatch = $false } 
    switch ($r) {
      #'ALL' { $RegionDateTime = (Get-Date) }
      'north-america' { $RegionDateTime = ([System.TimeZoneInfo]::ConvertTime([datetime]::Now.DateTime,  [System.TimeZoneInfo]::Local, ([System.TimeZoneInfo]::GetSystemTimeZones() | Where { $_.DisplayName -like '*Los?Angeles*' -or $_.DisplayName -like '*California*'})) ) }
      'europe'        { $RegionDateTime = ([System.TimeZoneInfo]::ConvertTime([datetime]::Now.DateTime,  [System.TimeZoneInfo]::Local, ([System.TimeZoneInfo]::GetSystemTimeZones() | Where { $_.DisplayName -like '*Belgrade*'})) ) }
      'oceania'       { $RegionDateTime = ([System.TimeZoneInfo]::ConvertTime([datetime]::Now.DateTime,  [System.TimeZoneInfo]::Local, ([System.TimeZoneInfo]::GetSystemTimeZones() | Where { $_.DisplayName -like '*Sydney*'  })) ) }
      #'INT' { $RegionDateTime = (Get-Date) }
      else  { continue } 
    }

    #Region Day period will be between 6am to 5:59am
    if ($RegionDateTime.Hour -in @(0,1,2,3,4,5)) { $RegionDateTime = $RegionDateTime.AddDays(-1) }
    $strDate = ('{0:yyyy-MM-dd}' -f $RegionDateTime)

    $outDir   = "$PSScriptRoot/_daily/$r"
    $outFile  = "$outDir/$($r)_DailyStats_$($strDate).json"
    $outHtml  = "$outDir/$($r)_DailyStats_$($strDate).html"
    #$batchDir = "$outDir/.batch"
    #$newDir   = "$outDir/.new"

    if (!(Test-Path $outDir  )) { New-Item $outDir   -ItemType Directory | Out-Null }
    #if (!(Test-Path $batchDir)) { New-Item $batchDir -ItemType Directory | Out-Null }
    #if (!(Test-Path $newDir  )) { New-Item $newDir   -ItemType Directory | Out-Null }

    if ((Get-ChildItem "$newDir/*.json").Length -gt 0) {
      $doBatch = $true
      $batchFiles = (Get-ChildItem "$newDir/*.json")
    } 

    if ($doBatch) {
      foreach ($f in $batchFiles) {
        if (Test-Path -LiteralPath $OutFile) {
          #join files
          if (($f.BaseName -replace '_blue_vs_red_stats','') -in ($outJson.Matches.Match -replace '.*/','')) { 
            # Skip Match already reported
            Remove-Item -LiteralPath $f
            Write-Host "Batch Skipped - Match already existing:- $f"
            continue
          }
          $outJSON = (processFoStatsJSON -CurrentJson ((Get-Content -LiteralPath $outFile -Raw) | ConvertFrom-Json) -NewJson ((Get-Content -LiteralPath $f -Raw)| ConvertFrom-Json))
        } else {
          #new file becomes the file
          $outJSON = (Get-Content -LiteralPath $f -Raw) | ConvertFrom-Json
        }

        ($outJSON | ConvertTo-JSON) | Out-File -LiteralPath $outFile
        Write-Host "Batch Added - Match file:- $f"
        Copy-Item -LiteralPath $f -Destination $batchDir -Force
        Remove-Item -LiteralPath $f -Force
        #} else {
        #  #Just move the file
        #  Copy-Item -LiteralPath $f -Destination $batchDir -Force
        #  Move-Item -LiteralPath $f -Destination $outFile -Force
        #}
      }
    }
    if ( $doBatch -or ((Test-Path -LiteralPath $outFile) -and !(Test-Path -LiteralPath $outHtml)) ) {
      #generate HTML
      Write-Host "Batch HTML - Generated :- $outHtml"
      Generate-DailyStatsHTML -JSON (Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json) | Out-File -LiteralPath $outHtml
    }


} #end region for


