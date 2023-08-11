###
# PS  COMMAND LINE:- & .\FO_stats_v2.ps1 -StatFile 'x:\path\filename.json' [-RoundTime <seconds>] [-TextOnly] [-TextSave] [-NoStatJson]
# WIN COMMAND LINE:- powershell -Command "& .\FO_stats_v2.ps1 -StatFile 'x:\path\filename.json' [-RountTime <seconds>] [-TextOnly] [-TextSave] [-NoStatJson]"
#
# NOTE: StatFile parameter now accepts *.json wildcard to generate many HTMLs, Text/Json stats are ALL STATS COMBINED.
#
# For individual TextJson Only stats for many stat files - i.e. not all games combined.
# PS  *.JSON:- foreach ($f in (gci 'x:\stats\*.json')) { & .\FO_stats_v2.ps1 -StatFile ($f.ToString() -replace '\[','`[' -replace '\]','`]') -TextOnly }
###

param (
  [Parameter(Mandatory = $true)] 
  [string[]]$StatFile,
  [int]   $RoundTime,
  [switch]$TextSave,
  [switch]$NoStatJson,
  [switch]$TextOnly,
  [switch]$OpenHTML
)


# Process input file, make sure it is valid.
$inputFileStr = $StatFile -replace '(?<!`)[\[\]]', '`$&'

if ($inputFileStr -contains '*') { $inputFile = Get-ChildItem $inputFileStr }
elseif (Test-Path $inputFileStr) { $inputFile = @(Get-Item $inputFileStr) }

# If a folder search for all JSON files
if ($inputFile.Count -eq 1 -and (Test-Path $inputFile -PathType Container)) {
  $inputFile = Get-ChildItem $inputFile -Filter '*.json'
}

if ($inputFile.Length -lt 1) { Write-Host "ERROR: No JSON files found at '$inputFileStr'"; return }
if ($inputFile -notmatch '.*\.json$') { Write-Host 'ERROR: Following files are not JSON files...'; ($inputFile -notmatch '.*\.json$') | FT Name | Out-String ; return }

$regExReplaceFix = '[[+*?()\\.]', '\$&'

<# See fo_stats.css
$ccGrey   = '#F1F1F1'
$ccAmber  = '#FFD900'
$ccOrange = '#FFB16C'
$ccGreen  = '#96FF8F'
$ccBlue   = '#87ECFF'
$ccRed    = '#FF8080'
$ccPink   = '#FA4CFF'#>

$ccGrey = 'cellGrey'
$ccAmber = 'cellAmber'
$ccOrange = 'cellOrange'
$ccGreen = 'cellGreen'
$ccBlue = 'rowTeam1'
$ccRed = 'rowTeam2'
$ccPink = 'rowTeamBoth'



# 0        1     2     3      4      5    6      7     8     9     10
$script:ClassToStr = @('World', 'Sco', 'Snp', 'Sold', 'Demo', 'Med', 'HwG', 'Pyro', 'Spy', 'Eng', 'SG')
$script:ClassAllowedStr = @('Sco', 'Sold', 'Demo', 'Med', 'HwG', 'Pyro', 'Spy', 'Eng')
$script:ClassAllowedWithSGStr = @('Sco', 'Sold', 'Demo', 'Med', 'HwG', 'Pyro', 'Spy', 'Eng', 'SG')
$script:ClassAllowed = @(1, 3, 4, 5, 6, 7, 8, 9)
$script:ClassAllowedwithSG = @(1, 3, 4, 5, 6, 7, 8, 9, 10)
$script:TeamToColor = @('Civ', 'Blue', 'Red', 'Yellow', 'Green')

function getPlayerClasses {
  param ($Round, $Player, $TimePlayed)
  
  $pos = arrFindPlayer -Table ([ref]$arrPlayerTable) -Player $Player -Round $Round
  $filter = ($arrClassTimeTable  |  Where-Object { $_.Name -eq $Player -and ($Round -lt 1 -or $_.Round -eq $Round) })                
  $classes = ($filter | % { $_.PSObject.Properties | Where Name -in $ClassAllowedStr | Where Value -gt 5 } | % { $_.Name }) -join ','
  
  #$hover = ($classes -split ',' | % { "<b>$_</b>: $(Format-MinSec $filter.$_)" }) -join '<br>'
  #return "$classes<span class=`"ClassHoverText$($arrPlayerTable[$pos].Team)`">$hover</span> "
  return $classes
}

function nullValueColorCode {
  switch ($args[0]) {
    '' { $ccGrey }
    '0' { $ccGrey }
    default { $args[1] }
  }
}

function nullValueAsBlank {
  if ($args[0] -match '^0+%?$') {
    return ''
  }
  else {
    $args[0]
  }
}

function teamColorCode {
  switch ($args[0]) {
    '1' { 'rowTeam1' }
    '2' { 'rowTeam2' }
    default { 'rowTeamBoth' } 
  }
}

function teamColorCodeByName {
  foreach ($name in ($args[0] -split ',')) {
    $tm = $arrteam.$name
    if ($lasttm -and $lasttm -ne $tm) { return 'rowTeamBoth' }
    $lasttm = $tm
  }
  return "rowTeam$tm"
}

<## See fo_stats.css 
#Friendly fire is bad
function actionColorCode ($arrTeam, $p1, $p2) {
    #check if action is no Friendly fire
    if ($p1 -eq $p2) {
      $ccAmber #yellow
    } elseif ($arrTeam.$p1 -eq $arrTeam.$p2) {
      #Friendly fire
      $ccOrange #orange
    } else {
      $ccGreen #green
    }
}#>


function actionColorCode ($arrTeam, $p1, $p2) {
  #check if action is no Friendly fire
  if ($p1 -eq $p2) {
    'cellAmber'
  }
  elseif ($arrTeam.$p1 -eq $arrTeam.$p2) {
    #Friendly fire
    'cellOrange' #orange
  }
  else {
    'cellGreen' #green
  }
}

function timeRnd-RoundDown {
  # p1 = $time , $p2 = roundendtime
  if ($args[0] / 60 -lt 0.4) {
    if ($args[0] -lt $args[1]) { '0' }
    else { $args[1] }
  }
  else { $time }
}

function Format-MinSec {
  param($sec)
  if (!$sec) { return }
  $ts = (New-TimeSpan -Seconds $sec)
  $mins = ($ts.Days * 24 + $ts.Hours) * 60 + $ts.minutes
  return "$($mins):$("{0:d2}" -f $ts.Seconds)"
}

function Table-ClassInfo {
  param([ref]$Table, $Name, $TimePlayed)
  $out = ''
  $classlist = @{}
  foreach ($p in [array]$Table.Value) {
    if ($p.Name -eq $Name) {
      foreach ($class in $ClassAllowed) {
        $strClass = $ClassToStr[$class]
        $time = $p.($strClass)

        if ($time -notin 0, '', $null) {
          $classlist.$strClass = ($time / $TimePlayed)
        }
      }

      foreach ($c in ($classlist.GetEnumerator() | Sort-Object Value -Descending)) {        
        $out += "$(($c.Name).PadRight(4)) $(('{0:P0}' -f $c.Value).PadLeft(3))|"
      }
      
      return $out -replace '\|$', ''
    }
  }
}

# Convert weapon names into friendly short names
function weapSN {
  
  switch ($args[0]) {
    '' { 'NULL' }
    #common
    'info_tfgoal' { 'laser' }
    'supershotgun' { 'ssg' }
    'shotgun' { 'sg' }
    'normalgrenade' { 'hgren' }
    'grentimer' { 'hgren' }
    'axe' { 'axe' }
    'spike' { 'ng' }
    'nailgun' { 'ng' }
    
    #7/2/23 - New inflictor/weaps??
    'grenade grenadegrenade' { 'hgren' }
    'red grenadegrenade' { 'gl' }
    'mirv grenadegrenade' { 'mirv' }
    'mirvlet grenadegrenade' { 'mirv' }
    'napalm grenadegrenade' { 'napalm' }
    'shock grenadegrenade' { 'shock' }
    'emp grenadegrenade' { 'emp' }
    'flash grenadegrenade' { 'flash' }

    #23/2/23 - Newby changes v2
    'incendiarylauncher' { 'incen' }
    'napalmgrenade' { 'napalm' }
    'glgrenade' { 'gl' }

    #scout
    'flashgrenade' { 'flash' }
    
    #sold
    'proj_rocket' { 'rl' }
    'rocketlauncher' { 'rl' }
    'shockgrenade' { 'shock' }

    #demo 
    'detpack' { 'detp' }
    'pipebomb' { 'pipe' }
    'pipebomblauncher' { 'pipe' }
    'grenade' { 'gl' }
    'grenadelauncher' { 'gl' }
    'mirvsinglegrenade' { 'mirv' }
    'mirvgrenade' { 'mirv' }

    #medic
    'medikit' { 'bio' }
    'superspike' { 'sng' }
    'supernailgun' { 'sng' }

    #hwg
    'proj_bullet' { 'cann' }
    'assaultcannon' { 'cann' }

    #pyro
    'pyro_rocket' { 'incen' }
    'incendiary' { 'incen' }
    'flamethrower' { 'flame' }
    'fire' { 'fire' }
    'flamerflame' { 'flame' }
    
    #spy - knife
    'proj_tranq' { 'tranq' }
    'tranquilizer' { 'tranq' }

    #eng
    'spanner' { 'spann' }
    'empgrenade' { 'emp' }
    'ammobox' { 'emp' }
    'sentrygun' { 'sent' }
    'railslug' { 'rail' }
    'railgun' { 'rail' }
    'building_dispenser' { 'disp' }
    'building_sentrygun' { 'sent' }
    'build_timer' { 'sent' }

    #remove underscore to avoid token key issues.
    default { $args[0] -replace '[_ ]', '-' }
  }
}

#Summary table funcitons
function attOrDef {
  if ($args[0] -lt 1 -or $args[0] -gt 2) { return '' }
  elseif ($args[0] -eq $args[1]) { return 'Att' }
  else { return 'Def' } 
}
function arrFindPlayer {
  param( 
    [ref]$Table,
    [string]$Player,
    [int]$Round
  )
  
  process {
    $count = 0
    foreach ($i in $Table.Value) {
      if ($i.Name -eq $Player -and (!$Round -or $i.Round -eq $Round)) {
        return $count
      }
      $count++
    }
    return -1
  }
}

function arrSummaryTable-UpdatePlayer {
  param( 
    [ref]$table,
    [string]$player,
    [int]$kills,
    [int]$death,
    [int]$tkill
  )

  process {
    $playerpos = (arrFindPlayer -Table $table -Player $player)

    #if player round update, else setup object
    if ($playerpos -lt 0) {
      $obj = [PSCustomObject]@{
        Name       = $player
        KPM        = $null
        KD         = $null
        Kills      = 0
        Death      = 0
        TKill      = 0
        Dmg        = 0
        DPM        = $null
        FlagCap    = 0
        FlagTake   = 0
        FlagTime   = 0
        FlagStop   = 0
        Win        = 0
        Draw       = 0
        Loss       = 0
        TimePlayed = 0
        Classes    = ''
      }
      $playerpos = $table.Value.Length
      $table.Value += $obj
    }

    ($table.Value)[$playerpos].Kills += $kills
    ($table.Value)[$playerpos].Death += $death
    ($table.Value)[$playerpos].TKill += $tkill
  }
}

function arrSummaryTable-SetPlayerProperty {
  param( 
    [ref]$table,
    [string]$player,
    [string]$property,
    $value
  )

  process {
    if (!$Value) { $Value = 1 }
    $playerpos = (arrFindPlayer -Table $table -Player $player)
    if ($playerpos -gt -1 -and $value -gt 0) { ($table.Value)[$playerpos].$property += $value }
  }
}

function arrClassTable-UpdatePlayer {
  param( 
    [ref]$Table,
    [string]$Player,
    [string]$Class,
    [int]$Round,
    $Value
  )

  process {
    if ($Class -in $ClassAllowed) { $Class = $ClassToStr[$Class] }
    if ($Class -notin $ClassAllowedWithSGStr) { return }
    
    if ($round) { $playerpos = (arrFindPlayer -Table $Table -Player $Player -Round $round) }
    else { $playerpos = (arrFindPlayer -Table $Table -Player $Player) }

    #Setup object if plyaer not found
    if ($playerpos -lt 0) {
      $obj = [PSCustomObject]@{
        Name  = $Player
        Round = 0
        Sco   = 0
        Sold  = 0
        Demo  = 0
        Med   = 0
        HwG   = 0
        Pyro  = 0
        Spy   = 0
        Eng   = 0
        SG    = 0
      }

      if ($round) { $obj.Round = $round }
      $playerpos = $table.Value.Length
      $table.Value += $obj
    } 
    $table.Value[$playerpos].$Class += $Value
  }
}

function arrClassTable-GetPlayerTotal {
  param([pscustomobject]$player)

  return ($player.Sco + $player.Sold + $player.Demo + $player.Med + $player.Hwg + $player.Pyro + $player.Spy + $player.Eng + $player.SG)
}

function arrClassTable-FindPlayerTotal {
  param([string]$player, [int]$rnd)

  $pos = (arrFindPlayer -Table ([ref]$arrClassTimeTable) -Player $player -Round $rnd)

  return ($arrClassTimeTable[$pos].Sco + $arrClassTimeTable[$pos].Sold + $arrClassTimeTable[$pos].Demo `
        + $arrClassTimeTable[$pos].Med + $arrClassTimeTable[$pos].Hwg + $arrClassTimeTable[$pos].Pyro `
        + $arrClassTimeTable[$pos].Spy + $arrClassTimeTable[$pos].Eng + $arrClassTimeTable[$pos].SG)
}

function arrFindPlayer-WeaponTable {
  param( [string]$Name, $Round, $PlayerClass, [string]$Weapon, $Class )
  
  $count = 0
  foreach ($p in $script:arrWeaponTable) {
    if ($p.Name -eq $Name -and $p.Round -eq $Round -and ($PlayerClass -and $p.PlayerClass -eq $PlayerClass) -and $p.Weapon -eq $Weapon -and $p.Class -eq $Class) {
      return $count
    }
    $count += 1
  }
  return -1
}

function arrWeaponTable-UpdatePlayer {
  param( [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$PlayerClass,
    [Parameter(Mandatory = $true)]        $Round,
    [Parameter(Mandatory = $true)][string]$Weapon,
    [Parameter(Mandatory = $true)]        $Class, 
    [Parameter(Mandatory = $true)][string]$Property, 
    $Value, 
    [switch]$Increment
  )

  $pos = arrFindPlayer-WeaponTable -Name $Name -Round $Round -Weapon $Weapon -Class $Class -PlayerClass $PlayerClass
  if ($pos -lt 0) {
    $obj = [pscustomobject]@{ Name = $Name
      PlayerClass                  = $PlayerClass
      Team                         = ''
      Round                        = [int]$Round
      Weapon                       = $Weapon
      Class                        = [int]$Class
      Kills                        = 0
      Death                        = 0
      Dmg                          = 0
      DmgTaken                     = 0
      AttackCount                  = 0
      DmgCount                     = 0 
    }

    $script:arrWeaponTable += $obj
    $pos = $script:arrWeaponTable.Length - 1 
  }
  
  if ($Increment -and !$Value) { $Value = [int]1 }
  if ($Increment) { $script:arrWeaponTable[$pos].$Property += [int]$Value }
  else { $script:arrWeaponTable[$pos].$Property = $Value }
}


function arrPlayerTable-UpdatePlayer {
  param( [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)]        $Round,
    [Parameter(Mandatory = $true)][string]$Property, 
    $Value, 
    [switch]$Increment
  )

  $pos = arrFindPlayer -Table ([ref]$arrPlayerTable) -Player $Name -Round $Round
  if ($pos -lt 0) {
    $obj = $obj = [pscustomobject]@{ Name = $Name
      Team                                = ''
      Round                               = [int]$Round
      Kills                               = 0
      Death                               = 0
      TKill                               = 0
      Dmg                                 = 0
      DmgTaken                            = 0
      DmgTeam                             = 0
      FlagCap                             = 0
      FlagDrop                            = 0
      FlagTake                            = 0
      FlagThrow                           = 0
      FlagTime                            = 0
      FlagStop                            = 0
    }

    $script:arrPlayerTable += $obj
    $pos = $script:arrPlayerTable.Length - 1 
  }
  
  if ($Increment -and !$Value) { $Value = [int]1 }
  if ($Increment) { $script:arrPlayerTable[$pos].$Property += $Value }
  else { $script:arrPlayerTable[$pos].$Property = $Value }
}
#end Summary table functions

