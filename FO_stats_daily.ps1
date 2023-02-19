## _daily/US/FOSummary*_yyyy-MM-dd.txt
# _daily/US/.batch
# _daily/US/.new
###

param([switch]$ForceBatch)

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
  param($minSec1,$minSec2)

  $split1 = $minSec1 -split ':'
  $split2 = $minSec2 -split ':'
  $secs = (([int]$split1[0] + [int]$split2[0]) * 60) + ([int]$split1[1] + [int]$split2[1] )

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
           [Parameter(Mandatory=$true)]$NewJson
    )

    $CurrentJson.Matches += $NewJson.Matches

    #Add the JSONs together
    foreach ($array in @('SummaryAttack','SummaryDefence')) {
        foreach ($p in $NewJson.$array) {


          $pos = (arrFindPlayer ([ref]$CurrentJson.$array) $p.Name)
          if ($pos -lt 0) {
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

          $CurrentJson.$array[$pos].Kills  += $p.Kills
          $CurrentJson.$array[$pos].Death += $p.Death
          $CurrentJson.$array[$pos].TKill  += $p.TKill
          $CurrentJson.$array[$pos].Dmg    += $p.Dmg
          $CurrentJson.$array[$pos].FlagStop += $p.FlagStop
          $CurrentJson.$array[$pos].FlagTake  += $p.FlagTake
          $CurrentJson.$array[$pos].FlagCap   += $p.FlagCap
          $CurrentJson.$array[$pos].FlagTime  = Sum-MinSec $CurrentJson.$array[$pos].FlagTime $p.FlagTime
          $CurrentJson.$array[$pos].Win   += $p.Win
          $CurrentJson.$array[$pos].Loss  += $p.Draw
          $CurrentJson.$array[$pos].Draw  += $p.Loss

          $CurrentJson.$array[$pos].TimePlayed = Sum-MinSec $CurrentJson.$array[$pos].TimePlayed $p.TimePlayed
        }
    }

    foreach ($strTable in @("ClassFragAttack","ClassFragDefence","ClassTimeAttack","ClassTimeDefence")) {
      foreach ($p in $NewJson.$strTable) {
        $pos = (arrFindPlayer-Class ([ref]$CurrentJson.$strTable) $p.Name)
        if ($pos -lt 0) {
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
          $CurrentJson.$strTable[$pos].$class += $p.$class
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
            $timeMins   = $timeplayed[0] + ($timePlayed[1] / 60)
            $player.KPM = '{0:n2}' -f ($player.Kills / $timeMins)
            $player.KD  = '{0:n2}' -f ($player.Kills / $player.Death)
            $player.DPM = '{0:n2}' -f ($player.Dmg / $timeMins)
            $player.Classes    = (Table-ClassInfo ($classTable) $player.Name $player.TimePlayed)
        }
        $x++
    }

    $x = 1
    foreach ($table in @($CurrentJson.ClassFragAttack,$CurrentJson.ClassFragDefence)) {
        foreach ($player in $table) {
            if ($x -eq 1) { $classTable = [ref]$CurrentJson.ClassTimeAttack  }
            else          { $classTable = [ref]$CurrentJson.ClassTimeDefence }


            foreach ($classID in $script:ClassAllowedWithSG) {
                $class = $ClassToStr[$classID]
                if ($player.Kills -gt 0) {
                  $player."KPM$class" = '{0:n0}' -f ($player.$class / ($ClassTable.Value | Where Name -EQ $player.Name).$class / 60)
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
    $htmlBody += $JSON.SummaryAttack | Select-Object Name,KPM,KD,Kills,Death,TKill,Dmg,DPM,FlagCap,FlagTake,FlagTime,FlagStop,Win,Draw,Loss,TimePlayed,Classes | Sort-Object Name | ConvertTo-Html -Fragment
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
}

foreach ($region in @('oceania','north-america','europe')) {
    if ($ForceBatch) { $doBatch = $true  }
    else             { $dobatch = $false } 
    <#switch ($region) {
      #'ALL' { $RegionDateTime = (Get-Date) }
      'north-america' { $RegionDateTime = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,'America/Los_Angeles')) }
      'europe'        { $RegionDateTime = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,'Europe/Dublin')) }
      'oceania'       { $RegionDateTime = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,'Australia/Sydney')) }
      #'INT' { $RegionDateTime = (Get-Date) }
      else  { continue } 
    }#>

    $RegionDateTime = Get-Date

    #Region Day period will be between 6am to 5:59am
    if ($RegionDateTime.Hour -in @(0,1,2,3,4,5)) { $RegionDateTime = $RegionDateTime.AddDays(-1) }
    $strDate = ('{0:yyyy-MM-dd}' -f $RegionDateTime)

    $outDir   = "$PSScriptRoot/_daily/$Region"
    $outFile  = "$outDir/$($region)_DailyStats_$($strDate).json"
    $outHtml  = "$outDir/$($region)_DailyStats_$($strDate).html"
    $batchDir = "$outDir/.batch"
    $newDir   = "$outDir/.new"

    if (!(Test-Path $outDir  )) { New-Item $outDir   -ItemType Directory | Out-Null }
    #if (!(Test-Path $batchDir)) { New-Item $batchDir -ItemType Directory | Out-Null }
    if (!(Test-Path $newDir  )) { New-Item $newDir   -ItemType Directory | Out-Null }

    if ((Get-ChildItem "$newDir/*.json").Length -gt 0) {
      $doBatch = $true
      $batchFiles = (Get-ChildItem "$newDir/*.json")
    } 

    if ($doBatch) {
      foreach ($f in $batchFiles) {
        if (Test-Path -LiteralPath $OutFile) {
          #Add the files
          $outJSON = (processFoStatsJSON -CurrentJson ((Get-Content -LiteralPath $outFile -Raw) | ConvertFrom-Json) -NewJson ((Get-Content -LiteralPath $f -Raw)| ConvertFrom-Json))         
          ($outJSON | ConvertTo-JSON) | Out-File -LiteralPath $outFile
          Copy-Item -LiteralPath $f -Destination $batchDir -Force
          Remove-Item -LiteralPath $f -Force
        } else {
          #Just move the file
          Copy-Item -LiteralPath $f -Destination $batchDir -Force
          Move-Item -LiteralPath $f -Destination $outFile -Force
        }
      }
    }
    if ( $doBatch -or ((Test-Path -LiteralPath $outFile) -and !(Test-Path -LiteralPath $outHtml)) ) {
      #generate HTML
      Generate-DailyStatsHTML -JSON (Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json) | Out-File -LiteralPath $outHtml
    }


} #end region for