function GenerateVersusHtmlInnerTable {
  param([ref]$VersusTable, $Player, $Round)

  switch ($Round) {
    '1' { $refTeam = [ref]$arrTeamRnd1 }
    '2' { $refTeam = [ref]$arrTeamRnd2 }
    default { $refTeam = [ref]$arrTeam }
  }

  $tbl = ''
  $count2 = 0
  foreach ($o in $playerList) {
    $key = "$($player)_$($o)"
    $kills = $VersusTable.Value.$key
    $killsOpponent = $VersusTable.Value."$($o)_$($player)"
    if ($kills -eq '' -or $kills -lt 1) { $kills = 0 }
    if ($killsOpponent -eq '' -or $killsOpponent -lt 1) { $killsOpponent = 0 }

    if ($o -eq $player) {
      #$hoverText = "<b>Self-affliction</b><br>$player`: $kills"
      $colour = 'Amber'
    }
    elseif ($refTeam.Value.$Player -eq $refTeam.Value.$o) {
      #$hoverText = "<b>Friendly fire</b><br> $player`: $kills <br>$o`: $killsOpponent"
      $colour = 'Orange'
    }
    else {
      #$hoverText = "<b>Head to Head</b><br>$player`: $kills <br>$o`: $killsOpponent"
      $colour = 'Green'
    }

    $tbl += "<td class=`"$(actionColorCode $refTeam.Value $player $o)`">$($kills)</td>"
    # Java Scirpt implemented
    #$tbl += "<td class=`"$(actionColorCode $refTeam.Value $player $o)`"><div class=`"VersusHover`">$($kills)<span class=`"VersusHoverText$colour`">$hoverText</span></div>
    #</td>"
    if ($player -ne $o) { 
      $subtotal[$count2] = $kills + $subtotal[$count2]
    }
    $count2 += 1
  }

  return $tbl
}

function GenerateSummaryHtmlTable {
  param([switch]$Attack, [switch]$Defence)
  
  $count = 1
  $tableHeader = "<table id=`"summary$(if ($Defence) { 'Defence' } else { 'Attack' })`" style=""width:600px;display:inline-table""><thead><tr><th>#</th><th>Player</th><th>Team</th><th title='Kills per minute'>KPM</th><th title='Kill-death ratio'>K/D</th><th title='Kills'>Kills</th><th title='Deaths'>Dth</th><th title='Team kills'>TK</h><th title='Damage'>Dmg</th><th title='Damage per miunte'>DPM</h>"
  if ($Attack) { $tableHeader += "<th title='Flag Captures'>Caps</th><th title='Flag pickups'>Take</th><th title='Time flag held'>Carry</th>" }
  else { $tableHeader += "<th title='Killed flag carrier'>FlagStop</th>" }
  $tableHeader += "<th>Time</th>"
  $table = ''
  $subtotal = @(1..8 | foreach { 0 })

  foreach ($p in $playerList) {
    if ($Defence) { 
      if ($arrTeam.$p -eq '1&2') { 
        $table += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>None</td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>"
        $count += 1
        continue 
      }
      elseif ($arrTeam.$p -eq '2&1') {
        $rnds = @(1, 2)
      }
      else {
        $rnds = if ($arrTeam.$p -match '^.*2$') { '1' } else { '2' }
      }
    }
    else { 
      if ($arrTeam.$p -eq '2&1') { 
        $table += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>None</td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>"
        $count += 1
        continue 
      }
      elseif ($arrTeam.$p -eq '1&2') {
        $rnds = @(1, 2)
      }
      else {
        $rnds = if ($arrTeam.$p -match '^1.*$') { '1' } else { '2' }
      }
    } 
  
    foreach ($rnd in $rnds) {      
      $player = ($arrPlayerTable | Where-Object { $_.Name -EQ $p -and (($_.Team -match '^1' -and $_.Round -eq $rnd) -or ($_.Team -match '^2' -and $_.Round -eq $rnd)) })
      if ($lastPlayer -ne $null -and $lastPlayer -eq $player.Name) { $count = $count - 1 }

      $team = (Get-Variable "arrTeamRnd$rnd").Value.$p

      if ($player -eq $null) { 
        $table += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($team)</td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>"
        if ($Attack) { $table += "<td></td><td></td>" }
        $table += "</tr>"
        $count++
        continue 
      }

      $kills = $player.Kills
      $timePlayed = arrClassTable-GetPlayerTotal ($arrClassTimeTable | Where-Object { $_.Name -eq $player.Name -and $_.Round -eq $player.Round })
            
      $kpm = $kills / ($timePlayed / 60)
      $death = $player.Death
      $kd = if ($death) { $kills / $death } else { '-' }
      $tkill = $player.TKill
      $dmg = $player.Dmg
      $dpm = $dmg / ($timePlayed / 60)

      $flagCap = $player.FlagCap
      $flagTake = $player.FlagTake
      $flagTime = $player.FlagTime
      $flagStop = $player.FlagStop

      $table += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($team)</td><td>$('{0:0.00}' -f $kpm)</td><td>$('{0:0.00}' -f $kd)</td><td>$($kills)</td><td>$($death)</td><td>$($tkill)</td><td>$($dmg)</td><td>$('{0:0}' -f $dpm)</td>"
    
      if ($Attack) { $table += "<td>$($flagCap)</td><td>$($flagTake)</td><td>$(Format-MinSec $flagTime)</td>" }
      else { $table += "<td>$($flagStop)</td>" }
      
      $table += "<td>$(Format-MinSec ([int]$timePlayed))</td>"
      #$table += "<td><div class=`"ClassHover`">$(getPlayerClasses -Round $rnd -Player $p)</div></td>"
      $table += "<td id=`"ClassColumn`">$(getPlayerClasses -Round $rnd -Player $p)</td>"
      $table += "</tr>`n"
    
      $subtotal[0] += $kills; $subtotal[1] += $death; $subtotal[2] += $tkill; $subtotal[3] += $dmg; $subtotal[4] = ''
      if ($Attack) {  
        $subtotal[5] += $flagCap; $subtotal[6] += $flagTake; $subtotal[7] += $FlagTime
      }
      else {
        $subtotal[5] += $flagStop; $subtotal[6] = $null; $subtotal[7] = $null
      }
      $count += 1
      $lastPlayer = $player.Name
    }
  }

  $tableHeader += "<th id=`"ClassColumn`">Classes</th></tr></thead>`n"
  $table += '<tfoot><tr id="TotalRow"><td colspan=5 align=right padding=2px><b>Total:</b></td>'

  if ($Attack) { $subtotal[7] = Format-MinSec $subtotal[7] }
  foreach ($st in $subtotal) { if ($st -eq $null) { break }; $table += "<td>$($st)</td>" }
  $table += '</tr></tfoot>'

  $ret = $tableHeader      
  $ret += $table            
  $ret += "</table>`n"

  return $ret
}


function GenerateFragHtmlTable {
  param([string]$Round)

  switch ($Round) {
    '1' { $refTeam = [ref]$arrTeamRnd1; $refVersus = [ref]$arrFragVersusRnd1 }
    '2' { $refTeam = [ref]$arrTeamRnd2; $refVersus = [ref]$arrFragVersusRnd2 }
    default { $refTeam = [ref]$arrTeam; $refVersus = [ref]$arrFragVersus }
  }
  
  $count = 1
  $tableHeader = "<table id=`"fragRound$Round`" style=""width:600px;display:inline-table""><thead><tr><th>#</th><th>Player</th><th>Team</th><th title='Kills'>Kills</th><th title='Deaths'>Dth</th><th title='Team kills'>TK</h>"
  $table = ''
  $subtotal = @($playerList | foreach { 0 } )

  foreach ($p in $playerList) {
    $tableHeader += "<th title='$($p)'>$($count)</th>"
    $team = $refTeam.Value.$p
    #$team  = ($arrPlayerTable | Where { $_.Name -eq $p -and (!$Round -or $_.Round -eq $Round) } `
    #                          | %{ $_.Team} | Sort-Object -Unique) -join '&'
    $kills = ($arrPlayerTable | Where { $_.Name -EQ $p -and (!$Round -or $_.Round -eq $Round) } | Measure-Object Kills -Sum).Sum
    $death = ($arrPlayerTable | Where { $_.Name -EQ $p -and (!$Round -or $_.Round -eq $Round) } | Measure-Object Death -Sum).Sum
    $tkill = ($arrPlayerTable | Where { $_.Name -EQ $p -and (!$Round -or $_.Round -eq $Round) } | Measure-Object TKill -Sum).Sum
    
    $table += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($team)</td><td>$($kills)</td><td>$($death)</td><td>$($tkill)</td>"

    $table += GenerateVersusHtmlInnerTable -VersusTable $refVersus -Player $p -Round $Round

    #$table += "<td><div class=`"ClassHover`">$(getPlayerClasses -Round $Round -Player $p)</div></td>"
    $table += "<td id=`"ClassColumn`">$(getPlayerClasses -Round $Round -Player $p)</td>"
    $table += "</tr>`n"
    
    $count += 1 
  }

  $tableHeader += "<th id=`"ClassColumn`">Classes</th></tr></thead>`n"

  $table += '<tfoot><tr id="TotalRow"><td colspan=6 align=right padding=2px><b>Total:</b></td>'
  foreach ($st in $subtotal) { $table += "<td>$($st)</td>" }
  $table += '</tr></tfoot>'
  $ret = $tableHeader      
  $ret += $table            
  $ret += "</table>`n"

  return $ret
}


function GenerateDmgHtmlTable {
  param([string]$Round)

  switch ($Round) {
    '1' { $refTeam = [ref]$arrTeamRnd1; $refVersus = [ref]$arrDmgVersusRnd1 }
    '2' { $refTeam = [ref]$arrTeamRnd2; $refVersus = [ref]$arrDmgVersusRnd2 }
    default { $refTeam = [ref]$arrTeam; $refVersus = [ref]$arrDmgVersus }
  }

  $count = 1
  $tableHeader = "<table id=`"damageRound$Round`" style=""width:700px;display:inline-table""><thead><tr><th>#</th><th>Player</th><th>Team</th><th title='Damage'>Dmg</th>"
  $table = ''
  $subtotal = @($playerList | foreach { 0 } )

  foreach ($p in $playerList) {
    $tableHeader += "<th>$($count)</th>"
    $dmg = ($arrPlayerTable | Where { $_.Name -EQ $p -and (!$Round -or $_.Round -eq $Round) } | Measure-Object Dmg -Sum).Sum
    $table += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($refTeam.Value.$p)</td><td>$($dmg)</td>"

    $table += GenerateVersusHtmlInnerTable -VersusTable $refVersus -Player $p -Round $Round

    #$table += "<td><div class=`"ClassHover`">$(getPlayerClasses -Round $Round -Player $p)</div></td>"
    $table += "<td id=`"ClassColumn`">$(getPlayerClasses -Round $Round -Player $p)</td>"
    $table += "</tr>`n"
    
    $count += 1 
  }

  $tableHeader += "<th id=`"ClassColumn`">Classes</th></tr></thead>`n"

  $table += '<tfoot><tr id="TotalRow"><td colspan=4 align=right padding=2px><b>Total:</b><i> *minus self-dmg</i></td>'
  foreach ($st in $subtotal) { $table += "<td>$($st)</td>" }
  $table += '</tr></tfoot>'
  $ret += $tableHeader   
  $ret += $table         
  $ret += "</table>`n"
  return $ret  
}

#Text Based stats initialized - not reset after each file
$script:arrSummaryAttTable = @()
$script:arrSummaryDefTable = @()
$script:arrClassTimeAttTable = @()
$script:arrClassTimeDefTable = @()
$script:arrClassFragAttTable = @()
$script:arrClassFragDefTable = @()
$script:arrResultTable = @()

$jsonFileCount = 0
foreach ($jsonFile in $inputFile) {
  # Enure JSON files with [ at start and ] (not added in log files)
  $txt = (Get-Content ($jsonFile.FullName -replace '\[', '`[' -replace '\]', '`]'))
  if ($txt[0] -notmatch '^\[.*') {
    $txt[0] = "[$($txt[0])"
    $txt[$txt.count - 1] = "$($txt[$txt.count - 1])]"
    $txt | Out-File -LiteralPath ($jsonFile.FullName) -Encoding utf8
  }
  Remove-Variable txt

  if (!($jsonFile.Exists)) { Write-Host "ERROR: File not found - $($jsonFile.FullName)"; return }

  # Out file with same-name.html - remove pesky [] braces.
  $outFileStr = ($jsonFile.FullName) -replace '\.json$', ''  #-replace '`?(\[|\])','')
  $json = ((Get-Content -Path ($jsonFile.FullName -replace '\[', '`[' -replace '\]', '`]') -Raw) | ConvertFrom-Json)
  $jsonFileCount++
  Write-Host "Input File$(if ($inputFile.Length -gt 1) { " ($jsonFileCount/$($inputFile.Length))" } ): $($jsonFile.Name)"

  #Check for end round time (seconds) - default to 600secs (10mins)
  if ($RoundTime -is [int] -and $RoundTime -gt 0) { $round1EndTime = $RoundTime }
  else { $script:round1EndTime = 600 }

  # Leaving as HashTable, used for HTML display only 
  $script:arrFragVersus = @{}
  $script:arrFragVersusRnd1 = @{}
  $script:arrFragVersusRnd2 = @{}
  $script:arrDmgVersus = @{}
  $script:arrDmgVersusRnd1 = @{}
  $script:arrDmgVersusRnd2 = @{}
  
  # Used for some HTML->Awards only
  $script:arrKilledClass = @{}
  $script:arrKilledClassRnd1 = @{}
  $script:arrKilledClassRnd2 = @{}
 
  #Json parsing helper - _currentClass and _lastChange
  $script:arrTimeTrack = @{}
  
  # Tracking teams via below and then updating arrPlayerTable after JSON parsing -Worth changing?
  $script:arrTeam = @{}
  $script:arrTeamRnd1 = @{}
  $script:arrTeamRnd2 = @{}
  
  $script:arrResult = @{}
  
  # Leaving as HashTable, used for HTML display only 
  $script:arrFragMin = @{}
  $script:arrDmgMin = @{} 
  $script:arrDeathMin = @{} 
  $script:arrFlagCapMin = @{}
  $script:arrFlagDropMin = @{}
  $script:arrFlagTookMin = @{}  
  $script:arrFlagThrowMin = @{}
  $script:arrFlagStopMin = @{}

  # Table Arrays - PS Format-Table friendly
  $script:arrAttackDmgTracker = @{} #Json parsing helper (AttackCount + Dmg Count)
  $script:arrWeaponTable = @()  # Filtering on PlayerClass for Class Kills, use measure-object
  $script:arrPlayerTable = @()
  $script:arrClassTimeTable = @()

  ###
  # Process the JSON into above arrays (created 'Script' to be readable by all functions)
  # keys: Frags/playername, Versus.player_enemy, Classes/player_class#, Weapons/player_weapon
  ###
  $script:round = 1
  $script:timeBlock = 1
  $prevItem = ''

  ForEach ($item in $json) {
    $type = $item.type
    $kind = $item.kind

    #Remove any underscores for _ tokens used in Keys 
    $player = $item.player -replace '[_,]', '.' -replace '\s$', '.' -replace '\$', '§' -replace '\^([b0-9]{0,1}|&[0-9a-fA-F]{2}|x[0-9]{3})', ''  -replace '\*','°'
    $target = $item.target -replace '[_,]', '.' -replace '\s$', '.' -replace '\$', '§' -replace '\^([b0-9]{0,1}|&[0-9a-fA-F]{2}|x[0-9]{3})', ''  -replace '\*','°'
    $prevPlayer = $prevItem.player -replace '[_,]', '.' -replace '\s$', '.' -replace '\$', '§' -replace '\^([b0-9]{0,1}|&[0-9a-fA-F]{2}|x[0-9]{3})', ''  -replace '\*','°'
    $prevAttacker = $prevItem.attacker -replace '[_,]', '.' -replace '\s$', '.' -replace '\$', '§' -replace '\^([b0-9]{0,1}|&[0-9a-fA-F]{2}|x[0-9]{3})', ''  -replace '\*','°'

    $p_team = $item.playerTeam
    $t_team = $item.targetTeam
    $class = $item.playerClass
    $classNoSG = $class -replace '10', '9'
    $t_class = $item.targetClass
    $dmg = [math]::Round($item.damage, 0)
    #Shorten and fix multiple names on weapons  
    $weap = (weapSN $item.inflictor)

    #Setup time blocks for per minute scoring
    $time = $item.time
    if ($time -notin '', $null -and [math]::Ceiling($time / 60) -gt $timeBlock) {
      #new time block found, update the time block
      $timeBlock = [math]::Ceiling($time / 60)
    }

    ###
    # Fix Stupid stuff missing from logs due to 3rd Party events - e.g. Buildings and Gas
    ###


    if ($round -eq 1) { $teamRound = [ref]$arrTeamRnd1 }
    else              { $teamRound = [ref]$arrTeamRnd2 }

    #try fix building kills/deaths
    if ($t_class -eq 0 -and $target -in '', 'build.timer' -and $weap -ne 'worldSpawn') {      
      $potentialEng = $arrTimeTrack.keys -match '.*_currentClass$'
      $potentialEng = $potentialEng | foreach { if ($arrTimeTrack.$_ -eq 9) { ($_ -split '_')[0] } }

      # If only 1 eng found fix it, else forget it
      if ($potentialEng -ne $null -and $potentialEng.Count -eq 1 ) {
        $target = ($potentialEng -split '_')[0]
        $t_class = 10
      }
      else { continue }
    }          
    elseif ($weap -eq 'sent') { $class = 10 }
    # Do this before Keys are made# dodgey... Try find out who a gas grenade owner is
    elseif ($class -eq '8' -and $weap -eq 'worldspawn') { 
      if ($type -in 'damageDone', 'kill') {
        $potentialSpies = $arrTimeTrack.keys -match '.*_currentClass$'
        $potentialSpies = $potentialSpies | foreach { if ($arrTimeTrack.$_ -eq 8 -and $teamRound.Value.$_ -eq $team) { ($_ -split '_')[0] } }

        # If only 1 spy found fix it, else forget it
        if ($potentialSpies.Count -eq 1 -and $potentialSpies -notin '', $null) { 
          $player = ($potentialSpies -split '_')[0]
          $weap = 'gas'
        }
        else { continue }
      } 
    }

    # add -ff to weap for friendly-fire
    if ($p_team -and $t_team -and $p_team -eq $t_team -and $weap -ne 'laser') { $weap += '-ff' }

    # change weapon to suidcide for self kills
    if ($player -and $player -eq $target) { $weap = 'suicide' }
    
    $key = "$($player)_$($target)"
    $keyTime = "$($timeBlock)_$($player)"
    #$keyTimeT  = "$($timeBlock)_$($target)"
    $keyClassK = "$($player)_$($class)_$($t_class)"
    $keyWeap = "$($player)_$($class)_$($weap)"
    

    # 19/12/21 New Attack/DmgDone stats in object/array format for PS Tables.
    if ($type -in 'attack', 'damageDone' -and $player -and $weap -and $class -gt 0 `
        -and ($type -eq 'attack' -or $p_team -ne $t_team -or $player -ne $target)) { 

      switch ($type) {
        'attack' {
          if ($arrAttackDmgTracker.$keyWeap -eq -1) {
            # damageDone registered before attack
            $arrAttackDmgTracker.Remove($keyWeap)
          }
          elseif ($arrAttackDmgTracker.$keyWeap -gt 0) {
            # attack registered - no dmg done found since
            $arrAttackDmgTracker.Remove($keyWeap)
          }
          arrWeaponTable-UpdatePlayer -Name $player -PlayerClass $class -Round $round -Weapon $weap -Class $class -Property 'AttackCount' -Increment
        }
        'damageDone' {
          <# To avoid multi-hits: No item existing = No DmgCount added #>
          if ($p_team -ne $t_team) {
            if (!$arrAttackDmgTracker.$keyWeap) { 
              #Damage not registered, no attack yet found
              $arrAttackDmgTracker.$keyWeap = -1
              arrWeaponTable-UpdatePlayer -Name $player -PlayerClass $class -Round $round -Weapon $weap -Class $class -Property 'DmgCount'   -Increment
            }
            elseif (!$arrAttackDmgTracker.$keyWeap -gt 0) {
              #Attack has been registered prior to damangeDone
              arrWeaponTable-UpdatePlayer -Name $player -PlayerClass $class -Round $round -Weapon $weap -Class $class -Property 'DmgCount'   -Increment
              $arrAttackDmgTracker.Remove($keyWeap) 
            }
          }
        }
      }
    }
    
    #Round tracking
    #if (($class -eq '0' -and $player -eq 'world' -and $p_team -eq '0' -and $weap -eq 'worldspawn' -and $time -ge $round1EndTime) -and $round -le 1) {    #(($kind -eq 'enemy' -and ..)
    if ($time -gt $round1EndTime -and $round -lt 2) { 
      $round += 1
      $prevItem = '-1'
      
      if ($arrTrackTime.flagPlayer -notin $null, '') {
        arrPlayerTable-UpdatePlayer -Name $arrTrackTime.flagPlayer -Round $round -Property 'FlagTime' -Value ($round1EndTime - $arrTimeTrack.flagTook) -Increment
        $arrTrackTime.flagTook = 0
        $arrTrackTime.flagPlayer = ''
      }

      #Finalise Rnd1 Class times from the tracker.
      foreach ($p in $arrTeam.Keys) {
        if ($arrTimeTrack."$($p)_currentClass" -in '',$null) { continue }

        $lastChangeDiff = $round1EndTime - $arrTimeTrack."$($p)_lastChange"
        arrClassTable-UpdatePlayer -Table ([ref]$arrClassTimeTable) -Player $p -Class $arrTimeTrack."$($p)_currentClass" -Round 1 `
          -Value ($lastChangeDiff) -Increment

        if ($lastChangeDiff -le 20) {
          $arrTimeTrack."$($p)_endClassRnd1" = $arrTimeTrack."$($p)_previousClass"
        }
        $arrTimeTrack."$($p)_lastChange" = $round1EndTime
      }
    }
    else {      
      if ($type -eq 'playerStart') {
        $arrTimeTrack."$($player)_currentClass"  = '-1'
        $arrTimeTrack."$($player)_previousClass" = '-1'
        $arrTimeTrack."$($player)_lastChange" = $time
      } #elseif ($type -eq 'changeClass' -and $item.nextClass -ne 0)  { continue }

      # Class tracking - Player and Target
      foreach ($pc in @(@($player, $classNoSG), @($target, $t_class -replace '10', '9'))) {
        if ($pc[0] -match '^(\s)*$') { continue }
        
        if ($round -eq 2 -and $arrTimeTrack."$($pc[0])_lastChange" -in '',$null -and $time -lt ($round1EndTime+20)) {
          $arrTimeTrack."$($pc[0])_previousClass" = $arrTimeTrack."$($pc[0])_currentClass"
          $arrTimeTrack."$($pc[0])_currentClass" = '-1'
          $arrTimeTrack."$($pc[0])_lastChange" = $round1EndTime
        }

        #This is making Rnd1 class bleed to Rnd2...
        #if ($type -eq 'changeClass') {  $currentClass = $class; $class = $item.nextClass; $class; $currentClass }       
        $lastChange = $arrTimeTrack."$($pc[0])_lastChange"	 
        if ($lastChange -in '', $null) { 
          if ((($round1EndTime * $round) - $round1EndTime + $time) -lt 30) { 
            $lastChange = ($round1EndTime * $round) - $round1EndTime
          }
          else { $lastChange = $time }
        }
      
        $lastChangeDiff = $time - $lastChange    

        $currentClass = $arrTimeTrack."$($pc[0])_currentClass"
        if ($type -eq 'changeClass')  { $newClass = $item.nextClass; $oldClass = $pc[1] } 
        else                          { $newClass = $pc[1]         ; $oldClass = $currentClass }

        if ($pc[1] -in $ClassAllowed -and $currentClass -ne $newClass) { 
          if ($currentClass -match '^(\s*|-1)$') { $currentClass = $pc[1] }

          #Record time 
          if ($lastChangeDiff -gt 0) {
            arrClassTable-UpdatePlayer -Table ([ref]$arrClassTimeTable) -Player $pc[0] -Class $currentClass -Round $round -Value $lastChangeDiff -Increment 
          }
    
          #Update tracker after stuff is tallied
          $arrTimeTrack."$($pc[0])_previousClass" = $oldClass
          $arrTimeTrack."$($pc[0])_currentClass"  = $newClass
          $arrTimeTrack."$($pc[0])_lastChange" = $time
        }

        if ($type -eq 'changeClass' -and $newClass -eq 0) { 
          $arrTimeTrack."$($pc[0])_previousClass" = $oldClass
          $arrTimeTrack."$($pc[0])_currentClass"  = ''
          $arrTimeTrack."$($pc[0])_lastChange"    = ''
        }
      }
    }
    
    # Switch #1 - Tracking Goal/TeamScores prior to world/error checks skip loop.
    #           - Tracking all-death prior to this also (death due to fall/other damage).
    switch ($type) {
      # Not used 'gameStart' { $map = $item.map }
      
      'goal' {
        # arrTimeTrack.flag* updated under the fumble event
        arrPlayerTable-UpdatePlayer -Name $arrTimeTrack.flagPlayer -Round $round -Property 'FlagTime' -Value ($time - $arrTimeTrack.flagTook) -Increment
        arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'FlagCap' -Increment
        $arrFlagCapMin.$keyTime += 1
      }

      'teamScores' {
        # For the final team score message
        $arrResult.team1Score = $item.team1Score
        $arrResult.team2Score = $item.team2Score
        $arrResult.winningTeam = $item.winningTeam
        $arrResult.time = $time

        # Note - Add +10 points when Team1 wins to avoid a Draw being compared to a Win.
        switch ($arrResult.winningTeam) {
          '0' { $arrResult.winRating = 0; $arrResult.winRatingDesc = 'Nobody wins' }
          '1' { $arrResult.winRating = 1 - ($arrResult.team2Score / ($arrResult.team1Score + 10)); $arrResult.winRatingDesc = "Wins by $($item.team1Score - $item.team2Score) points" }
          default { $arrResult.winRating = (($round1EndTime * 2) - $arrResult.time) / $round1EndTime; $arrResult.winRatingDesc = "$("{0:m\:ss}" -f ([timespan]::fromseconds(($round1EndTime * 2) - $arrResult.time))) mins left" }
        }
      }

      'death' {
        $arrDeathMin.$keyTime += 1
        if ($player -ne '' -and $class -ne 0) {
          arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'Death' -Increment
          if ($item.attacker -in 'world', '') {
            if ($weap -ne 'laser') { $weap = 'world' }
            arrWeaponTable-UpdatePlayer -Name $player -PlayerClass $class -Round $round -Weapon $weap -Class $class -Property 'Death' -Increment
          }
        }
        continue
      } 
    }
    
    #Skip environment/world events for kills/dmg stats (or after this), let laser and team scores pass thru
    if ((($player -eq '') -Or ($p_team -eq '0') -or ($t_team -eq '0') -or ($t_class -eq '0') -or ($weap -eq 'worldSpawn')) -and ($type -ne 'teamScores' -and $weap -ne 'laser')) { continue } 
    

    #team tracking
    if ($p_team -notin $null, '' -and $p_team -gt 0 -and $class -gt 0 -and $type -notin 'damageTaken' -and $weap -notlike 'worldspawn*') {
      if ($player -eq 'world') { $weap; $item }
      if ($arrTeam.$player -in '', $null) {
        #Initialise team info when null
        $arrTeam.$player = "$p_team"
      }
      elseif ($p_team -notin ($arrTeam.$player -split '&')) {
        #Else if team not in list add it
        $arrTeam.$player = "$($arrTeam.$player)&$($p_team)"
      }

      #Do the same for Rnd1 / Rnd2
      switch ($round) {
        '1' {
          if ($arrTeamRnd1.$player -in '', $null) {
            #Initialise team info when null
            $arrTeamRnd1.$player = "$p_team"
          }
          elseif ($p_team -notin ($arrTeamRnd1.$player -split '&')) {
            #Else if team not in list add it
            $arrTeamRnd1.$player = "$($arrTeamRnd1.$player)&$($p_team)"
          }
        }
        default {
          if ($arrTeamRnd2.$player -in '', $null) {
            #Initialise team info when null
            $arrTeamRnd2.$player = "$p_team"
          }
          elseif ($p_team -notin ($arrTeamRnd2.$player -split '&')) {
            #Else if team not in list add it
            $arrTeamRnd2.$player = "$($arrTeamRnd2.$player)&$($p_team)"
          }
        
        }
      }
    }

    # Switch #2
    # Frag and damage counter, + flags + scores + result + weap kills/deaths
    switch ($type) { 
      'kill' {    
        if ($player -ne $target -and $player -notin $null, '') {
          #make sure player did not killed himself and has a name
          if ($p_team -eq $t_team) {
            #team kill recorded, not a normal kill
            arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'TKill' -Increment
          }
          else {
            #Record the normal kill
            arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'Kills' -Increment
            arrWeaponTable-UpdatePlayer -Name $player -PlayerClass $class -Round $round -Weapon $weap -Class $class -Property 'Kills' -Increment

            $arrKilledClass.$keyClassK += 1
            $arrFragMin.$keyTime += 1

            switch ($round) {
              '1' { $arrKilledClassRnd1.$keyClassK += 1 }
              default { $arrKilledClassRnd2.$keyClassK += 1 }
            }
          }
        }
      
        #track all weap deaths on targets AND all versus kills (to see self/team kills in table). Exclude sentry death for player totals.
        #dont track SG deaths except in the class and weapons stats. 
        #if ($t_class -ne '10') {
          if ($player -notin $null, '') {
            $arrFragVersus.$key += 1
            switch ($round) {
              '1' { $arrFragVersusRnd1.$key += 1 }
              default { $arrFragVersusRnd2.$key += 1 }
            }

            arrWeaponTable-UpdatePlayer -Name $target -PlayerClass $t_class -Round $round -Class $class -Weapon $weap -Property 'Death' -Increment
          }
        #}
      }

      'damageDone' {
        if ($player -ne $target) { 
          #make sure player did not hurt himself, not record in totals - versus only.
          if ($p_team -ne $t_team) {
            #track enemy damage only in the total	  
            arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'Dmg'      -Value $dmg -Increment
            arrPlayerTable-UpdatePlayer -Name $target -Round $round -Property 'DmgTaken' -Value $dmg -Increment
            arrWeaponTable-UpdatePlayer -Name $player -PlayerClass $class   -Round $round -Weapon $weap -Class $class -Property 'Dmg' -Value $dmg -Increment
            arrWeaponTable-UpdatePlayer -Name $target -PlayerClass $t_class -Round $round -Weapon $weap -Class $class -Property 'DmgTaken' -Value $dmg  -Increment

            $arrDmgMin.$keyTime += $dmg
          }
          elseif ($player) {
            #team dmg
            arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'DmgTeam' -Value $dmg -Increment
          }
        }
        #record all damage including self/team in versus table
        $arrDmgVersus.$key += $dmg
        switch ($round) {
          '1' { $arrDmgVersusRnd1.$key += $dmg }
          default { $arrDmgVersusRnd2.$key += $dmg }
        }
      }

      'fumble' {
        arrPlayerTable-UpdatePlayer -Name $arrTimeTrack.flagPlayer -Round $round -Property 'FlagTime' -Value ($time - $arrTimeTrack.flagTook) -Increment
        $arrTimeTrack.'flagPlayer' = ''
        $arrTimeTrack.'flagTook' = 0
        
        arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'FlagDrop' -Increment
        $arrFlagDropMin.$keyTime += 1

        # work out if death or throw
        if ($prevAttacker -and $item.team -ne $prevItem.attackerTeam -and $prevItem.type -eq 'death' -and $prevPlayer -eq $player -and 
          $prevItem.time -eq $time -and $prevItem.kind -ne 'self') {
          arrPlayerTable-UpdatePlayer -Name $prevAttacker -Round $round -Property 'FlagStop' -Increment
          $arrFlagStopMin."$($timeBlock)_$($prevAttacker)" += 1
        }
        elseif ($prevItem.kind -ne 'self') { 
          arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'FlagThrow' -Increment
          $arrFlagThrowMin.$keyTime += 1 
        }
      }

      'pickup' {
        $arrTimeTrack.flagTook = $time
        $arrTimeTrack.flagPlayer = $player
        arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'FlagTake' -Increment
        $arrFlagTookMin.$keyTime += 1
      }
    } #end type switch

    if ($prevItem -ne '-1') { $prevItem = $item }
    else { $prevItem = '' }
  }#end for - finished parsing the JSON file

  #Close the arrTimeTrack flag + class stats a
  $arrTimeTrack.flagPlayer = ''
  $arrTimeTrack.flagTook = 0

  foreach ($p in $arrTeam.Keys) {
    $currentClass = $arrTimeTrack."$($p)_currentClass"   
    if ($currentClass -in '',$null) { continue }
    arrClassTable-UpdatePlayer -Table ([ref]$arrClassTimeTable) -Player $p -Class $currentClass -Round $round -Value ($time - $arrTimeTrack."$($p)_lastChange")
  }
  
  #remove any Class Times where timed played less that 20secs
  function arrClassTimeTable-Cleanup {
    param([ref]$Table)

    foreach ($p in $Table.Value) {
      $totalTime = ($p | Measure $ClassAllowedStr -Sum).Sum
      foreach ($c in $ClassAllowed) {
        $cStr = $ClassToStr[$c]
        $kills = ($arrWeaponTable | Where-Object { $_.Name -eq $p.Name -and $_.PlayerClass -eq $c -and $_.Round -eq $p.Round } | Measure-Object Kills -Sum).Sum
        $dmg   = ($arrWeaponTable | Where-Object { $_.Name -eq $p.Name -and $_.PlayerClass -eq $c -and $_.Round -eq $p.Round } | Measure-Object Dmg   -Sum).Sum

        if ($p.$cStr -in 1..20 -and $kills -lt 1 -and $dmg -lt 1) {      
          if ($p.Round -eq 1) { $p."$($ClassToStr[$arrTimeTrack."$($p.name)_endClassRnd1"])"  += $p.$cStr }
          else                { $p."$($ClassToStr[$arrTimeTrack."$($p.name)_previousClass"])" += $p.$cStr }
          $p.$cStr = 0
        }
        elseif ($p.$cStr -gt $round1Endtime) {
          $p.$cStr = $round1EndTime
        }
      }
    }
  }

  #cleanup class times
  arrClassTimeTable-Cleanup ([ref]$arrClassTimeTable)

  ######
  #Create Ordered Player List 
  #####
  $playerList = ($arrTeam.GetEnumerator() | Sort-Object -Property Value, Name).Key

  #######
  # Add Team Info to tables and sort by Round/Team/Name
  ######

  foreach ($i in $arrWeaponTable) {
    switch ($i.Round) { 
      1 { $i.Team = $arrTeamRnd1.($i.Name) }
      2 { $i.Team = $arrTeamRnd2.($i.Name) }
      default { $i.Team = $arrTeam.($i.Name) }
    }
  }
  $arrWeaponTable = $arrWeaponTable | Sort-Object Round, Team, Name

  foreach ($i in $arrPlayerTable) {
    switch ($i.Round) { 
      1 { $i.Team = $arrTeamRnd1.($i.Name) }
      2 { $i.Team = $arrTeamRnd2.($i.Name) }
      default { $i.Team = $arrTeam.($i.Name) }
    }
  }
  $arrPlayerTable = $arrPlayerTable | Sort-Object Round, Team, Name                                   
  
  if (!$TextOnly) {
    ###
    # Calculate awards
    ##

    #create variables here, min/max values to be generated for awardAtt* + awardDef* (exclude *versus)
    Remove-Variable -Name award*
    $script:awardAttKills = @{}
    $script:awardAttDeath = @{}
    $script:awardAttDmg = @{}
    $script:awardAttDmgTaken = @{}
    $script:awardAttDmgTeam = @{}
    $script:awardAttKD = @{}
    $script:awardAttTKill = @{}
    $script:awardAttDmgPerKill = @{}
    $script:awardAttKillsVersus = @{}
    $script:awardAttFlagCap = @{}
    $script:awardAttFlagTook = @{}
    $script:awardAttFlagTime = @{}

    $script:awardDefKills = @{}
    $script:awardDefDeath = @{}
    $script:awardDefDmg = @{}
    $script:awardDefDmgTaken = @{}
    $script:awardDefDmgTeam = @{}
    $script:awardDefKD = @{}
    $script:awardDefTKill = @{}
    $script:awardDefDmgPerKill = @{}
    $script:awardDefKillsVersus = @{}

    function awardScaler {
      if ($arrResult.WinningTeam -eq 2) {
        $playedPercent = ($arrResult.time - $round1EndTime) / $round1EndTime
        return [math]::Floor($args[0] / $playedPercent)
      }
      else { return $args[0] }
    }

    #Attack - Rnd1=T1 and Rnd2=T2 - Get Player list and get required Data sets
    # Teams sorted in order, i.e. 1&2 = Att 2x, 2&1 = Def 2x.
    $script:playerListAttRnd1 = ($arrTeamRnd1.Keys | foreach { if ($arrTeamRnd1.$_ -match '^(1|1&2)$' -and (arrClassTable-FindPlayerTotal $_ 1) -gt $round1EndTime - 60) { $_ } })
    $script:playerListAttRnd2 = ($arrTeamRnd2.Keys | foreach { if ($arrTeamRnd2.$_ -match '^(2|1&2)$' -and (arrClassTable-FindPlayerTotal $_ 2) -gt ($arrResult.time - $round1EndTime - 60)) { $_ } })


    ## Generate Attack/Def Tables, e.g. for att Rnd1 = Team1 attack + Rnd2 = Team2 attack
    $count = 1

    foreach ($array in @($playerListAttRnd1, $playerListAttRnd2)) {
      foreach ($p in $array) {
        #disqualify a player if they were on multiple teams
        if ($arrTeam.$p -notmatch '^(1|2)$') { continue }

        if ($arrResult.WinningTeam -eq 2) {
          $scaler = 1 / $arrResult.winRating
        }
        else { $scaler = 1 }
        $pos = arrFindPlayer -Table ([ref]$arrPlayerTable) -Player $p -Round $count

        $awardAttFlagCap.Add( $p, $arrPlayerTable[$pos].FlagCap)
        $awardAttFlagTook.Add($p, $arrPlayerTable[$pos].FlagTake)
        $awardAttFlagTime.Add($p, $arrPlayerTable[$pos].FlagTime)
      

        if ($count -eq 1) {
          $awardAttKills.Add($p, $arrPlayerTable[$pos].Kills)
          $awardAttDeath.Add($p, $arrPlayerTable[$pos].Death )
          $awardAttDmg.Add(  $p, $arrPlayerTable[$pos].Dmg )
          $awardAttDmgTaken.Add($p, $arrPlayerTable[$pos].DmgTaken)
          $awardAttDmgTeam.Add(  $p, $arrPlayerTable[$pos].DmgTeam)
          $awardAttTkill.Add($p, $arrPlayerTable[$pos].TKill)
          $awardAttKD.Add(   $p, ($arrPlayerTable[$pos].Kills - $arrPlayerTable[$pos].Death) )
        }
        else {
          $awardAttKills.Add($p, (awardScaler $arrPlayerTable[$pos].Kills ))
          $awardAttDeath.Add($p, (awardScaler $arrPlayerTable[$pos].Death))
          $awardAttDmg.Add(  $p, (awardScaler $arrPlayerTable[$pos].Dmg))
          $awardAttDmgTaken.Add(  $p, (awardScaler $arrPlayerTable[$pos].DmgTaken))
          $awardAttDmgTeam.Add(  $p, (awardScaler $arrPlayerTable[$pos].DmgTeam))
          $awardAttTkill.Add($p, (awardScaler $arrPlayerTable[$pos].TKill))

          $awardAttKD.Add(   $p, (awardScaler ($arrPlayerTable[$pos].Kills - $arrPlayerTable[$pos].Death)) )
        }
        if ($arrPlayerTable[$pos].Kills -notin $null, '', '0') { $awardAttDmgPerKill.Add($p, [math]::Round($arrPlayerTable[$pos].Dmg / $arrPlayerTable[$pos].Kills) ) }
      }
      $count += 1
    }


    #defence - Rnd2=T2 and Rnd2=T1 - Get Player list and get required Data sets
    ## Generate Attack/Def Tables, e.g. for att Rnd1 = Team2 def + Rnd2 = Team1 def
    $script:playerListDefRnd1 = ($arrTeamRnd1.Keys | foreach { if ($arrTeamRnd1.$_ -match '^(2|2&1)$' -and (arrClassTable-FindPlayerTotal $_ 1) -gt $round1EndTime - 60) { $_ } })
    $script:playerListDefRnd2 = ($arrTeamRnd2.Keys | foreach { if ($arrTeamRnd2.$_ -match '^(1|2&1)$' -and (arrClassTable-FindPlayerTotal $_ 2) -gt $arrResult.time - $round1EndTime - 60) { $_ } })

    $count = 1
    foreach ($array in @($playerListDefRnd1, $playerListDefRnd2)) {
      foreach ($p in $array) {
        #disqualify a player if they were on multiple teams
        if ($arrTeam.$p -notmatch '^(1|2)$') { continue }
        $pos = arrFindPlayer -Table ([ref]$arrPlayerTable) -Player $p -Round $count

        if ($count -eq 1) {
          $awardDefKills.Add($p, $arrPlayerTable[$pos].Kills)
          $awardDefDeath.Add($p, $arrPlayerTable[$pos].Death )
          $awardDefDmg.Add(  $p, $arrPlayerTable[$pos].Dmg )
          $awardDefDmgTaken.Add($p, $arrPlayerTable[$pos].DmgTaken)
          $awardDefDmgTeam.Add(  $p, $arrPlayerTable[$pos].DmgTeam)
          $awardDefTkill.Add($p, $arrPlayerTable[$pos].TKill)
          $awardDefKD.Add(   $p, ($arrPlayerTable[$pos].Kills - $arrPlayerTable[$pos].Death) )
        }
        else {
          $awardDefKills.Add($p, (awardScaler $arrPlayerTable[$pos].Kills ))
          $awardDefDeath.Add($p, (awardScaler $arrPlayerTable[$pos].Death))
          $awardDefDmg.Add(  $p, (awardScaler $arrPlayerTable[$pos].Dmg))
          $awardDefDmgTaken.Add(  $p, (awardScaler $arrPlayerTable[$pos].DmgTaken))
          $awardDefDmgTeam.Add(  $p, (awardScaler $arrPlayerTable[$pos].DmgTeam))
          $awardDefTkill.Add($p, (awardScaler $arrPlayerTable[$pos].TKill))

          $awardDefKD.Add(   $p, (awardScaler ($arrPlayerTable[$pos].Kills - $arrPlayerTable[$pos].Death)) )
        }
        if ($arrPlayerTable[$pos].Kills -notin $null, '', '0') { $awardDefDmgPerKill.Add($p, [math]::Round($arrPlayerTable[$pos].Dmg / $arrPlayerTable[$pos].Kills) ) }

      }
      $count += 1
    }

    #function to tally up multiple sources
    function awardTallyTables {
      $htOut = @{}
      $keyList = $args[0].Keys
      $keyList += ($args[1].Keys -notmatch ($args[0].Keys -replace $regExReplaceFix))

      foreach ($item in $keyList) {
        $htOut.$item = $args[0].$item + $args[1].$item
      }
      return $htOut
    }

    $awardAttDmgAll = awardTallyTables $awardAttDmg $awardAttDmgTaken
    $awardDefDmgAll = awardTallyTables $awardDefDmg $awardDefDmgTaken

    # MR Magoo % higher than TK and TmDmg, then divide by two for an average.
    $tkAvg = ($awardDefTKill.Values   | Measure-Object -Average).Average
    $tdAvg = ($awardDefDmgTeam.Values | Measure-Object -Average).Average
    $awardDefMagoo = @{}
    foreach ($p in $awardDefTKill.Keys) { $awardDefMagoo.$p += $awardDefTKill.$p / $tkAvg }
    foreach ($p in $awardDefDmgTeam.Keys) { $awardDefMagoo.$p = [Math]::Round(($awardDefMagoo.$p + ($awardDefDmgTeam.$p / $tdAvg)) / 2, 2) }
    Remove-Variable tkAvg, tdAvg


    # Repeatable function for Killed Class Lookup
    function awardFromKilledClass {
      # p1 = att/def p2 = regex
      $htOut = @{}
      switch ($args[0]) {
        'Att' { $plRnd1 = $playerListAttRnd1; $plRnd2 = $playerListAttRnd2 }
        'Def' { $plRnd1 = $playerListDefRnd1; $plRnd2 = $playerListDefRnd2 }
        Default { return }
      }

      foreach ($item in $arrKilledClassRnd1.Keys -match $args[1]) { 
        $name = ($item -split '_')[0]
        # Disqualify player if on multple teams
        if ($arrTeam.$name -notmatch '^(1|2)$') { continue }

        if ($name -in $plRnd1) { $htOut.$name += $arrKilledClassRnd1.$item }
      }
      foreach ($item in $arrKilledClassRnd2.Keys -match $args[1]) { 
        $name = $($item -split '_')[0]
        # Disqualify player if on multple teams
        if ($arrTeam.$name -notmatch '^(1|2)$') { continue }

        if ($name -in $plRnd2) { $htOut.$name += (awardScaler $arrKilledClassRnd2.$item) }
      }

      if ($htOut.Count -lt 1) { $htOut.'n/a' = 'n/a' }
      return $htOut
    }

    $awardAttKilledDemo = (awardFromKilledClass 'Att' '.*_4$')
    $awardDefKilledSold = (awardFromKilledClass 'Def' '.*_3$')
    $awardDefKilledLight = (awardFromKilledClass 'Def' '.*_(1|5|8|9)$')
    $awardAttKilledHeavy = (awardFromKilledClass 'Att' '.*_(3|4|6|7)$')
    $awardDefKilledHeavy = (awardFromKilledClass 'Def' '.*_(3|4|6|7)$')
    $awardAttLightKills = (awardFromKilledClass 'Att' '.*_(1|5|8|9)_.*$')
    $awardAttKilledSG = (awardFromKilledClass 'Att' '.*_10$')


    #####
    #Get MAX and MIN for each of the new tables starting with awardAtt/awardDef
    # CREATE ALL $awardDef and $awardAtt tables BEFORE THIS POINT!!
    ######
    #attack
    ####
    foreach ($v in (Get-Variable 'award*' -Exclude '*_*', 'awardsHtml')) {
      Set-Variable -Name  "$($v.Name)_Max" -Value (($v.Value).Values | Measure-Object -Maximum).Maximum
      Set-Variable -Name  "$($v.Name)_Min" -Value (($v.Value).Values | Measure-Object -Minimum).Minimum
    }

    function addTokenToString {
      if ($args[0] -in $null, '') { $args[1] }
      elseif ($args[1] -notin ($args[0] -split ', ')) { "$($args[0]), $($args[1])" }
      else { $args[0] }
    }

    # Get the Names of each Max/Min award table
    foreach ($p in $PlayerList) {
      foreach ($vlist in @((Get-Variable 'award*_Max' -Exclude '*Versus*'), (Get-Variable 'award*_Min' -Exclude '*Versus*'))) {    
        foreach ($v in $vlist) {
          $arrayName = ($v.Name -Split '_')[0]
          $name = "$($v.Name)Name"
          $value = $v.Value[1]
          if (Test-Path "variable:$($name)") { $leader = Get-Variable $name -ValueOnly }
          else { $leader = '' }
          
          if ((Get-Variable $arrayName).Value.$p -eq $v.Value) { Set-Variable -Name $name -Value (addTokenToString $leader $p) }
        }
      }
    }

    # Most Frag  on a player 
    $attMax = ''
    $awardAttPlayerFrag_MaxName = ''
    $awardAttPlayerFrag_Victim = ''
    $awardAttPlayerFrag_Value = ''
    $defMax = ''
    $awardDefPlayerFrag_MaxName = ''
    $awardDefPlayerFrag_Victim = ''
    $awardDefPlayerFrag_Value = ''

    $count = 1
    ### Frag versus statistics
    foreach ($array in @($arrFragVersusRnd1, $arrFragVersusRnd2)) {
      foreach ($item in $array.keys) {
        #player/target
        $pt = $item -split '_'
        switch ($count) {
          1 { $pl = $playerListAttRnd1; $value = $array.$item }
          default { $pl = $playerListAttRnd2; $value = awardScaler $array.$item }
        }

        if ($pt[0] -ne $pt[1] -and $pt[0] -in $pl) {  
          if ($max -eq '' -or $value -ge $attMax) {
            if ($value -eq $attMax) {
              $awardAttPlayerFrag_MaxName = (addTokenToString $awardAttPlayerFrag_MaxName $pt[0])
              $awardAttPlayerFrag_Victim = (addTokenToString $awardAttPlayerFrag_Victim  $pt[1])
            }
            else {
              $awardAttPlayerFrag_MaxName = $pt[0]
              $awardAttPlayerFrag_Victim = $pt[1]
            }
            $awardAttPlayerFrag_Value = $value
            $attMax = $value
          }
        }

        switch ($count) {
          1 { $pl = $playerListDefRnd1 }
          default { $pl = $playerListDefRnd2 }
        }

        if ($pt[0] -ne $pt[1] -and $pt[0] -in $pl) {  
          if ($max -eq '' -or $value -ge $defMax) {
            if ($value -eq $defMax) {
              $awardDefPlayerFrag_MaxName = (addTokenToString $awardDefPlayerFrag_MaxName $pt[0])
              $awardDefPlayerFrag_Victim = (addTokenToString $awardDefPlayerFrag_Victim  $pt[1])
            }
            else {
              $awardDefPlayerFrag_MaxName = $pt[0]
              $awardDefPlayerFrag_Victim = $pt[1]
            }
            $awardDefPlayerFrag_Value = $value
            $defMax = $value
          } 
        }
      }
      $count += 1
    }

    # Most Dmg  on a player 
    $attMax = ''
    $awardAttPlayerDmg_MaxName = ''
    $awardAttPlayerDmg_Victim = ''
    $awardAttPlayerDmg_Value = ''
    $defMax = ''
    $awardDefPlayerDmg_MaxName = ''
    $awardDefPlayerDmg_Victim = ''
    $awardDefPlayerDmg_Value = ''

    $count = 1
    ### Damage versus statistics
    foreach ($array in @($arrDmgVersusRnd1, $arrDmgVersusRnd2)) {
      foreach ($item in $array.keys) {
        #player/target
        $pt = $item -split '_'
        switch ($count) {
          1 { $pl = $playerListAttRnd1; $value = $array.$item }
          default { $pl = $playerListAttRnd2; $value = awardScaler $array.$item }
        }

        if ($pt[0] -ne $pt[1] -and $pt[0] -in $pl) {  
          if ($max -eq '' -or $value -ge $attMax) {
            if ($value -eq $attMax) {
              $awardAttPlayerDmg_MaxName = (addTokenToString $awardAttPlayerDmg_MaxName   $pt[0])
              $awardAttPlayerDmg_Victim = (addTokenToString $awardAttPlayerDmg_Victim $pt[1])
            }
            else {
              $awardAttPlayerDmg_MaxName = $pt[0]
              $awardAttPlayerDmg_Victim = $pt[1]
            }
            $awardAttPlayerDmg_Value = $value
            $attMax = $value
          }
        }

        switch ($count) {
          1 { $pl = $playerListDefRnd1 }
          default { $pl = $playerListDefRnd2 }
        }

        if ($pt[0] -ne $pt[1] -and $pt[0] -in $pl) {  
          if ($max -eq '' -or $value -ge $defMax) {
            if ($value -eq $defMax) {
              $awardDefPlayerDmg_MaxName = (addTokenToString $awardDefPlayerDmg_MaxName $pt[0])
              $awardDefPlayerDmg_Victim = (addTokenToString $awardDefPlayerDmg_Victim  $pt[1])
            }
            else {
              $awardDefPlayerDmg_MaxName = $pt[0]
              $awardDefPlayerDmg_Victim = $pt[1]
            }
            $awardDefPlayerDmg_Value = $value
            $defMax = $value
          } 

        }
      }
      $count += 1
    }

    ####
    # Make Award HTML String
    ###

    function awardScaleCaveat {
      # p1 = att/def #p2 = names
      if ($arrResult.winningTeam -lt 2) { return $args[1] }
      
      $players = $args[1] -split ', '
      switch ($args[0]) {
        'Att' { $pl = $playerListAttRnd2 }
        default { $pl = $playerListDefRnd2 }
      }

      $outNames = ''
      foreach ($p in $players) {
        if ($p -in $pl) { $name = "$($p)*" }
        else { $name = $p }

        if ($outNames -eq '') { $outNames = $name }
        else { $outNames += ", $($name)" }
      }
      return $outNames
    }

  
    $awardsHtml = "<div class=row><div class=column style=`"width:580;display:inline-table`"> 
    <h3>The Attackers</h3>
    <table id=`"awardAttack`">
   <thead><tr><th>Award</h>            <th>Winner</th>                          <th>Description</th></tr> </thead>
   <tbody>
    <tr><td>Commando</td>        <td align=center width=150px class=$(teamColorCodeByName $awardAttKills_MaxName)>$(awardScaleCaveat 'Att' $awardAttKills_MaxName)</td>      <td>Most kills ($($awardAttKills_Max))</td></tr>
    <tr><td>Rambo</td>           <td align=center width=150px class=$(teamColorCodeByName $awardAttDmg_MaxName)>$(awardScaleCaveat 'Att' $awardAttDmg_MaxName)</td>        <td>Most damage ($($awardAttDmg_Max))</td></tr>
    <tr><td>Golden Hands</td>    <td align=center width=150px class=$(teamColorCodeByName $awardAttFlagCap_MaxName)>$($awardAttFlagCap_MaxName)</td>    <td>Most caps ($($awardAttFlagCap_Max))</td></tr>
    <tr><td>Running Man</td>     <td align=center width=150px class=$(teamColorCodeByName $awardAttFlagTime_MaxName)>$($awardAttFlagTime_MaxName)</td>   <td>Most time with flag ($($awardAttFlagTime_Max)s)</td></tr>
    <tr><td>Brawler</td>         <td align=center width=150px class=$(teamColorCodeByName $awardAttKilledHeavy_MaxName)>$(awardScaleCaveat 'Att' $awardAttKilledHeavy_MaxName)</td><td>Most kills on heavy classes ($($awardAttKilledHeavy_Max))</td></tr>
    <tr><td>David</td>           <td align=center width=150px class=$(teamColorCodeByName $awardAttLightKills_MaxName)>$(awardScaleCaveat 'Att' $awardAttLightKills_MaxName)</td> <td>Most kills as a light class ($($awardAttLightKills_Max))</td></tr>
    <tr><td>Spec Ops</td>        <td align=center width=150px class=$(teamColorCodeByName $awardAttKilledDemo_MaxName)>$(awardScaleCaveat 'Att' $awardAttKilledDemo_MaxName)</td> <td>Most kills on demo ($($awardAttKilledDemo_Max))</td></tr>
    <tr><td>Sapper</td>          <td align=center width=150px class=$(teamColorCodeByName $awardAttKilledSG_MaxName)>$(awardScaleCaveat 'Att' $awardAttKilledSG_MaxName)</td>   <td>Most kills on a SG ($($awardAttKilledSG_Max))</td></tr>
    <tr><td>Lemming</td>         <td align=center width=150px class=$(teamColorCodeByName $awardAttDeath_MaxName)>$(awardScaleCaveat 'Att' $awardAttDeath_MaxName)</td>      <td>Most Deaths ($($awardAttDeath_Max))</td></tr>
    <tr><td>Battering Ram</td>   <td align=center width=150px class=$(teamColorCodeByName $awardAttKD_MinName)>$(awardScaleCaveat 'Att' $awardAttKD_MinName)</td>         <td>Lowest Kill-Death rank ($($awardAttKD_Min))</td></tr>
    <tr><td>Buck shot</td>       <td align=center width=150px class=$(teamColorCodeByName $awardAttDmgPerKill_MaxName)>$($awardAttDmgPerKill_MaxName)</td>                        <td>Most Damage per kill ($($awardAttDmgPerKill_Max))</td></tr>
    <tr><td>Predator</td>        <td align=center width=150px class=$(teamColorCodeByName $awardAttPlayerFrag_MaxName)>$(awardScaleCaveat 'Att' $awardAttPlayerFrag_MaxName)</td> <td>Most kills on a defender ($($awardAttPlayerFrag_Value) on $($awardAttPlayerFrag_Victim))</td></tr>
    <tr><td>Hulk Smash</td>      <td align=center width=150px class=$(teamColorCodeByName $awardAttPlayerDmg_MaxName)>$(awardScaleCaveat 'Att' $awardAttPlayerDmg_MaxName)</td>  <td>Most damage on a defender ($($awardAttPlayerDmg_Value) on $($awardAttPlayerDmg_Victim))</td></tr>
    </tbody>
    "

    if ($arrResult.winningTeam -eq 2) {
      $awardsHtml += "<tr><td colspan=3 align=right><i>*Team2 scaled: Only $('{0:p0}' -f [math]::Round((1 - $arrResult.winRating),2)) of Rnd2 played</i></td></tr>`n"
    }

    $awardsHtml += "</table></div>
    <div class=column style=`"width:580;display:inline-table`"> 
    <h3>The Defenders</h3>
    <table id=`"awardDefence`">
    <thead><tr><th>Award</h>                <th>Winner</th>                                                  <th>Description</th></tr> </thead>
    <tbody>
    <tr><td>Slaughterhouse</td>      <td align=center width=150px class=$(teamColorCodeByName $awardDefKills_MaxName)>$(awardScaleCaveat 'Def' $awardDefKills_MaxName)</td>      <td>Most kills ($($awardDefKills_Max))</td></tr>
    <tr><td>Terminator</td>          <td align=center width=150px class=$(teamColorCodeByName $awardDefKD_MaxName)>$(awardScaleCaveat 'Def' $awardDefKD_MaxName)</td>         <td>Kills-death rank ($($awardDefKD_Max))</td></tr>
    <tr><td>Juggernaut</td>          <td align=center width=150px class=$(teamColorCodeByName $awardDefDmg_MaxName)>$(awardScaleCaveat 'Def' $awardDefDmg_MaxName)</td>        <td>Most damage ($($awardDefDmg_Max))</td></tr>
    <tr><td>Dark Knight</td>         <td align=center width=150px class=$(teamColorCodeByName $awardDefKilledSold_MaxName)>$(awardScaleCaveat 'Def' $awardDefKilledSold_MaxName)</td> <td>Most kills on Soldier ($($awardDefKilledSold_Max))</td></tr>
    <tr><td>Tank</td>                <td align=center width=150px class=$(teamColorCodeByName $awardDefKilledHeavy_MaxName)>$(awardScaleCaveat 'Def' $awardDefKilledHeavy_MaxName)</td><td>Most kills on a heavy class ($($awardDefKilledHeavy_Max))</td></tr>
    <tr><td>Goliath</td>             <td align=center width=150px class=$(teamColorCodeByName $awardDefKilledLight_MaxName)>$(awardScaleCaveat 'Def' $awardDefKilledLight_MaxName)</td><td>Most kills on a light class ($($awardDefKilledLight_Max))</td></tr>
    <tr><td>Sly Fox</td>             <td align=center width=150px class=$(teamColorCodeByName $awardDefDeath_MinName)>$(awardScaleCaveat 'Def' $awardDefDeath_MinName)</td>      <td>Lowest Deaths ($($awardDefDeath_Min))</td></tr>
    <tr><td>Team Player</td>         <td align=center width=150px class=$(teamColorCodeByName $awardDefDmgPerKill_MaxName)>$($awardDefDmgPerKill_MaxName)</td>                        <td>Most damage per kill ($($awardDefDmgPerKill_Max))</td></tr>
    <tr><td>Nemesis</td>             <td align=center width=150px class=$(teamColorCodeByName $awardDefPlayerFrag_MaxName)>$(awardScaleCaveat 'Def' $awardDefPlayerFrag_MaxName)</td> <td>Most Kills on an attacker ($($awardDefPlayerFrag_Value) on $($awardDefPlayerFrag_Victim))</td></tr>
    <tr><td>No quarter</td>          <td align=center width=150px class=$(teamColorCodeByName $awardDefDmgPerKill_MinName)>$($awardDefDmgPerKill_MinName)</td>                        <td>Lowest damage per kill ($($awardDefDmgPerKill_Min))</td></tr>
    <tr><td>Attention whore</td>     <td align=center width=150px class=$(teamColorCodeByName $awardDefDmgAll_MaxName)>$(awardScaleCaveat 'Def' $awardDefDmgAll_MaxName)</td>     <td>Most damage given + taken ($($awardDefDmgAll_Max))</td></tr>
    <tr><td>Shy Guy</td>             <td align=center width=150px class=$(teamColorCodeByName $awardDefDmgTaken_MinName)>$(awardScaleCaveat 'Def' $awardDefDmgTaken_MinName)</td>   <td>Lowest damage taken ($($awardDefDmgTaken_Min))</td></tr>
    <tr><td>Mr Magoo</td>            <td align=center width=150px class=$(teamColorCodeByName $awardDefMagoo_MaxName)>$($awardDefMagoo_MaxName)</td>      <td>Team Kill/Damage above avg ($('{0:p0}' -f $awardDefMagoo_Max))</td></tr>
    </tbody>`n"

    if ($arrResult.winningTeam -eq 2) {
      $awardsHtml += "<tr><td colspan=3 align=right><i>*Team1 scaled: Only $('{0:p0}' -f [math]::Round((1 - $arrResult.winRating),2)) of Rnd2 played</i></td></tr>`n"
    }
    $awardsHtml += "</table></div></div>"

    ###
    # Generate the HTML Ouput
    ###

    $ccGrey = 'cellGrey'
    $ccAmber = 'cellAmber'
    $ccOrange = 'cellOrange'
    $ccGreen = 'cellGreen'
    $ccBlue = 'rowTeam1'
    $ccRed = 'rowTeam2'
    $ccPink = 'rowTeamBoth'

    <# See fo_stats.css
      $ccGrey   = '#F1F1F1'
      $ccAmber  = '#FFD900'
      $ccOrange = '#FFB16C'
      $ccGreen  = '#96FF8F'
      $ccBlue   = '#87ECFF'
      $ccRed    = '#FF8080'
      $ccPink   = '#FA4CFF'

      <style>
        body { font-family: calibri; color:white; background-color:rgb(56, 75, 94);}

        th { background-color: rgb(19, 37, 56);}
        tr { background-color: rgb(34, 58, 85);}
        table, th, td {
          white-space: nowrap;
          padding: 2px;
          border: 1px solid rgb(122, 122, 122);
          border-collapse: collapse;
          min-width: 20px;
        }
        .rowTeam1    { background-color: #2357b9 }
        .rowTeam2    { background-color: #d63333 }
        .rowTeamBoth { background-color: #b71dbd } 
        .cellGrey   { background-color:rgb(45, 62, 80) }
        .cellAmber  { color:black; background-color: #fcd600 }
        .cellOrange { background-color: #e0662d }
        .cellGreen  { background-color: #2357b9 }
      </style>#>

    $htmlOut = "<html>
      <head>
        <meta id=`"FOStatsVersion`" name=`"FOStatsVersion`" content=`"2.1`">
        <script src=`"http://haze.fortressone.org/.css/fo_stats.js`"></script>
        <script src=`"tablesort.min.js`"></script>
        <script src=`"tablesort.number.min.js`"></script>
        <script src=`"../../tablesort.min.js`"></script>
        <script src=`"../../tablesort.number.min.js`"></script>
        <script src=`"http://haze.fortressone.org/.css/tablesort.min.js`"></script>
        <script src=`"http://haze.fortressone.org/.css/tablesort.number.min.js`"></script>
        <link rel=`"stylesheet`" href=`"fo_stats.css`">
        <link rel=`"stylesheet`" href=`"../../fo_stats.css`">
        <link rel=`"stylesheet`" href=`"http://haze.fortressone.org/.css/fo_stats.css`">
      </head>
      <body>
        <h1>$($jsonFile.Name)</h1>"


    $htmlOut += "<table id=`"matchResult`" cellpadding=`"3`">
    <thead><tr><th>Result</th><th>Scores</th><th>Win Rating</th></tr></thead>
    <tr><td class=`"$(teamColorCode $arrResult.winningTeam)`">"  

    switch ($arrResult.winningTeam) {
      '0' { $htmlOut += "DRAW! " }
      default { $htmlOut += "TEAM $($arrResult.winningTeam) WINS! " }
    }

    $htmlOut += "</td><td>Team1: $($arrResult.team1Score) vs Team2: $($arrResult.team2Score)</td><td>$('{0:p0}' -f $arrResult.winRating) ($($arrResult.winRatingDesc))</td></tr>`n</table>`n"  
    
    #### awards
    $htmlOut += "<hr><h2>Awards</h2>`n"
    $htmlOut += $awardsHtml

    #Frag Total Table
    #$htmlOut += "<hr><h2>TOTAL - Attack and Defence</h2>`n"  
    #$htmlOut += GenerateFragHtmlTable ''
    #$htmlOut += GenerateDmgHtmlTable ''
    $htmlOut += "<hr><h2>Attack and Defence</h2>`n"
    $htmlOut += '<div class="row"><div class="column"  style="display:inline-table;padding-right:5px">'
    $htmlOut += "<h3>Attack</h3>`n"         
    $htmlOut += GenerateSummaryHtmlTable -Attack
    $htmlOut += '</div><div class="column"  style="display:inline-table">'
    $htmlOut += "<h3>Defence</h3>`n"            
    $htmlOut += GenerateSummaryHtmlTable -Defence
    $htmlOut += '</div></div>'

    $htmlOut += "<hr><h2>Frags</h2>`n" 
    $htmlOut += '<div class="row"><div class="column"  style="display:inline-table;padding-right:5px">'
    $htmlOut += "<h3>Round 1</h3>`n" 
    $htmlOut += GenerateFragHtmlTable -Round '1'
    $htmlOut += '</div><div class="column"  style="display:inline-table">'
    $htmlOut += "<h3>Round 2</h3>`n"   
    $htmlOut += GenerateFragHtmlTable -Round '2'
    $htmlOut += '</div></div>'

    #Damage by Round Table
    $htmlOut += "<hr><h2>Damage</h2>`n"  
    $htmlOut += '<div class="row"><div class="column"  style="display:inline-table;padding-right:5px">' 
    $htmlOut += "<h3>Round 1</h3>`n"   
    $htmlOut += GenerateDmgHtmlTable -Round '1'
    $htmlOut += '</div><div class="column"  style="display:inline-table">'
    $htmlOut += "<h3>Round 2</h3>`n"          
    $htmlOut += GenerateDmgHtmlTable -Round '2'
    $htmlOut += '</div></div>'

    ###
    # frag/death per mins
    ###

    $htmlOut += "<hr><h2>Per Minute - Frags/Deaths</h2>`n"  
    
    $table = ''
    $tableHeader = "<thead><tr><th colspan=6></ht><th colspan=$([math]::Ceiling($round1EndTime / 60) + 1)>Rnd1</ht><th colspan=$($timeBlock - $([math]::Ceiling($round1EndTime / 60)) + 1)>Rnd2</th></tr>
    <tr><th>#</th><th>Player</th><th>Team</th><th title='Kills'>Kills</th><th title='Deaths'>Dth</th><th title='Team kills'>TK</h>"
    
    foreach ($min in 1..$timeBlock) { 
      $tableHeader += "<th>$($min)</th>" 
      if ($min -in $timeBlock, ([math]::Floor($round1EndTime / 60))) { 
        $tableHeader += "<th>Total</th>" 
      }
    }
    $tableHeader += "</tr></thead>`n"

    $count = 1
    $subtotalFrg = @(1..$timeBlock | foreach { 0 } )
    $subtotalDth = @(1..$timeBlock | foreach { 0 } )

    foreach ($p in $playerList) {
      $kills = ($arrPlayerTable | Where Name -eq $p | Measure Kills -Sum).Sum
      $death = ($arrPlayerTable | Where Name -eq $p | Measure Death -Sum).Sum
      $tKill = ($arrPlayerTable | Where Name -eq $p | Measure TKill -Sum).Sum
      $table += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($kills)</td><td>$($death)</td><td>$($tKill)</td>"
      
      $count2 = 0  
      foreach ($min in 1..$timeBlock) {
        $key = "$($min)_$($p)"
        $kills = $arrFragMin.$key
        $dth = $arrDeathMin.$key
        if ($kills -in '', $null -and $dth -in '', $null) { 
          $value = ''
          $cellCC = nullValueColorCode
        }
        else {
          $cellCC = $ccGreen
          if ($kills -lt $dth) { $cellCC = $ccAmber }
          if ($kills -eq '' -or $kills -lt 1) { $kills = '0'; $cellCC = $ccOrange }
          if ($dth -eq '' -or $dth -lt 1) { $dth = '0' }

          $value = "$($kills)/$($dth)"
        }

        $table += "<td class=`"$($cellCC)`" width=40px>$($value)</td>"
        
        $subtotalFrg[$count2] += $kills
        $subtotalDth[$count2] += $dth


        if ($min -in $timeBlock, ([math]::Floor($round1EndTime / 60))) {
          #rnd total
          if ($min -le ([math]::Floor($round1EndTime / 60))) {
            $round = 1            
          }
          else {
            $round = 2
          }
          $kills = ($arrPlayerTable | Where { $_.Name -eq $p -and $_.Round -eq $round } | Measure Kills -Sum).Sum
          $death = ($arrPlayerTable | Where { $_.Name -eq $p -and $_.Round -eq $round } | Measure Death -Sum).Sum    
          $table += "<td>$($kills)/$($death)</td>"
        }
        $count2 += 1
      }

      $table += "</tr>`n"
      $count += 1 
    }

    $table += '<tfoot><tr id="TotalRow"><td colspan=6 align=right padding=2px><b>Total:</b></td>'
    $count = 0
    foreach ($st in $subtotalFrg) { 
      $table += "<td>$([int]$subtotalFrg[$count])/$([int]$subtotaldth[$count])</td>"
      $count += 1 
      if ($count -in $timeBlock, ([math]::Floor($round1EndTime / 60))) { $table += "<td></td>" }
    }
    $table += "</tr></tfoot>`n"

    $htmlOut += "<table id=`"perMinFragDeath`" style=`"display:inline-table`">"
    $htmlOut += $tableHeader      
    $htmlOut += $table            
    $htmlOut += "</table>`n"        

    ###
    # Damage per mins
    ###
    $htmlOut += "<hr><h2>Per Minute - Damage <i>(excluding friendly-fire)</i></h2>`n"  

    $table = ''
    $subtotalDmg = @(1..$timeBlock | foreach { 0 } )
    $count = 1

    $tableHeader = $tableHeader -replace '>Kills<', '>Dmg<'

    foreach ($p in $playerList) {
      $dmg = ($arrPlayerTable | Where Name -eq $p | Measure Dmg -Sum).Sum
      $death = ($arrPlayerTable | Where Name -eq $p | Measure Death -Sum).Sum
      $tKill = ($arrPlayerTable | Where Name -eq $p | Measure TKill -Sum).Sum
      $table += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($dmg)</td><td>$($death)</td><td>$($tKill)</td>"
      
      $count2 = 0  
      foreach ($min in 1..$timeBlock) {
        $key = "$($min)_$($p)"
        $dmg = $arrDmgMin.$key
        if ($kills -eq '' -or $kills -lt 1) { $kills = 0 }

        $table += "<td class=`"$((nullValueColorCode $dmg $ccGreen))`" width=40px>$($dmg)</td>"

        $subtotalDmg[$count2] += $dmg

        if ($min -in $timeBlock, ([math]::Floor($round1EndTime / 60))) {
          #rnd total
          if ($min -le ([math]::Floor($round1EndTime / 60))) {
            $round = 1
          }
          else {
            $round = 2
          }
          $dmg = ($arrPlayerTable | Where { $_.Name -eq $p -and $_.Round -eq $round } | Measure Dmg -Sum).Sum
          $table += "<td>$($dmg)</td>"
        }

        $count2 += 1
      }

      $table += "</tr>`n"
      $count += 1 
    }

    $table += '<tfoot><tr id="TotalRow"><td colspan=6 align=right padding=2px><b>Total:</b></td>'

    $count = 0
    foreach ($st in $subtotalDmg) { 
      $table += "<td>$($subtotalDmg[$count])</td>"
      $count += 1

      if ($count -in $timeBlock, ([math]::Floor($round1EndTime / 60))) { $table += "<td></td>" }
    }
    $table += "</tr></tfoot>`n"

    $htmlOut += "<table id=`"perMinDamage`" style=`"display:inline-table`">"
    $htmlOut += $tableHeader      
    $htmlOut += $table            
    $htmlOut += "</table>`n"        


    ###
    # Flag Cap/Took/Drop per min
    ###
    $htmlOut += "<hr><h2>Per Minute - Flag stats</h2>`n"  

    $tableHeader = "<table id=`"perMinFlag`" style=""width:30%;display:inline-table"">
    <thead><tr><th colspan=8></ht><th colspan=$([math]::Ceiling($round1EndTime / 60))>Rnd1 <i>(Cp/Tk/Thr or Stop)</i></ht><th colspan=$($timeBlock - $([math]::Ceiling($round1EndTime / 60)))>Rnd2 <i>(Cp/Tk/Thr or Stop)</i></th></tr>
    <tr><th>#</th><th>Player</th><th>Team</th><th title='Flags captures'>Caps</th><th title='Flag pickups'>Took</th><th title='Flag throws'>Throw</h><th title='Time flag held'>Time</h><th title='Times killed flag carrier'>Stop</h>"
    $table = ''

    foreach ($min in 1..$timeBlock) { $tableHeader += "<th>$($min)</th>" }
    $tableHeader += "</tr></thead>`n"
    
    $count = 1
    $subtotalCap = @(1..$timeBlock | foreach { 0 } )
    $subtotalTook = @(1..$timeBlock | foreach { 0 } )
    $subtotalThrow = @(1..$timeBlock | foreach { 0 } )

    foreach ($p in $playerList) {    
      #$pos = arrFindPlayer -Table ([ref]$arrPlayerTable) -Player $p 
      $table += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td>
                    <td>$(($arrPlayerTable | Where {$_.Name -eq $p } | Measure FlagCap   -Sum).Sum)</td>
                    <td>$(($arrPlayerTable | Where {$_.Name -eq $p } | Measure FlagTake  -Sum).Sum)</td>
                    <td>$(($arrPlayerTable | Where {$_.Name -eq $p } | Measure FlagThrow -Sum).Sum)</td>
                    <td>$("{0:m\:ss}" -f [timespan]::FromSeconds( ($arrPlayerTable | Where {$_.Name -eq $p } | Measure FlagTime -Sum).Sum ) )</td>
                    <td>$(($arrPlayerTable | Where {$_.Name -eq $p } | Measure FlagStop -Sum).Sum)</td>"
      
      $count2 = 0
      foreach ($min in 1..$timeBlock) {
        $key = "$($min)_$($p)"
        $cap = $arrFlagCapMin.$key
        $took = $arrFlagTookMin.$key
        $throw = $arrFlagThrowMin.$key
        $stop = $arrFlagStopMin.$key

        if ($cap -in '', $null -and $took -in '', $null) { 
          if ($Stop -notin '', $null) {
            $value = $stop
            $cellCC = $ccAmber
          }
          else {
            $value = ''
            $cellCC = nullValueColorCode
          }
        }
        else {
          $subtotalCap[$count2] += $cap
          if ($took -in '', $null) { $took = 0 }
          $subtotalTook[$count2] += $Took
          if ($throw -in '', $null) { $throw = 0 }
          $subtotalThrow[$count2] += $Throw
          $cellCC = $ccGreen
          if ($cap -in '', $null) { $cap = '0'; $cellCC = $ccOrange }
          $value = "$($cap)/$($Took)/$($throw)"
        }

        $table += "<td class=`"$($cellCC)`">$($value)</td>"
        $count2 += 1
      }

      $table += "</tr>`n"
      $count += 1 
    }

    $table += '<tfoot><tr id="TotalRow"><td colspan=8 align=right padding=2px><b>Total:</b></td>'
    $count = 0
    foreach ($st in $subtotalCap) { 
      $table += "<td>$($subtotalCap[$count])/$($subtotalTook[$count])/$($subtotalThrow[$count])</td>"
      $count += 1
    }
    $table += "</tr></tfoot>`n"

    $htmlOut += $tableHeader      
    $htmlOut += $table
    $htmlOut += "</table>`n"

    Remove-Variable cellCC, value, took, cap, key, subtotalCap, subtotalTook

    ###
    # Class related tables....
    ###

    $count = 1
    $tableHeader = "<table id=`"classKills`" >
    <thead><tr><th colspan=4></th><th colspan=9>Rnd1</th><th colspan=9>Rnd2</th></tr>
    <tr><th>#</th><th>Player</th><th>Team</th><th title='Kills'>Kills</th>
    <th>Sco</th>
    <th>Sold</th>
    <th>Demo</th>
    <th>Med</th>
    <th>HwG</th>
    <th>Pyro</th>
    <th>Spy</th>
    <th>Eng</th>
    <th>SG</th>
    <th>Sco</th>
    <th>Sold</th>
    <th>Demo</th>
    <th>Med</th>
    <th>HwG</th>
    <th>Pyro</th>
    <th>Spy</th>
    <th>Eng</th>
    <th>SG</th></tr></thead>`n"

    $table = ''
    $subtotalFrg = @($ClassAllowedwithSG | foreach { 0 }) + @($ClassAllowedwithSG | foreach { 0 })
    $subtotalDth = @($ClassAllowedwithSG | foreach { 0 }) + @($ClassAllowedwithSG | foreach { 0 })

    foreach ($p in $playerList) { 
      $kills = ($arrPlayerTable | Where Name -eq $p | Measure Kills -sum).Sum
      $table += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($kills)</td>"
      
      $count2 = 0
      foreach ($round in 1..2) {
        foreach ($o in ($ClassAllowedwithSG)) {
          $kills = ($arrWeaponTable | Where { $_.Name -eq $p -and $_.Round -eq $round -and $_.Class -eq $o } | Measure-Object Kills -Sum).Sum
          $dth   = ($arrWeaponTable | Where { $_.Name -eq $p -and $_.Round -eq $round -and $_.PlayerClass -eq $o } | Measure-Object Death -Sum).Sum
          
          if ($kills + $dth -gt 0) {
            $table += "<td>$($kills)/$($dth)</td>"
          }
          else {
            $table += "<td class=`"$ccGrey`"></td>"
          }

          $subtotalFrg[$count2] += $kills
          $subtotalDth[$count2] += $dth
          $count2 += 1
        }
      }

      $table += "</tr>`n"
      $count += 1 
    }

    $table += '<tfoot><tr id="TotalRow"><td colspan=4 align=right padding=2px><b>Total:</b></td>'
    $count = 0
    foreach ($st in $subtotalFrg) { $table += "<td>$(if (0 -ne $subtotalFrg[$count] + $subtotalDth[$count]) { "$($subtotalFrg[$count])/$($subtotalDth[$count])" })</td>"; $count++ }
    $htmlOut += '</tr></tfoot>'

    #$htmlOut += '<hr><div class="row">'             
    #$htmlOut += '<div class="column" style="width:550px;display:inline-table;padding-right:5px">' 
    $htmlOut += "<hr><h2>Kills/Deaths By Class</h2>`n"  
    $htmlOut += $tableHeader                        
    $htmlOut += $table                              
    $htmlOut += '</table>'      
    #$htmlOut += '</div><div class="column" style="width:550px;display:inline-table">' 


    $table = ''
    $tableHeader = "<table id=`"classTime`" ><thead><tr><th colspan=3></th><th colspan=9>Rnd1</th><th colspan=9>Rnd2</th></tr>
    <tr><th>#</th><th>Player</th><th>Team</th><th title='Kill-death ratio'>K/D</h>
    <th>Sco</th><th>Sold</th><th>Demo</th><th>Med</th><th>HwG</th><th>Pyro</th><th>Spy</th><th>Eng</th>
    <th>K/D</h><th>Sco</th><th>Sold</th><th>Demo</th><th>Med</th><th>HwG</th><th>Pyro</th><th>Spy</th><th>Eng</th>
    </tr></thead>"

    $count = 1
    foreach ($p in $playerList) {
      $table += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td>"
        
      foreach ($r in 1..2) {
        $pos = arrFindPlayer -Table ([ref]$arrPlayerTable) -Player $p -Round $r
        if ($arrPlayerTable[$pos].Death -in 0, '', $null) { $kd = 'n/a' }
        else { $kd = [math]::Round( $arrPlayerTable[$pos].Kills / $arrPlayerTable[$pos].Death , 2) }

        $table += "<td>$($kd)</td>"

        $count2 = 1
        $pr = $arrClassTimeTable | Where-Object { $_.Name -eq $p -and $_.Round -eq $r }

        foreach ($o in $ClassAllowedStr) {
          if ($pr.$o -lt 1) { $time = '' }
          else { $time = "{0:m\:ss}" -f [timespan]::FromSeconds($pr.$o) }

          if ($time) { $table += "<td>$($time)</td>" }
          else { $table += "<td class=`"$ccGrey`"></td>" }
          $count2 += 1
        }
      }
      $table += "</tr>`n"
      $count += 1 
    }

      
    #'<div class="column">'                
    $htmlOut += "<hr><h2>Estimated Time per Class</h2>`n"
    $htmlOut += $tableHeader                          
    $htmlOut += $table                                
    $htmlOut += '</table>'          
    #$htmlOut += '</div></div>'          

    #Stats for each player
    $htmlOut += "<hr><h2>Player Weapon Stats </h2>`n"   

    $count = 1
    $table = ''
    $tableHeader = "<table id=`"weaponStats$count`"><tr><th colspan=`"2`"></th><th colspan=`"6`">Rnd1</th><th colspan=`"6`">Rnd2</th></tr>"
    $tableHeader += "<tr><th>Weapon</th><th>Class</th><th>Shots</th><th>Hit%</th><th>Kills</th><th>Dmg</th><th>Dth</th><th>DmgT</th><th>Shots</th><th>Hit%</th><th>Kills</th><th>Dmg</th><th>Dth</th><th>DmgT</th></tr>`n"

    $divCol = 1
    $htmlOut += '<div class="row">' 
    $htmlOut += '<div class="column" style="width:600;display:inline-table">' 
    $htmlOut += '<h3>Team 1</h3>' 

    foreach ($p in $playerList) { 
      if ($divCol -eq 1 -and $arrTeam.$p -gt 1) {
        $htmlOut += '</div><div class="column" style="width:600;display:inline-table">' 
        $htmlOut += '<h3>Team 2</h3>' 
        $divCol += 1
      }

      $htmlOut += "<hr><h4>$($p)</h4>"

      foreach ($rnd in 1..2) {
        $pClassKeys = @()
        $totalTime = 0
        $classStats = ''
        $pClassKeys = getPlayerClasses $rnd $p
        $pr = ($arrClassTimeTable | Where-Object { $_.Name -eq $p -and $_.Round -eq $rnd})
        $totalTime = arrClassTable-GetPlayerTotal $pr
        if ($totalTime -gt 0) {
          foreach ($i in ($pClassKeys -split ',')) { $classStats += "$i ($('{0:p0}' -f ($pr.$i / $totalTime))) " } 
        }
      
        $htmlOut += "<b>Rnd$($rnd):</b> $($classStats) $(if ($rnd -eq 1) {'|'}) " 
      }
      Remove-Variable pClassKeys, totalTime, classStats

      $playerStats = ''
      $lastClass = ''
      $totKill = @(0, 0, 0)
      $totDmg = @(0, 0, 0)
      $totDth = @(0, 0, 0)
      $totDmgTk = @(0, 0, 0)
      $foundFF = 0

      $allWeapKeys = $arrWeaponTable | Where { $_.Name -eq $p -and $_.Weapon -notmatch '^(world|suicide|.*-ff)$' } `
      | Group-Object Class, Weapon `
      | % { $_.Group | Select Class, Weapon -First 1 } `
      | Sort-Object Class, Weapon
      $allWeapKeys += $arrWeaponTable | Where { $_.Name -eq $p -and $_.Weapon -match '^(world|suicide|.*-ff)$' } `
      | Group-Object Class, Weapon `
      | % { $_.Group | Select Class, Weapon -First 1 } `
      | Sort-Object Class, Weapon

      foreach ($w in $allWeapKeys) {
        if ($w.Class -eq 10) { $class = 9 }
        else { $class = $w.Class }
        $weapon = $w.Weapon

        $objRnd1 = [PSCustomObject]@{ Name = $p; Class = $class; Kills = 0; Dmg = 0; Death = 0; DmgTaken = 0; AttackCount = 0; HitPercent = ''; pos = 1 }
        $objRnd2 = [PSCustomObject]@{ Name = $p; Class = $class; Kills = 0; Dmg = 0; Death = 0; DmgTaken = 0; AttackCount = 0; HitPercent = ''; pos = 2 }
        
        foreach ($o in @($objRnd1, $objRnd2)) {
          $o.Kills = ($arrWeaponTable | Where { $_.Name -eq $p -and $_.Class -eq $w.Class -and $_.Round -eq $o.pos -and $_.Weapon -eq $weapon } | Measure-Object Kills -Sum).Sum
          $o.Dmg = ($arrWeaponTable | Where { $_.Name -eq $p -and $_.Class -eq $w.Class -and $_.Round -eq $o.pos -and $_.Weapon -eq $weapon } | Measure-Object Dmg -Sum).Sum
          $o.Death = ($arrWeaponTable | Where { $_.Name -eq $p -and $_.Class -eq $w.Class -and $_.Round -eq $o.pos -and $_.Weapon -eq $weapon } | Measure-Object Death -Sum).Sum
          $o.DmgTaken = ($arrWeaponTable | Where { $_.Name -eq $p -and $_.Class -eq $w.Class -and $_.Round -eq $o.pos -and $_.Weapon -eq $weapon } | Measure-Object DmgTaken -Sum).Sum
          $o.AttackCount = ($arrWeaponTable | Where { $_.Name -eq $p -and $_.Class -eq $w.Class -and $_.Round -eq $o.pos -and $_.Weapon -eq $weapon } | Measure-Object AttackCount -Sum).Sum
          
          if ($o.AttackCount -gt 0) {
            $o.HitPercent = ($arrWeaponTable | Where { $_.Name -eq $p -and $_.Class -eq $w.Class -and $_.Round -eq $o.pos -and $_.Weapon -eq $weapon } | Measure-Object DmgCount -Sum).Sum / $o.AttackCount
          }
        }    

        if ($class -ne $lastClass -and $foundFF -lt 1) {        
          if ($lastClass -ne '') {
            $playerStats += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td colspan=2 align=right><b>$($ClassToStr[$lastClass]) Totals:</b></td>
                              <td></td><td></td><td>$(nullValueAsBlank $totKill[0])</td><td>$(nullValueAsBlank $totDmg[0])</td><td>$(nullValueAsBlank $totDth[0])</td><td>$(nullValueAsBlank $totDmgTk[0])</td>
                              <td></td><td></td><td>$(nullValueAsBlank $totKill[1])</td><td>$(nullValueAsBlank $totDmg[1])</td><td>$(nullValueAsBlank $totDth[1])</td><td>$(nullValueAsBlank $totDmgTk[1])</td></tr>"
            #<td></td><td></td><td>$(nullValueAsBlank $totKill[2])</td><td>$(nullValueAsBlank $totDmg[2])</td><td>$(nullValueAsBlank $totDth[2])</td><td>$(nullValueAsBlank $totDmgTk[2])</td></tr>"
          }
          
          if ($weapon -match '(world|suicide|-ff)$') { $foundFF++ }
          
          $lastClass = $class
          $totKill = @(0, 0, 0)
          $totDmg = @(0, 0, 0)
          $totDth = @(0, 0, 0)
          $totDmgTk = @(0, 0, 0)
        }

        $totKill[0] += [double]$objRnd1.Kills; $totKill[1] += [double]$objRnd2.Kills; $totKill[2] = ([double]$totKill[0] + [double]$totKill[1])
        $totDmg[0] += [double]$objRnd1.Dmg; $totDmg[1] += [double]$objRnd2.Dmg; $totDmg[2] = ([double]$totDmg[0] + [double]$totDmg[1])  
        $totDth[0] += [double]$objRnd1.Death; $totDth[1] += [double]$objRnd2.Death; $totDth[2] = ([double]$totDth[0] + [double]$totDth[1])
        $totDmgTk[0] += [double]$objRnd1.DmgTaken; $totDmgTk[1] += [double]$objRnd2.DmgTaken; $totDmgTk[2] = ([double]$totDmgTk[0] + [double]$totDmgTk[1])
        
        if ($weapon -match '^(world|suicide|.*-ff$)') {
          $ccNormOrSuicide = $ccAmber
        }
        else {
          $ccNormOrSuicide = $ccOrange
        }

        <# Removed Sub totals - too large
        $subTotalShot  = $objRnd1.AttackCount + $objRnd2.AttackCount
        $subTotalHit   = $objRnd1.HitPercent + $objRnd2.HitPercent
        if ($subTotalHit -gt 0) { 
          $subTotalHit = $subTotalHit / ( ($objRnd1.AttackCount -gt 0 | %{ if ($_) { [int]1 } }) `
                                        + ($objRnd2.AttackCount -gt 0 | %{ if ($_) { [int]1 } }) )
        } else { $subTotalHit = '' } 

        $subTotalKill  = $objRnd1.Kills    + $objRnd2.Kills
        $subTotalDmg   = $objRnd1.Dmg      + $objRnd2.Dmg
        $subTotalDth   = $objRnd1.Death    + $objRnd2.Death
        $subTotalDmgTk = $objRnd1.DmgTaken + $objRnd2.DmgTaken#>

        $playerStats += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td>$($weapon)</td><td>$($ClassToStr[$class])</td>
                          <td class=`"$(nullValueColorCode ($objRnd1.AttackCount) $ccGreen)`">$(nullValueAsBlank $objRnd1.AttackCount)</td>
                            <td class=`"$(nullValueColorCode ($objRnd1.HitPercent) $ccGreen)`">$('{0:P0}' -f (nullValueAsBlank $objRnd1.HitPercent))</td>
                            <td class=`"$(nullValueColorCode ($objRnd1.Kills) $ccGreen)`">$(nullValueAsBlank $objRnd1.Kills)</td>
                            <td class=`"$(nullValueColorCode ($objRnd1.Dmg) $ccGreen)`">$(nullValueAsBlank $objRnd1.Dmg)</td>
                            <td class=`"$(nullValueColorCode ($objRnd1.Death) $ccNormOrSuicide)`">$(nullValueAsBlank $objRnd1.Death)</td>
                            <td class=`"$(nullValueColorCode ($objRnd1.DmgTaken) $ccNormOrSuicide)`">$(nullValueAsBlank $objRnd1.DmgTaken)</td>
                          <td class=`"$(nullValueColorCode ($objRnd2.AttackCount) $ccGreen)`">$(nullValueAsBlank $objRnd2.AttackCount)</td>
                            <td class=`"$(nullValueColorCode ($objRnd2.HitPercent) $ccGreen)`">$('{0:P0}' -f (nullValueAsBlank $objRnd2.HitPercent))</td>
                            <td class=`"$(nullValueColorCode ($objRnd2.Kills) $ccGreen)`">$(nullValueAsBlank $objRnd2.Kills)</td>
                            <td class=`"$(nullValueColorCode ($objRnd2.Dmg) $ccGreen)`">$(nullValueAsBlank $objRnd2.Dmg)</td>
                            <td class=`"$(nullValueColorCode ($objRnd2.Death) $ccNormOrSuicide)`">$(nullValueAsBlank $objRnd2.Death)</td>
                            <td class=`"$(nullValueColorCode ($objRnd2.DmgTaken) $ccNormOrSuicide)`">$(nullValueAsBlank $objRnd2.DmgTaken)</td></tr>`n"
        <# Removed Sub totals - too large
                            <td class=`"$(nullValueColorCode $subTotalShot    $ccGreen)`">$(nullValueAsBlank $subTotalShot)</td>
                            <td class=`"$(nullValueColorCode $subTotalHit   $ccGreen)`">$('{0:P0}' -f (nullValueAsBlank $subTotalHit))</td>
                            <td class=`"$(nullValueColorCode $subTotalKill  $ccGreen)`">$(nullValueAsBlank $subTotalKill)</td>
                            <td class=`"$(nullValueColorCode $subTotalDmg   $ccGreen)`">$(nullValueAsBlank $subTotalDmg)</td>    
                            <td class=`"$(nullValueColorCode $subTotalDth   $ccNormOrSuicide)`">$(nullValueAsBlank $subTotalDth)</td>
                            <td class=`"$(nullValueColorCode $subTotalDmgTk $ccNormOrSuicide)`">$(nullValueAsBlank $subTotalDmgTk)</td></tr>`n"#>

      } #end foreach

      if ($foundFF) { $lastClass = 'Friendly' }
      
      $playerStats += "<tr class=`"$(teamColorCode $arrTeam.$p)`"><td colspan=2 align=right><b>$($lastClass) Totals:</b></td>
                      <td></td><td></td><td>$(nullValueAsBlank $totKill[0])</td><td>$(nullValueAsBlank $totDmg[0])</td><td>$(nullValueAsBlank $totDth[0])</td><td>$(nullValueAsBlank $totDmgTk[0])</td>
                      <td></td><td></td><td>$(nullValueAsBlank $totKill[1])</td><td>$(nullValueAsBlank $totDmg[1])</td><td>$(nullValueAsBlank $totDth[1])</td><td>$(nullValueAsBlank $totDmgTk[1])</td></tr>`n"
      #<td></td><td></td><td>$(nullValueAsBlank $totKill[2])</td><td>$(nullValueAsBlank $totDmg[2])</td><td>$(nullValueAsBlank $totDth[2])</td><td>$(nullValueAsBlank $totDmgTk[2])</td></tr>`n"

      $htmlOut += $tableHeader       
      $htmlOut += $playerStats       
      $htmlOut += "</table>`n"         


      $count += 1 
    }

    $htmlOut += '</div></div>' 
    $htmlOut += "<script>
                FO_Post();
              </script>"
    $htmlOut += "</body></html>"

    $htmlOut | Out-File -LiteralPath "$outFileStr.html" -Encoding utf8
    if ($OpenHTML) { & "$outFileStr.html" }
  }   #end html generation



  ## Object/Table for Text-base Summaries
  $arrResultTable += [pscustomobject]@{ 
    Match  = $jsonFile.BaseName -replace '_blue_vs_red.*', ''
    Winner = switch ($arrResult.winningTeam) { '0' { "Draw" }; "1" { "Team1" }; "2" { "Team2" } } 
    Rating = $arrResult.winRating
    Score1 = $arrResult.team1Score
    Score2 = $arrResult.team2Score
    Team1  = ($playerlist | ForEach-Object { if ($arrTeam.$_ -match "1") { $_ } }) -join ','
    Team2  = ($playerlist | ForEach-Object { if ($arrTeam.$_ -match "2") { $_ } }) -join ','
  }

  foreach ($p in $playerList) {
    #Data that is seperated by round - work out whos att and def.
    foreach ($round in 1..2) {
      $pos = arrFindPlayer ([ref]$arrPlayerTable) $p -Round $round
      if ($pos -eq -1) { continue } # Did not play this round

      $aod = (attOrDef $round (Get-Variable "arrTeamRnd$round").Value.$p)
      if ($aod -ne '') {    
        if (    $aod -eq 'Att') { $refSummary = ([ref]$arrSummaryAttTable); $refClassTime = ([ref]$arrClassTimeAttTable); $refClassFrag = ([ref]$arrClassFragAttTable) }
        elseif ($aod -eq 'Def') { $refSummary = ([ref]$arrSummaryDefTable); $refClassTime = ([ref]$arrClassTimeDefTable); $refClassFrag = ([ref]$arrClassFragDefTable) }

        arrSummaryTable-UpdatePlayer -table $refSummary -player $p  -kills ([int]$arrPlayerTable[$pos].Kills)  `
          -death ([int]$arrPlayerTable[$pos].Death) `
          -tkill ([int]$arrPlayerTable[$pos].TKill)
        arrSummaryTable-SetPlayerProperty -table $refSummary -player $p -property 'Dmg' -value ([double]$arrPlayerTable[$pos].Dmg)
  
        foreach ($i in $ClassAllowedWithSG) {
          $time = [int]($arrClassTimeTable | Where-Object { $_.Name -eq $p -and $_.Round -eq $round}).($ClassToStr[$i])
          $kills = ($arrWeaponTable | Where-Object { $_.Name -eq $p -and $_.Class -eq $i -and $_.Round -eq $round } | Measure-Object Kills -Sum).Sum
          $class = ($ClassToStr[$i])
          
          if ($time -gt 0) {
            arrClassTable-UpdatePlayer -table $refClassTime -player $p -class $class -value ([int]$time)
            arrSummaryTable-SetPlayerProperty -table $refSummary -player $p -property 'TimePlayed' -value ([int]$time)
          }
  
          if ($kills -gt 0) {
            arrClassTable-UpdatePlayer -table $refClassFrag -player $p -class $class -value $kills
          }
        }
      }
    }

    #Data that are not divded up by round
    switch ($arrResult.winningTeam) {
      { $_ -eq '0' -or 
        $arrTeam.$p -match "[1-2]&[1-2]" } { 
        arrSummaryTable-SetPlayerProperty -table ([ref]$arrSummaryAttTable) -player $p -property 'Draw'
        arrSummaryTable-SetPlayerProperty -table ([ref]$arrSummaryDefTable) -player $p -property 'Draw'
      }
      $arrPlayerTable[$pos].Team {
        arrSummaryTable-SetPlayerProperty -table ([ref]$arrSummaryAttTable) -player $p -property 'Win'
        arrSummaryTable-SetPlayerProperty -table ([ref]$arrSummaryDefTable) -player $p -property 'Win'
      }
      Default { 
        arrSummaryTable-SetPlayerProperty -table ([ref]$arrSummaryAttTable) -player $p -property 'Loss'
        arrSummaryTable-SetPlayerProperty -table ([ref]$arrSummaryDefTable) -player $p -property 'Loss'
      }
    }

    arrSummaryTable-SetPlayerProperty -table ([ref]$arrSummaryAttTable) -player $p -property 'FlagCap'  -value (($arrPlayerTable | Where Name -EQ $p | Measure FlagCap -Sum).Sum)
    arrSummaryTable-SetPlayerProperty -table ([ref]$arrSummaryAttTable) -player $p -property 'FlagTake' -value (($arrPlayerTable | Where Name -EQ $p | Measure FlagTake -Sum).Sum)
    arrSummaryTable-SetPlayerProperty -table ([ref]$arrSummaryAttTable) -player $p -property 'FlagTime' -value (($arrPlayerTable | Where Name -EQ $p | Measure FlagTime -Sum).Sum)
    arrSummaryTable-SetPlayerProperty -table ([ref]$arrSummaryDefTable) -player $p -property 'FlagStop' -value (($arrPlayerTable | Where Name -EQ $p | Measure FlagStop -Sum).Sum)
  }
}


#Value Per Minute
function Table-CalculateVPM {
  param($Value, $TimePlayed, $Round)
  
  if ($Value -eq 0) { return $null }
  if ($Round -in '', $null) { $Round = 2 }

  if (!$TimePlayed) { return '' }
  return [math]::Round($Value / ($TimePlayed / 60), $Round)
}

$textOut = ''
$textOut += "###############"
$textOut += "`n   Game Log "
$textOut += "`n###############"
$textOut += $arrResultTable | Format-Table Match, Winner, @{L = 'Rating'; E = { '{0:P0}' -f $_.Rating } }, Score1, Team1, Score2, Team2 -Wrap | Out-String

$textOut += "`n##############$(if ($jsonFileCount -gt 1) { "##############" })"
$textOut += "`n FINAL TOTALS $(if ($jsonFileCount -gt 1) { " - $jsonFileCount games" })"
$textOut += "`n##############$(if ($jsonFileCount -gt 1) { "##############" })`n"
$textOut += "`nAttack Summary`n"

# Update the Attack Table into presentation format
foreach ($i in $arrSummaryAttTable) {
  $i.KPM = Table-CalculateVPM $i.Kills $i.TimePlayed
  if ($i.Death) { $i.KD = [math]::Round($i.Kills / $i.Death, 2) }
  $i.DPM = Table-CalculateVPM $i.Dmg $i.TimePlayed 0
  $i.Classes = (Table-ClassInfo ([ref]$arrClassTimeAttTable) $i.Name $i.TimePlayed)
  $i.FlagTime = "{0:m\:ss}" -f [timespan]::FromSeconds( $i.FlagTime )
  $i.TimePlayed = Format-MinSec $i.TimePlayed
}

$textOut += $arrSummaryAttTable | Format-Table Name, KPM, KD, Kills, Death, TKill, @{L = 'Dmg'; E = { '{0:n0}' -f $_.Dmg } }, @{L = 'DPM'; E = { '{0:n0}' -f $_.DPM } }, @{L = 'FlagCap'; E = { '{0:n0}' -f $_.FlagCap } }, @{L = 'FlagTake'; E = { '{0:n0}' -f $_.FlagTake } }, FlagTime, TimePlayed, Classes | Out-String

# Update the Def Table into presentation format
foreach ($j in $arrSummaryDefTable) {
  $j.KPM = Table-CalculateVPM $j.Kills $j.TimePlayed
  $j.KD = [math]::Round($j.Kills / $j.Death, 2)
  $j.DPM = Table-CalculateVPM $j.Dmg $j.TimePlayed 0
  $j.Classes = (Table-ClassInfo ([ref]$arrClassTimeDefTable) $j.Name $j.TimePlayed)
  $j.TimePlayed = Format-MinSec $j.TimePlayed
}

$textOut += "Defence Summary`n"
$textOut += $arrSummaryDefTable | Format-Table Name, KPM, KD, Kills, Death, TKill, @{L = 'Dmg'; E = { '{0:n0}' -f $_.Dmg } }, @{L = 'DPM'; E = { '{0:n0}' -f $_.DPM } }, @{L = 'FlagStop'; E = { '{0:n0}' -f $_.FlagStop } }, Win, Draw, Loss, TimePlayed, Classes | Out-String

$textOut += "Class Kills / KPM Summary - Attack`n"
$textOut += $arrClassFragAttTable  | Format-Table Name, Sco, @{L = 'KPM'; E = { Table-CalculateVPM $_.Sco ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Sco } }, `
  Sold, @{L = 'KPM'; E = { Table-CalculateVPM $_.Sold ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Sold } }, `
  Demo, @{L = 'KPM'; E = { Table-CalculateVPM $_.Demo ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Demo } }, `
  Med, @{L = 'KPM'; E = { Table-CalculateVPM $_.Med  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Med } }, `
  HwG, @{L = 'KPM'; E = { Table-CalculateVPM $_.HwG  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).HwG } }, `
  Pyro, @{L = 'KPM'; E = { Table-CalculateVPM $_.Pyro ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Pyro } }, `
  Spy, @{L = 'KPM'; E = { Table-CalculateVPM $_.Spy  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Spy } }, `
  Eng, @{L = 'KPM'; E = { Table-CalculateVPM $_.Eng  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Eng } }, `
  SG, @{L = 'KPM'; E = { Table-CalculateVPM $_.SG   ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Eng } }  `
| Out-String
   
$textOut += "Class Kills / KPM Summary - Defence`n"
$textOut += $arrClassFragDefTable  | Format-Table Name, Sco, @{L = 'KPM'; E = { Table-CalculateVPM $_.Sco ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Sco } }, `
  Sold, @{L = 'KPM'; E = { Table-CalculateVPM $_.Sold ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Sold } }, `
  Demo, @{L = 'KPM'; E = { Table-CalculateVPM $_.Demo ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Demo } }, `
  Med, @{L = 'KPM'; E = { Table-CalculateVPM $_.Med  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Med } }, `
  HwG, @{L = 'KPM'; E = { Table-CalculateVPM $_.HwG  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).HwG } }, `
  Pyro, @{L = 'KPM'; E = { Table-CalculateVPM $_.Pyro ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Pyro } }, `
  Spy, @{L = 'KPM'; E = { Table-CalculateVPM $_.Spy  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Spy } }, `
  Eng, @{L = 'KPM'; E = { Table-CalculateVPM $_.Eng  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Eng } }, `
  SG, @{L = 'KPM'; E = { Table-CalculateVPM $_.SG   ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Eng } }  `
| Out-String


<# Moved class time to % in summary table.
$textOut += "`nClass Time Played - Attack`n"
$textOut += $arrClassTimeAttTable | Format-Table Name, `
                                     @{L='Sco' ; E={Format-MinSec $_.Sco}}, `
                                     @{L='Sold'; E={Format-MinSec $_.Sold}}, `
                                     @{L='Demo'; E={Format-MinSec $_.Demo}}, `
                                     @{L='Med' ; E={Format-MinSec $_.Med}}, `
                                     @{L='HwG' ; E={Format-MinSec $_.HwG}}, `
                                     @{L='Pyro'; E={Format-MinSec $_.Pyro}}, `
                                     @{L='Spy' ; E={Format-MinSec $_.Spy}}, `
                                     @{L='Eng' ; E={Format-MinSec $_.Eng}}  `
                                  | Out-String
$textOut += "`nClass Time Played - Defence`n"
$textOut += $arrClassTimeDefTable | Format-Table Name, `
                                     @{L='Sco' ; E={Format-MinSec $_.Sco}}, `
                                     @{L='Sold'; E={Format-MinSec $_.Sold}}, `
                                     @{L='Demo'; E={Format-MinSec $_.Demo}}, `
                                     @{L='Med' ; E={Format-MinSec $_.Med}}, `
                                     @{L='HwG' ; E={Format-MinSec $_.HwG}}, `
                                     @{L='Pyro'; E={Format-MinSec $_.Pyro}}, `
                                     @{L='Spy' ; E={Format-MinSec $_.Spy}}, `
                                     @{L='Eng' ; E={Format-MinSec $_.Eng}} `
                                  | Out-String
#>

if (!$NoStatJson) {
  $textJsonOut = ([PSCustomObject]@{Matches = ''; SummaryAttack = ''; SummaryDefence = ''; ClassFragAttack = ''; ClassFragDefence = ''; ClassTimeAttack = ''; ClassTimeDefence = '' })
  $textJsonOut.Matches = @($arrResultTable | Select-Object Match, Winner, @{L = 'Rating'; E = { '{0:P0}' -f $_.Rating } }, Score1, Team1, Score2, Team2)

  $textJsonOut.SummaryAttack = [array]($arrSummaryAttTable)  #  | Select-Object -Property Name,KPM,KD,Kills,Death,TKill,Dmg,DPM,FlagStop,Win,Draw,Loss,TimePlayed,Classes)
  $textJsonOut.SummaryDefence = [array]($arrSummaryDefTable) #  | Select-Object -Property Name,KPM,KD,Kills,Death,TKill,Dmg,DPM,FlagStop,Win,Draw,Loss,TimePlayed,Classes)

  $textJsonOut.ClassFragAttack = [array]($arrClassFragAttTable  | Select-Object -Property Name, `
      Sco, @{L = 'KPM1'; E = { Table-CalculateVPM $_.Sco ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Sco } }, `
      Sold, @{L = 'KPM3'; E = { Table-CalculateVPM $_.Sold ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Sold } }, `
      Demo, @{L = 'KPM4'; E = { Table-CalculateVPM $_.Demo ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Demo } }, `
      Med, @{L = 'KPM5'; E = { Table-CalculateVPM $_.Med  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Med } }, `
      HwG, @{L = 'KPM6'; E = { Table-CalculateVPM $_.HwG  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).HwG } }, `
      Pyro, @{L = 'KPM7'; E = { Table-CalculateVPM $_.Pyro ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Pyro } }, `
      Spy, @{L = 'KPM8'; E = { Table-CalculateVPM $_.Spy  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Spy } }, `
      Eng, @{L = 'KPM9'; E = { Table-CalculateVPM $_.Eng  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Eng } }, `
      SG, @{L = 'KPM0'; E = { Table-CalculateVPM $_.SG   ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Eng } })
  $textJsonOut.ClassFragDefence = ($arrClassFragDefTable | Select-Object -Property Name, `
      Sco, @{L = 'KPM1'; E = { Table-CalculateVPM $_.Sco ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Sco } }, `
      Sold, @{L = 'KPM3'; E = { Table-CalculateVPM $_.Sold ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Sold } }, `
      Demo, @{L = 'KPM4'; E = { Table-CalculateVPM $_.Demo ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Demo } }, `
      Med, @{L = 'KPM5'; E = { Table-CalculateVPM $_.Med  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Med } }, `
      HwG, @{L = 'KPM6'; E = { Table-CalculateVPM $_.HwG  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).HwG } }, `
      Pyro, @{L = 'KPM7'; E = { Table-CalculateVPM $_.Pyro ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Pyro } }, `
      Spy, @{L = 'KPM8'; E = { Table-CalculateVPM $_.Spy  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Spy } }, `
      Eng, @{L = 'KPM9'; E = { Table-CalculateVPM $_.Eng  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Eng } }, `
      SG, @{L = 'KPM0'; E = { Table-CalculateVPM $_.SG   ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Eng } })

  $textJsonOut.ClassTimeAttack = [array]($arrClassTimeAttTable  | Select-Object -Property Name, Sco, Sold, Demo, Med, HwG, Pyro, Spy, Eng)
  $textJsonOut.ClassTimeDefence = [array]($arrClassTimeDefTable | Select-Object -Property Name, Sco, Sold, Demo, Med, HwG, Pyro, Spy, Eng)

  if ($jsonFileCount -eq 1) { 
    $TextFileStr = "$($outFileStr)_stats.json"
  }   else {   
    $TextFileStr = "$($inputfile[0].Directory.FullName)\FO_Stats_Summary-$($jsonFileCount)games-$('{0:yyMMdd_HHmmss}' -f (Get-Date)).json"
  }

  write-host $outStr
  ($textJsonOut | ConvertTo-Json) | Out-File -LiteralPath "$($TextFileStr)" -Encoding utf8
  Write-Host "JSON stats saved: $($outFileStr)_stats.json"
}

Write-Host "`n"
Write-Host $textOut

if ($TextSave) {
  if ($jsonFileCount -eq 1) {
    $TextFileStr = "$outFileStr.txt"
  } else {   
    $TextFileStr = "$($inputfile[0].Directory.FullName)\FO_Stats_Summary-$($jsonFileCount)games-$('{0:yyMMdd_HHmmss}' -f (Get-Date)).txt"
  }
  $textOut | Out-File -LiteralPath $TextFileStr -Encoding utf8
  Write-Host "Text stats saved: $TextFileStr"
}


<# test Weap counter
$arrWeaponTable | `  # | Where { ($_.AttackCount + $_.DmgCount) -GT 0 }  `
                 Sort-Object Round,Team,Name,Class,Weapon `
                | FT  *, ` #Name,  `
                      #Team, `
                      #Round, `
                      #Weapon, `
                      #Dmg, `
                      @{L='Shots';E={$_.AttackCount}}, `
                      @{L='Hit%';E={ '{0:P0}' -f ($_.DmgCount / $_.AttackCount) }}, `
                      @{L='DmgPerAtt';E={ '{0,5:n1}' -f ($_.Dmg / $_.AttackCount) }}, `
                      @{L='DmgPerHit';E={ '{0,5:n1}' -f ($_.Dmg / $_.DmgCount) }} -GroupBy Round
 #>
<# Testing New arrClassTimeTable.... the Att/Def is more accurate for some reason
 $arrClassTimetable | FT *,@{L='Total';E={ $_.Sco + $_.Sold + $_.Demo + $_.Hwg + $_.Med + $_.Pyro + $_.Spy + $_.Eng  }}
 # These use the original hash table....
 $arrClassTimeAttTable | FT *,@{L='Total';E={ $_.Sco + $_.Sold + $_.Demo + $_.Hwg + $_.Med + $_.Pyro + $_.Spy + $_.Eng  }}
 $arrClassTimeDefTable | FT *,@{L='Total';E={ $_.Sco + $_.Sold + $_.Demo + $_.Hwg + $_.Med + $_.Pyro + $_.Spy + $_.Eng  }}
 #>


# SIG # Begin signature block
# MIIbngYJKoZIhvcNAQcCoIIbjzCCG4sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUug3lQWFSJqKZFEP3P5GS1hiU
# 6r2gghYTMIIDCDCCAfCgAwIBAgIQVxZN0cTEa7NFKtjIhSbFETANBgkqhkiG9w0B
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
# /JiW9lVUKx+A+sDyDivl1vupL0QVSucTDh3bNzgaoSv27dZ8/DCCBsAwggSooAMC
# AQICEAxNaXJLlPo8Kko9KQeAPVowDQYJKoZIhvcNAQELBQAwYzELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBU
# cnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTAeFw0yMjA5
# MjEwMDAwMDBaFw0zMzExMjEyMzU5NTlaMEYxCzAJBgNVBAYTAlVTMREwDwYDVQQK
# EwhEaWdpQ2VydDEkMCIGA1UEAxMbRGlnaUNlcnQgVGltZXN0YW1wIDIwMjIgLSAy
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAz+ylJjrGqfJru43BDZrb
# oegUhXQzGias0BxVHh42bbySVQxh9J0Jdz0Vlggva2Sk/QaDFteRkjgcMQKW+3Kx
# lzpVrzPsYYrppijbkGNcvYlT4DotjIdCriak5Lt4eLl6FuFWxsC6ZFO7KhbnUEi7
# iGkMiMbxvuAvfTuxylONQIMe58tySSgeTIAehVbnhe3yYbyqOgd99qtu5Wbd4lz1
# L+2N1E2VhGjjgMtqedHSEJFGKes+JvK0jM1MuWbIu6pQOA3ljJRdGVq/9XtAbm8W
# qJqclUeGhXk+DF5mjBoKJL6cqtKctvdPbnjEKD+jHA9QBje6CNk1prUe2nhYHTno
# +EyREJZ+TeHdwq2lfvgtGx/sK0YYoxn2Off1wU9xLokDEaJLu5i/+k/kezbvBkTk
# Vf826uV8MefzwlLE5hZ7Wn6lJXPbwGqZIS1j5Vn1TS+QHye30qsU5Thmh1EIa/tT
# QznQZPpWz+D0CuYUbWR4u5j9lMNzIfMvwi4g14Gs0/EH1OG92V1LbjGUKYvmQaRl
# lMBY5eUuKZCmt2Fk+tkgbBhRYLqmgQ8JJVPxvzvpqwcOagc5YhnJ1oV/E9mNec9i
# xezhe7nMZxMHmsF47caIyLBuMnnHC1mDjcbu9Sx8e47LZInxscS451NeX1XSfRkp
# WQNO+l3qRXMchH7XzuLUOncCAwEAAaOCAYswggGHMA4GA1UdDwEB/wQEAwIHgDAM
# BgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMCAGA1UdIAQZMBcw
# CAYGZ4EMAQQCMAsGCWCGSAGG/WwHATAfBgNVHSMEGDAWgBS6FtltTYUvcyl2mi91
# jGogj57IbzAdBgNVHQ4EFgQUYore0GH8jzEU7ZcLzT0qlBTfUpwwWgYDVR0fBFMw
# UTBPoE2gS4ZJaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3Rl
# ZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNybDCBkAYIKwYBBQUHAQEE
# gYMwgYAwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBYBggr
# BgEFBQcwAoZMaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1
# c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNydDANBgkqhkiG9w0B
# AQsFAAOCAgEAVaoqGvNG83hXNzD8deNP1oUj8fz5lTmbJeb3coqYw3fUZPwV+zbC
# SVEseIhjVQlGOQD8adTKmyn7oz/AyQCbEx2wmIncePLNfIXNU52vYuJhZqMUKkWH
# SphCK1D8G7WeCDAJ+uQt1wmJefkJ5ojOfRu4aqKbwVNgCeijuJ3XrR8cuOyYQfD2
# DoD75P/fnRCn6wC6X0qPGjpStOq/CUkVNTZZmg9U0rIbf35eCa12VIp0bcrSBWcr
# duv/mLImlTgZiEQU5QpZomvnIj5EIdI/HMCb7XxIstiSDJFPPGaUr10CU+ue4p7k
# 0x+GAWScAMLpWnR1DT3heYi/HAGXyRkjgNc2Wl+WFrFjDMZGQDvOXTXUWT5Dmhiu
# w8nLw/ubE19qtcfg8wXDWd8nYiveQclTuf80EGf2JjKYe/5cQpSBlIKdrAqLxksV
# StOYkEVgM4DgI974A6T2RUflzrgDQkfoQTZxd639ouiXdE4u2h4djFrIHprVwvDG
# IqhPm73YHJpRxC+a9l+nJ5e6li6FV8Bg53hWf2rvwpWaSxECyIKcyRoFfLpxtU56
# mWz06J7UWpjIn7+NuxhcQ/XQKujiYu54BNu90ftbCqhwfvCXhHjjCANdRyxjqCU4
# lwHSPzra5eX25pvcfizM/xdMTQCi2NYBDriL7ubgclWJLCcZYfZ3AYwxggT1MIIE
# 8QIBATAwMBwxGjAYBgNVBAMMEUhhemUgQXV0aGVudGljb2RlAhBXFk3RxMRrs0Uq
# 2MiFJsURMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkG
# CSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEE
# AYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTfeQjugn3dqNHR6QkrwxIMEwsenTANBgkq
# hkiG9w0BAQEFAASCAQB+H7bY2Li22xl7vHiKsxNjZvF869FrIKt8TuZvuo6FHSd5
# 8V4jxFPYEhQj987xmQDMQGzQ5GMLBqnD4GDgndOHVWQUAart++ueQSh9Q53J19YQ
# tkzA1ZUqYCNWahi9NgdZtso9Ua8ztidq+CbHSox2DhoK/jM2UADtMbn0esarerE0
# 4m8bBY9xGzPdgHcFpfRbnk2vtEkfQJEpQCTT6hjOcMTLbJC4SAqVc4S57P+xdt4I
# 4WCkjuThwjC1caF7pq0iETaSWJ9s43o5wiP9sLGdGg+lVze4HPPmB0mbSrO0Ic45
# 5ABQlfK8UKWUxT2DLB4Yimu6dqqsz2P8+fbNUyGGoYIDIDCCAxwGCSqGSIb3DQEJ
# BjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0
# LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hB
# MjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwqSj0pB4A9WjANBglghkgBZQME
# AgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTIzMDMyMzEwNTkwMVowLwYJKoZIhvcNAQkEMSIEIJZhAszRxOp3T5iDtIwy2GZe
# F4zZdFqxzLFVM7JfsksSMA0GCSqGSIb3DQEBAQUABIICAI/ITYuZdmqdPqbT2P40
# pYHfdY90oBR+iZDGttMqEhy2QhixmZZfauNtn2ypWOGUxAdz5iryylf3HNhxXvlZ
# hjOX0rx8TTdiyYrI8VoDWgysIShoZU0LvGnK+z+ZvlyMHgjXMewDwv+tu/9dKwr9
# KgJqazgafw66lANaEgdyGlvckGEgn0lVi4E4wYwpMCzIEaOeJak2U4d8x/j6LkeZ
# qYfkNRK8BzdHW4ldG2Bf9cxJwn5moNqKmIeQ2AoVejlwKcf2ahAIVQsJMOB2yc5U
# F71EpaASKOc3uqoeMjXInn/1YjDDSbB2L4Q+OLvCqeyhQdALM6EPnahuz/C5znOQ
# XEIUukJ1rDiDXk7QtV9KNZOau0b863WY/gPoubR4u/VuW+M7sSVPzK2ABRmTh8FI
# VGapUiO/yzS8lsQIVn+Yspr8Kj/cH3OEJYuGLEQ40CDTXXgdatL9+sO/dv2bjCaN
# jiE4Org3VfA/DEwD+oiRiK+vkeibDSfrMT4yiJ6u15Z/oddULKBcWW90w1e0CQfl
# Qj/veDnerSR8dTwLwCo5VPDtKbI8c+KefA5z4cTKsi2tJWJcxrPMppAPYiVgn7zs
# cDtScztWAYqwtrEvdzd9lmYPa2kKg5TSzSTkjy2aDMp9WtTuxqGKexEpOY2w8qKm
# M4CvRmFsPXi0igW+eMQykeAp
# SIG # End signature block
