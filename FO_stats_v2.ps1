###
# 22/12/2021
# PS  COMMAND LINE:- & .\FO_stats_v2.ps1 -StatFile 'x:\path\filename.json' [-RoundTime <seconds>] [-TextOnly] [-TextSave]
# WIN COMMAND LINE:- powershell -Command "& .\FO_stats_v2.ps1 -StatFile 'x:\path\filename.json' [-RountTime <seconds>] [-TextOnly] [-TextSave]"
#
# NOTE: StatFile parameter now accepts *.json wildcard to generate many HTMLs, Text stats are ALL STATS COMBINED.
#
# For Text Only stats for many stat files - i.e. not all games combined.
# PS  *.JSON:- foreach ($f in (gci 'x:\stats\*.json')) { & .\FO_stats_v2.ps1 -StatFile ($f.ToString() -replace '\[','`[' -replace '\]','`]') -TextOnly }
###

param (
  [Parameter(Mandatory=$true)] 
  [string]$StatFile,
  [int]   $RoundTime,
  [switch]$TextSave,
  [switch]$TextOnly,
  [switch]$OpenHTML
)


# Process input file, make sure it is valid.
$inputFileStr = $StatFile -replace '(?<!`)[\[\]]','`$&'

if ($inputFileStr -contains '*') { $inputFile = Get-ChildItem $inputFileStr }
elseif (Test-Path $inputFileStr) { $inputFile = @(Get-Item $inputFileStr)  }

# If a folder search for all JSON files
if ($inputFile.Count -eq 1 -and (Test-Path $inputFile -PathType Container)) {
    $inputFile = Get-ChildItem $inputFile -Filter '*.json'
}

if ($inputFile.Length -lt 1)          { Write-Host "ERROR: No JSON files found at '$inputFileStr'"; return }
if ($inputFile -notmatch '.*\.json$') { Write-Host 'ERROR: Following files are not JSON files...'; ($inputFile -notmatch '.*\.json$') | FT Name | Out-String ; return }

$regExReplaceFix = '[[+*?()\\.]','\$&'

$ccGrey   = '#F1F1F1'
$ccAmber  = '#FFD900'
$ccOrange = '#FFB16C'
$ccGreen  = '#96FF8F'
$ccBlue   = '#87ECFF'
$ccRed    = '#FF8080'
$ccPink   = '#FA4CFF'

                       # 0        1     2     3      4      5    6      7     8     9     10
$script:ClassToStr = @('World','Sco','Snp','Sold','Demo','Med','HwG','Pyro','Spy','Eng', 'SG')
$script:ClassAllowedStr = @('Sco','Sold','Demo','Med','HwG','Pyro','Spy','Eng', 'SG')
$script:ClassAllowed       = @(1,3,4,5,6,7,8,9)
$script:ClassAllowedwithSG = @(1,3,4,5,6,7,8,9,10)
$script:TeamToColor  = @('Civ','Blue','Red','Yellow','Green')

#array of team keys, playername
<# wc Old Get Player CLases
function getPlayerClasses {
  return ($args[0] -match "^$($args[1] -replace $regExReplaceFix)_[1-9]`$" | `
            %{ $ClassToStr[($_ -split '_')[1]] } | Sort-Object -Unique) -join ','
}#>

function getPlayerClasses {
  param ($Round,$Player)
  return ($arrClassTimeTable  |  Where { $_.Name -eq $Player -and ($Round -lt 1 -or $_.Round -eq $Round) } `
                              | %{ $_.PSObject.Properties | Where Name -in $ClassAllowedStr | Where Value -gt 0 } `
                              | %{ $_.Name } | Sort -Unique) -join ','
}

function nullValueColorCode {
  switch ($args[0]) {
    ''      { $ccGrey  }
    '0'       { $ccGrey  }
    default { $args[1] }
  }
}

function nullValueAsBlank {
  if ($args[0] -match '^0+%?$') {
    return ''
  } else {
    $args[0]
  }
}

function teamColorCode {
    switch ($args[0]) {
      '1'      { $ccBlue  }
      '2'      { $ccRed   }
       default { $ccPink  } 
    }
}

# Friendly fire is bad
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
}

function timeRnd-RoundDown {
 # p1 = $time , $p2 = roundendtime
 if ($args[0] / 60 -lt 0.4) {
   if ($args[0] -lt $args[1]) { '0' }
   else { $args[1] }
 }else { $time }
}

# Convert weapon names into friendly short names
function weapSN {
  
  switch ($args[0]) {
    ''              { 'NULL'  }
    #common
    'info_tfgoal'   { 'laser' }
    'supershotgun'  { 'ssg'   }
    'shotgun'       { 'sg'    }
    'normalgrenade' { 'hgren' }
    'grentimer'     { 'hgren' }
    'axe'           { 'axe'   }
    'spike'         { 'ng'    }
    'nailgun'       { 'ng'    }
    
    #7/2/23 - New inflictor/weaps??
    'grenade grenadegrenade'   { 'hgren' }
    'red grenadegrenade'       { 'gl'    }
    'mirv grenadegrenade'      { 'mirv'  }
    'mirvlet grenadegrenade'   { 'mirv'  }
    'napalm grenadegrenade'    { 'napalm'}
    'shock grenadegrenade'     { 'shock' }
    'emp grenadegrenade'       { 'emp'   }

    #scout
    'flashgrenade'  { 'flash' }
    
    #sold
    'proj_rocket'    { 'rl'    }
    'rocketlauncher' { 'rl'    }
    'shockgrenade'   { 'shock' }

    #demo 
    'detpack'           { 'detp' }
    'pipebomb'          { 'pipe' }
    'pipebomblauncher'  { 'pipe' }
    'grenade'           { 'gl'   }
    'grenadelauncher'   { 'gl'   }
    'mirvsinglegrenade' { 'mirv' }
    'mirvgrenade'       { 'mirv' }

    #medic
    'medikit'       { 'bio'  }
    'superspike'    { 'sng'  }
    'supernailgun'  { 'sng'  }

    #hwg
    'proj_bullet'   { 'cann' }
    'assaultcannon' { 'cann' }

    #pyro
    'pyro_rocket'   { 'incen' }
    'incendiary'    { 'incen' }
    'flamethrower'  { 'flame'  }
    'fire'          { 'fire'  }
    'flamerflame'   { 'flame' }
    
    #spy - knife
    'proj_tranq'    { 'tranq' }
    'tranquilizer'  { 'tranq' }

    #eng
    'spanner'       { 'spann'}
    'empgrenade'    { 'emp'  }
    'ammobox'       { 'emp'  }
    'sentrygun'     { 'sent' }
    'railslug'      { 'rail' }
    'railgun'       { 'rail' }
    'building_dispenser' { 'disp' }
    'building_sentrygun' { 'sent' }
    'build_timer'        { 'sent' }

    #remove underscore to avoid token key issues.
    default         { $args[0] -replace '_','-' }
  }
}

#Summary table funcitons
function attOrDef {
  if ($args[0] -lt 1 -or $args[0] -gt 2) { return '' }
  elseif ($args[0] -eq $args[1]) { return 'Att'}
  else { return 'Def'} 
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
            Name   = $player
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
    if (!$Value) { $Value = 1}
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
    if ($Class -notin $ClassAllowedStr) { return}
    
    if ($round)  { $playerpos = (arrFindPlayer -Table $Table -Player $Player -Round $round) }
    else         { $playerpos = (arrFindPlayer -Table $Table -Player $Player) }

    #Setup object if plyaer not found
    if ($playerpos -lt 0) {
      $obj = [PSCustomObject]@{
        Name = $Player
        Round= 0
        Sco  = 0
        Sold = 0
        Demo = 0
        Med  = 0
        HwG  = 0
        Pyro = 0
        Spy  = 0
        Eng  = 0
        SG   = 0
      }

      if ($round)  { $obj.Round = $round }
      $playerpos = $table.Value.Length
      $table.Value += $obj
    } 
    $table.Value[$playerpos].$Class += $Value
  }
}

function arrFindPlayer-WeaponTable {
  param( [string]$Name, $Round, [string]$Weapon, $Class )
  
  $count = 0
  foreach ($p in $script:arrWeaponTable) {
    if ($p.Name -eq $Name -and $p.Round -eq $Round -and $p.Weapon -eq $Weapon -and $p.Class -eq $Class) {
      return $count
    }
    $count += 1
  }
  return -1
}

function arrWeaponTable-UpdatePlayer {
  param( [Parameter(Mandatory=$true)][string]$Name,
         [Parameter(Mandatory=$true)][string]$PlayerClass,
         [Parameter(Mandatory=$true)]        $Round,
         [Parameter(Mandatory=$true)][string]$Weapon,
         [Parameter(Mandatory=$true)]        $Class, 
         [Parameter(Mandatory=$true)][string]$Property, 
         $Value, 
         [switch]$Increment
       )

  $pos = arrFindPlayer-WeaponTable -Name $Name -Round $Round -Weapon $Weapon -Class $Class
  if ($pos -lt 0) {
    $obj = [pscustomobject]@{ Name=$Name
                              PlayerClass=$PlayerClass
                              Team=''
                              Round=[int]$Round
                              Weapon=$Weapon
                              Class=[int]$Class
                              Kills=0
                              Death=0
                              Dmg=0
                              DmgTaken=0
                              AttackCount=0
                              DmgCount=0 }

    $script:arrWeaponTable += $obj
    $pos = $script:arrWeaponTable.Length - 1 
  }
  
  if ($Increment -and !$Value) { $Value = [int]1 }
  if ($Increment) { $script:arrWeaponTable[$pos].$Property += [int]$Value }
  else            { $script:arrWeaponTable[$pos].$Property  = $Value }
}


function arrPlayerTable-UpdatePlayer {
  param( [Parameter(Mandatory=$true)][string]$Name,
         [Parameter(Mandatory=$true)]        $Round,
         [Parameter(Mandatory=$true)][string]$Property, 
         $Value, 
         [switch]$Increment
       )

  $pos = arrFindPlayer -Table ([ref]$arrPlayerTable) -Player $Name -Round $Round
  if ($pos -lt 0) {
    $obj = $obj = [pscustomobject]@{ Name=$Name
      Team=''
      Round=[int]$Round
      Kills=0
      Death=0
      TKill=0
      Dmg=0
      DmgTaken=0
      DmgTeam=0
      FlagCap=0
      FlagDrop=0
      FlagTake=0
      FlagThrow=0
      FlagTime=0
      FlagStop=0
    }

    $script:arrPlayerTable += $obj
    $pos = $script:arrPlayerTable.Length - 1 
  }
  
  if ($Increment -and !$Value) { $Value = [int]1 }
  if ($Increment) { $script:arrPlayerTable[$pos].$Property += $Value }
  else            { $script:arrPlayerTable[$pos].$Property  = $Value }
}
#end Summary table functions

function GenerateVersusHtmlInnerTable {
  param([ref]$VersusTable,$Player,$Round)

  switch ($Round) {
    '1'     { $refTeam = [ref]$arrTeamRnd1 }
    '2'     { $refTeam = [ref]$arrTeamRnd2 }
    default { $refTeam = [ref]$arrTeam    }
  }

  $tbl = ''
  $count2 = 0
  foreach ($o in $playerList) {
    $key = "$($player)_$($o)"
    $kills = $VersusTable.Value.$key
    if ($kills -eq '' -or $kills -lt 1) { $kills = 0 }

    $tbl += "<td bgcolor=`"$(actionColorCode $refTeam.Value $player $o)`">$($kills)</td>"

    $subtotal[$count2] = $kills + $subtotal[$count2]
    $count2 +=1
  }

  return $tbl
}

function GenerateFragHtmlTable {
  param([string]$Round)

  switch ($Round) {
    '1'     { $refTeam = [ref]$arrTeamRnd1; $refVersus = [ref]$arrFragVersusRnd1 }
    '2'     { $refTeam = [ref]$arrTeamRnd2; $refVersus = [ref]$arrFragVersusRnd2 }
    default { $refTeam = [ref]$arrTeam;     $refVersus = [ref]$arrFragVersus     }
  }
  
  $count = 1
  $tableHeader = "<table style=""width:600px;display:inline-table"">$($tableStyle2)<tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Kills</th><th $($columStyle)>Dth</th><th $($columStyle)>TK</h>"
  $table = ''
  $subtotal = @($playerList | foreach { 0 } )

  foreach ($p in $playerList) {
    $tableHeader += "<th $($columStyle)>$($count)</th>"
    $team = $refTeam.Value.$p
    #$team  = ($arrPlayerTable | Where { $_.Name -eq $p -and (!$Round -or $_.Round -eq $Round) } `
    #                          | %{ $_.Team} | Sort-Object -Unique) -join '&'
    $kills = ($arrPlayerTable | Where { $_.Name -EQ $p -and (!$Round -or $_.Round -eq $Round)} | Measure-Object Kills -Sum).Sum
    $death = ($arrPlayerTable | Where { $_.Name -EQ $p -and (!$Round -or $_.Round -eq $Round)} | Measure-Object Death -Sum).Sum
    $tkill = ($arrPlayerTable | Where { $_.Name -EQ $p -and (!$Round -or $_.Round -eq $Round)} | Measure-Object TKill -Sum).Sum
    #$table +=  "<tr bgcolor=`"$(teamColorCode (Get-Variable -Name "arrTeam$suffix").Value.$p)`"><td>$($count)</td><td>$($p)</td><td>$((Get-Variable -Name "arrTeam$suffix").Value.$p)</td><td>$($kills)</td><td>$($death)</td><td>$($tkill)</td>"
    $table +=  "<tr bgcolor=`"$(teamColorCode $team)`"><td>$($count)</td><td>$($p)</td><td>$($team)</td><td>$($kills)</td><td>$($death)</td><td>$($tkill)</td>"

    $table += GenerateVersusHtmlInnerTable -VersusTable $refVersus -Player $p -Round $Round

    $table += "<td>$(getPlayerClasses -Round $Round -Player $p)</td>"
    $table += "</tr>`n"
    
    $count += 1 
  }

  $tableHeader += "<th>Classes</th></tr>`n"
  $tableHeader += "</tr>`n"

  $table += '<tr><td colspan=6 align=right padding=2px><b>Total:</b></td>'
  foreach ($st in $subtotal) { $table += "<td>$($st)</td>" }

  $ret = $tableHeader      
  $ret += $table            
  $ret += "</table>`n"

  return $ret
}


function GenerateDmgHtmlTable {
  param([string]$Round)

  switch ($Round) {
    '1'     { $refTeam = [ref]$arrTeamRnd1; $refVersus = [ref]$arrDmgVersusRnd1 }
    '2'     { $refTeam = [ref]$arrTeamRnd2; $refVersus = [ref]$arrDmgVersusRnd2 }
    default { $refTeam = [ref]$arrTeam;     $refVersus = [ref]$arrDmgVersus     }
  }

  $count = 1
  $tableHeader = "<table style=""width:700px;display:inline-table""><tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Dmg</th>"
  $table = ''
  $subtotal = @($playerList | foreach { 0 } )

  foreach ($p in $playerList) {
    $tableHeader += "<th $($columStyle)>$($count)</th>"
    $dmg = ($arrPlayerTable | Where { $_.Name -EQ $p -and (!$Round -or $_.Round -eq $Round)} | Measure-Object Dmg -Sum).Sum
    $table +=  "<tr bgcolor=`"$(teamColorCode $refTeam.Value.$p)`"><td>$($count)</td><td>$($p)</td><td>$($refTeam.Value.$p)</td><td>$($dmg)</td>"

    $table += GenerateVersusHtmlInnerTable -VersusTable $refVersus -Player $p -Round $Round

    $table += "<td>$(getPlayerClasses -Round $Round -Player $p)</td>"
    $table += "</tr>`n"
    
    $count += 1 
  }

  $tableHeader += "<th>Classes</th></tr>`n"
  $tableHeader += "</tr>`n"

  $table += '<tr><td colspan=4 align=right padding=2px><b>Total:</b><i> *minus self-dmg</i></td>'
  foreach ($st in $subtotal) { $table += "<td>$($st)</td>" }

  $ret += $tableHeader   
  $ret += $table         
  $ret += "</table>`n"
  return $ret  
}

#Text Based stats initialized - not reset after each file
$script:arrSummaryAttTable   = @()
$script:arrSummaryDefTable   = @()
$script:arrClassTimeAttTable = @()
$script:arrClassTimeDefTable = @()
$script:arrClassFragAttTable = @()
$script:arrClassFragDefTable = @()
$script:arrResultTable       = @()

$jsonFileCount = 0
foreach ($jsonFile in $inputFile) {
  # Enure JSON files with [ at start and ] (not added in log files)
  $txt = (Get-Content ($jsonFile.FullName  -replace '\[','`[' -replace '\]','`]'))
  if ($txt[0] -notmatch '^\[.*') {
    $txt[0] = "[$($txt[0])"
    $txt[$txt.count - 1] = "$($txt[$txt.count - 1])]"
    $txt | Out-File ($jsonFile.FullName  -replace '\[','`[' -replace '\]','`]')
  }
  Remove-Variable txt

  if (!($jsonFile.Exists)) { Write-Host "ERROR: File not found - $($jsonFile.FullName)"; return }

  # Out file with same-name.html - remove pesky [] braces.
  $outFileStr = ($jsonFile.FullName -replace '\.json$',''  -replace '`?(\[|\])','')
  $json = ((Get-Content -Path ($jsonFile.FullName  -replace '\[','`[' -replace '\]','`]') -Raw) | ConvertFrom-Json)
  $jsonFileCount++
  Write-Host "Input File$(if ($inputFile.Length -gt 1) { " ($jsonFileCount/$($inputFile.Length))" } ): $($jsonFile.Name)"

  #Check for end round time (seconds) - default to 600secs (10mins)
  if ($RoundTime -is [int] -and $RoundTime -gt 0) { $round1EndTime = $RoundTime }
  else { $script:round1EndTime = 600 }

  # Leaving as HashTable, used for HTML display only 
  $script:arrFragVersus     = @{}
  $script:arrFragVersusRnd1 = @{}
  $script:arrFragVersusRnd2 = @{}
  $script:arrDmgVersus     = @{}
  $script:arrDmgVersusRnd1 = @{}
  $script:arrDmgVersusRnd2 = @{}
  
  # Used for some HTML->Awards only
  $script:arrKilledClass     = @{}
  $script:arrKilledClassRnd1 = @{}
  $script:arrKilledClassRnd2 = @{}

  # Using Time tracking via below as values are more accurate than new $arrClassTimeTable - Why?
  $script:arrTimeTrack = @{} #Json parsing helper
  $script:arrTimeClass = @{}
  $script:arrTimeClassRnd1 = @{}
  $script:arrTimeClassRnd2 = @{}

  # Tracking teams via below and then updating arrPlayerTable after JSON parsing -Worth changing?
  $script:arrTeam     = @{}
  $script:arrTeamRnd1 = @{}
  $script:arrTeamRnd2 = @{}
  
  $script:arrResult = @{}
  
  # Leaving as HashTable, used for HTML display only 
  $script:arrFragMin     = @{}
  $script:arrDmgMin      = @{} 
  $script:arrDeathMin    = @{} 
  $script:arrFlagCapMin   = @{}
  $script:arrFlagDropMin  = @{}
  $script:arrFlagTookMin  = @{}  
  $script:arrFlagThrowMin = @{}
  $script:arrFlagStopMin  = @{}

  # Table Arrays - PS Format-Table friendly
  $script:arrAttackDmgTracker = @{} #Json parsing helper (AttackCount + Dmg Count)
  $script:arrWeaponTable      = @()
  $script:arrPlayerTable      = @()
  $script:arrClassTimeTable   = @()

  ###
  # Process the JSON into above arrays (created 'Script' to be readable by all functions)
  # keys: Frags/playername, Versus.player_enemy, Classes/player_class#, Weapons/player_weapon
  ###
  $script:round = 1
  $script:timeBlock = 1
  $prevItem = ''

  ForEach ($item in $json) {
    $type    = $item.type
    $kind    = $item.kind

    #Remove any underscores for _ tokens used in Keys 
    $player  = $item.player -replace '_','.' -replace '\s$','.' -replace '\^','.'  -replace '\$','§'
    $target  = $item.target -replace '_','.' -replace '\s$','.' -replace '\^','.'  -replace '\$','§'
    $p_team  = $item.playerTeam
    $t_team  = $item.targetTeam
    $class   = $item.playerClass
    $classNoSG = $class -replace '10','9'
    $t_class = $item.targetClass
    $dmg     = [math]::Round($item.damage,0)
    #Shorten and fix multiple names on weapons  
    $weap    = (weapSN $item.inflictor)

    #Setup time blocks for per minute scoring
    $time    = $item.time
    if ($time -notin '',$null -and [math]::Ceiling($time/60) -gt $timeBlock) {
      #new time block found, update the time block
      $timeBlock = [math]::Ceiling($time/60)
    }

    ###
    # Fix Stupid stuff missing from logs due to 3rd Party events - e.g. Buildings and Gas
    ###

    #try fix building kills/deaths
    if ($t_class -eq 0 -and $target -in '','build.timer' -and $weap -ne 'worldSpawn') {  
      $potentialEng = $arrTimeTrack.keys -match '.*_lastClass$'
      $potentialEng = $potentialEng | foreach { if ($arrTimeTrack.$_ -eq 9) { ($_ -split '_')[0] } }

      # If only 1 eng found fix it, else forget it
      if ($potentialEng -notin '',$null -and $potentialEng.Count -eq 1 ) {
        $target = ($potentialEng -split '_')[0]
        $t_class  = 10
      } else { continue }
    }          
    elseif ($weap -eq 'sent') { $class = 10 }
    # Do this before Keys are made# dodgey... Try find out who a gas grenade owner is
    elseif ($class -eq '8' -and $weap -eq 'worldspawn') { 
      if ($type -in 'damageDone','kill') {
        $potentialSpies = $arrTimeTrack.keys -match '.*_lastClass$'
        $potentialSpies = $potentialSpies | foreach { if ($arrTimeTrack.$_ -eq 8) { ($_ -split '_')[0] } }
      
        # If only 1 spy found fix it, else forget it
        if ($potentialSpies.Count -eq 1 -and $potentialSpies -notin '',$null) { 
          $player = ($potentialSpies -split '_')[0]
        } else { continue }
      } 
    }

    # add -ff to weap for friendly-fire
    if ($p_team -and $t_team -and $p_team -eq $t_team -and $weap -ne 'laser') { $weap += '-ff' }

    # change weapon to suidcide for self kills
    if ($player -and $player -eq $target) { $weap  = 'suicide' }
    
    $key       = "$($player)_$($target)"
    $keyTime   = "$($timeBlock)_$($player)"
    #$keyTimeT  = "$($timeBlock)_$($target)"
    $keyClassK = "$($player)_$($class)_$($t_class)"
    $keyWeap   = "$($player)_$($class)_$($weap)"
    #$keyWeapT  = "$($target)_$($class)_$($weap)" 
    

    # 19/12/21 New Attack/DmgDone stats in object/array format for PS Tables.
    if ($type -in 'attack','damageDone' -and $player -and $weap -and $class -gt 0 `
        -and ($type -eq 'attack' -or $p_team -ne $t_team -or $player -ne $target)) { 

      switch ($type) {
        'attack'      { if ($arrAttackDmgTracker.$keyWeap -eq -1) {
                          # damageDone registered before attack
                          $arrAttackDmgTracker.Remove($keyWeap)
                        } elseif ($arrAttackDmgTracker.$keyWeap -gt 0) {
                          # attack registered - no dmg done found since
                          $arrAttackDmgTracker.Remove($keyWeap)
                        }
                        arrWeaponTable-UpdatePlayer -Name $player -PlayerClass $class -Round $round -Weapon $weap -Class $class -Property 'AttackCount' -Increment
                      }
        'damageDone'  { <# To avoid multi-hits: No item existing = No DmgCount added #>
                        if ($p_team -ne $t_team) {
                          if (!$arrAttackDmgTracker.$keyWeap) { 
                            #Damage not registered, no attack yet found
                            $arrAttackDmgTracker.$keyWeap = -1
                            arrWeaponTable-UpdatePlayer -Name $player -PlayerClass $class -Round $round -Weapon $weap -Class $class -Property 'DmgCount'   -Increment
                          } elseif (!$arrAttackDmgTracker.$keyWeap -gt 0) {
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
      
      if ($arrTrackTime.flagPlayer -notin $null,'') {
        arrPlayerTable-UpdatePlayer -Name $arrTrackTime.flagPlayer -Round $round -Property 'FlagTime' -Value ($round1EndTime - $arrTimeTrack.flagTook) -Increment
        $arrTrackTime.flagTook   = 0
        $arrTrackTime.flagPlayer = ''
      }

      #Finalise Rnd1 Class times from the tracker.
      foreach ($p in $arrTeam.Keys) { 
        arrClassTable-UpdatePlayer -Table ([ref]$arrClassTimeTable) -Player $p -Class $arrTimeTrack."$($p)_lastClass" -Round $round `
                                                                -Value ($round1EndTime - $arrTimeTrack."$($p)_lastChange") -Increment
        $arrTimeClass."$($p)_$($arrTimeTrack."$($p)_lastClass")"     += $round1EndTime - $arrTimeTrack."$($p)_lastChange"
        $arrTimeClassRnd1."$($p)_$($arrTimeTrack."$($p)_lastClass")" += $round1EndTime - $arrTimeTrack."$($p)_lastChange"
        $arrTimeTrack."$($p)_lastClass"  = ''
        $arrTimeTrack."$($p)_lastChange" = $round1EndTime
      }
    } else {
      if ($type -in 'playerStart','changeClass' -or $weap -like 'worldspawn*') { continue }
      # Class tracking - Player and Target
      if ($time -in 250..275 -and $player -eq 'world') { $weap }
      foreach ($pc in @(@($player,$classNoSG),@($target,$t_class -replace '10','9'))) {
        if ($pc[0] -match '^(\s)*$') { continue }	  
        #This is making Rnd1 class bleed to Rnd2...
        #if ($type -eq 'changeClass') {  $lastClass = $class; $class = $item.nextClass; $class; $lastclass }
        $lastClass  = $arrTimeTrack."$($pc[0])_lastClass"
        if ($lastClass -match '^(\s)*$') { $lastClass = $pc[1] }
    
        $lastChange = $arrTimeTrack."$($pc[0])_lastChange"	 
        if ($lastChange -in '',$null) { 
          if ((($round1EndTime * $round) - $round1EndTime + $time) -lt 30) { 
            $lastChange = ($round1EndTime * $round) - $round1EndTime
          } else { $lastChange = $time }
        }
      
        $lastChangeDiff = $time - $lastChange
      
        if ($pc[1] -in $ClassAllowed) { 
          #Record time 
          #if ($arrTimeTrack."$($pc[0])_lastClass" -gt 0)  { 
            arrClassTable-UpdatePlayer -Table ([ref]$arrClassTimeTable) -Player $pc[0] -Class $lastClass -Round $round -Value $lastChangeDiff -Increment 
         # }
          $arrTimeClass."$($pc[0])_$($lastClass)" += $lastChangeDiff
          if ($round -eq 1) { $arrTimeClassRnd1."$($pc[0])_$($lastClass)" += $lastChangeDiff } 
          else { $arrTimeClassRnd2."$($pc[0])_$($lastClass)" += $lastChangeDiff }
    
          #Update tracker after stuff is tallied
          $arrTimeTrack."$($pc[0])_lastClass"  = $pc[1]
          $arrTimeTrack."$($pc[0])_lastChange" = $time
        }
      }
    }
    
    # Switch #1 - Tracking Goal/TeamScores prior to world/error checks skip loop.
    #           - Tracking all-death prior to this also (death due to fall/other damage).
    switch ($type) {
      #'gameStart' { $map = $item.map }
      
      'goal' {
        # arrTimeTrack.flag* updated under the fumble event
        arrPlayerTable-UpdatePlayer -Name $arrTimeTrack.flagPlayer -Round $round -Property 'FlagTime' -Value ($time - $arrTimeTrack.flagTook) -Increment
        arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'FlagCap' -Increment
        $arrFlagCapMin.$keyTime += 1
      }

      'teamScores' {
        # For the final team score message
        $arrResult.team1Score  = $item.team1Score
        $arrResult.team2Score  = $item.team2Score
        $arrResult.winningTeam = $item.winningTeam
        $arrResult.time        = $time

        # Note - Add +10 points when Team1 wins to avoid a Draw being compared to a Win.
        switch ($arrResult.winningTeam) {
          '0'     { $arrResult.winRating = 0;                                                          $arrResult.winRatingDesc = 'Nobody wins' }
          '1'     { $arrResult.winRating = 1 - ($arrResult.team2Score / ($arrResult.team1Score + 10)); $arrResult.winRatingDesc = "Wins by $($item.team1Score - $item.team2Score) points" }
          default { $arrResult.winRating = (($round1EndTime * 2) - $arrResult.time ) / $round1EndTime; $arrResult.winRatingDesc = "$("{0:m\:ss}" -f ([timespan]::fromseconds(($round1EndTime * 2) - $arrResult.time))) mins left" }
        }
      }

      'death' {
        $arrDeathMin.$keyTime    += 1
        
        #record sg deahts in class table only i.e.e Class 10/SG.
        if ($player  -ne '' -and $class -ne 0) {
          arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'Death' -Increment
          if ($item.attacker -in 'world','') {
            arrWeaponTable-UpdatePlayer -Name $player -PlayerClass $class -Round $round -Weapon 'world' -Class $class -Property 'Death' -Increment
          }
        }
        continue
      } 
    }
    
    #Skip environment/world events for kills/dmg stats (or after this), let laser and team scores pass thru
    if ((($player -eq '') -Or ($p_team -eq '0') -or ($t_team -eq '0') -or ($t_class -eq '0') -or ($weap -eq 'worldSpawn')) -and ($type -ne 'teamScores' -and $weap -ne 'laser')) { continue } 
    

    #team tracking
    if ($p_team -notin $null,'' -and $p_team -gt 0 -and $class -gt 0 -and $type -notin 'damageTaken' -and $weap -notlike 'worldspawn*') {
      if ($player -eq 'world') { $weap; $item }
      if ($arrTeam.$player -in '',$null) {
        #Initialise team info when null
        $arrTeam.$player = "$p_team"
      } elseif ($p_team -notin ($arrTeam.$player -split '&')) {
        #Else if team not in list add it
        $arrTeam.$player = "$($arrTeam.$player)&$($p_team)"
      }

      #Do the same for Rnd1 / Rnd2
      switch ($round) {
        '1'     {
          if ($arrTeamRnd1.$player -in '',$null) {
            #Initialise team info when null
            $arrTeamRnd1.$player = "$p_team"
          } elseif ($p_team -notin ($arrTeamRnd1.$player -split '&')) {
            #Else if team not in list add it
            $arrTeamRnd1.$player = "$($arrTeamRnd1.$player)&$($p_team)"
          }
        }
        default {
          if ($arrTeamRnd2.$player -in '',$null) {
            #Initialise team info when null
            $arrTeamRnd2.$player = "$p_team"
          } elseif ($p_team -notin ($arrTeamRnd2.$player -split '&')) {
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
        if ($player -ne $target -and $player -notin $null,'') {
          #make sure player did not killed himself and has a name
          if ($p_team -eq $t_team) {
            #team kill recorded, not a normal kill
            arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'TKill' -Increment
          } else {
            #Record the normal kill
            arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'Kills' -Increment
            arrWeaponTable-UpdatePlayer -Name $player -PlayerClass $class -Round $round -Weapon $weap -Class $class -Property 'Kills' -Increment

            $arrKilledClass.$keyClassK += 1
            $arrFragMin.$keyTime    += 1

            switch ($round) {
              '1'     { $arrKilledClassRnd1.$keyClassK += 1 }
              default { $arrKilledClassRnd2.$keyClassK += 1 }
            }
          }
        }
      
        #track all weap deaths on targets AND all versus kills (to see self/team kills in table). Exclude sentry death for player totals.
        #dont track SG deaths except in the class and weapons stats. 
        if ($t_class -ne '10') {
          if ($player -notin $null,'') {
            $arrFragVersus.$key       += 1
            switch ($round) {
              '1'     { $arrFragVersusRnd1.$key += 1 }
              default { $arrFragVersusRnd2.$key += 1 }
            }


            arrWeaponTable-UpdatePlayer -Name $target -PlayerClass $t_class -Round $round -Class $class -Weapon $weap -Property 'Death' -Increment
          }
        }
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

            $arrDmgMin.$keyTime    += $dmg
          } elseif ($player) {
            #team dmg
            arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'DmgTeam' -Value $dmg -Increment
          }
        }
        #record all damage including self/team in versus table
        $arrDmgVersus.$key += $dmg
        switch ($round) {
          '1'     { $arrDmgVersusRnd1.$key += $dmg }
          default { $arrDmgVersusRnd2.$key += $dmg }
        }
      }

      'fumble' {
        arrPlayerTable-UpdatePlayer -Name $arrTimeTrack.flagPlayer -Round $round -Property 'FlagTime' -Value ($time - $arrTimeTrack.flagTook) -Increment
        $arrTimeTrack.'flagPlayer' = ''
        $arrTimeTrack.'flagTook'   = 0
        
        arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'FlagDrop' -Increment
        $arrFlagDropMin.$keyTime += 1

        # work out if death or throw
        if ($prevItem.attacker -and $item.team -ne $prevItem.attackerTeam -and $prevItem.type -eq 'death' -and $prevItem.player -eq $player -and 
            $prevItem.time -eq $time -and $prevItem.kind -ne 'self') {
          arrPlayerTable-UpdatePlayer -Name $prevItem.attacker -Round $round -Property 'FlagStop' -Increment
          $arrFlagStopMin."$($timeBlock)_$($prevItem.attacker)" += 1
        } elseif ($prevItem.kind -ne 'self') { 
          arrPlayerTable-UpdatePlayer -Name $player -Round $round -Property 'FlagThrow' -Increment
          $arrFlagThrowMin.$keyTime += 1 
        }
      }

      'pickup' {
        $arrTimeTrack.flagTook   = $time
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
  $arrTimeTrack.flagTook    = 0

  foreach ($p in $arrTeam.Keys) {
    $lastClass = $arrTimeTrack."$($p)_lastClass"
    $key       = "$($p)_$($lastClass)"
     
    arrClassTable-UpdatePlayer -Table ([ref]$arrClassTimeTable) -Player $p -Class $lastClass -Round $round -Value ($time - $arrTimeTrack."$($p)_lastChange")
    $arrTimeClass."$($p)_$($lastClass)"     += $time - $arrTimeTrack."$($p)_lastChange"
    if ($arrTeamRnd2.$p -notin '',$null) {
      $arrTimeClassRnd2.$key += $time - $arrTimeTrack."$($p)_lastChange"
    } else {
      $arrTimeClassRnd2.Remove($key)
    }
  }

  #remove any Class Times where timed played less that 10secs
  function timeClassCleanup {
    $out = @{}
    foreach ($k in $args[0].keys) { if ($args[0].$k -gt 10) { $out.$k = $args[0].$k } }
    return $out
  }

  function arrClassTimeTable-Cleanup {
    param([ref]$Table)

    foreach ($p in $Table.Value) {
      $totalTime = ($p | Measure $ClassAllowedStr -Sum).Sum
      foreach ($c in $ClassAllowedStr) {
        if ($p.$c -lt 10) {
          $p.$c = 0
        } elseif ($p.$c -gt $round1Endtime) {
          $p.$c = $round1EndTime
        } elseif ($p.$c -in ($round1EndTime-15)..$round1EndTime -and $totalTime -lt $round1EndTime) {
          $p.$c = $round1EndTime
        }
      }
    }
  }

  arrClassTimeTable-Cleanup ([ref]$arrClassTimeTable)
  #cleanup class times less that 10 seconds
  $arrTimeClass     = timeClassCleanup $arrTimeClass
  $arrTimeClassRnd1 = timeClassCleanup $arrTimeClassRnd1
  $arrTimeClassRnd2 = timeClassCleanup $arrTimeClassRnd2

  ######
  #Create Ordered Player List 
  #####
  $playerList  = ($arrTeam.GetEnumerator()| Sort-Object -Property Value,Name).Key

  #######
  # Add Team Info to tables and sort by Round/Team/Name
  ######

  foreach ($i in $arrWeaponTable) {
    switch ($i.Round) { 
      1 { $i.Team = $arrTeamRnd1.($i.Name)   }
      2 { $i.Team = $arrTeamRnd2.($i.Name)   }
      default { $i.Team = $arrTeam.($i.Name) }
    }
  }
  $arrWeaponTable = $arrWeaponTable | Sort Round,Team,Name

  foreach ($i in $arrPlayerTable) {
    switch ($i.Round) { 
      1 { $i.Team = $arrTeamRnd1.($i.Name)   }
      2 { $i.Team = $arrTeamRnd2.($i.Name)   }
      default { $i.Team = $arrTeam.($i.Name) }
    }
  }
  $arrPlayerTable = $arrPlayerTable | Sort Round,Team,Name                                   
  
  if (!$TextOnly) {
    ###
    # Calculate awards
    ##

    #create variables here, min/max values to be generated for awardAtt* + awardDef* (exclude *versus)
    Remove-Variable -Name award*
    $script:awardAttKills   = @{}
    $script:awardAttDeath   = @{}
    $script:awardAttDmg     = @{}
    $script:awardAttDmgTaken = @{}
    $script:awardAttDmgTeam = @{}
    $script:awardAttKD      = @{}
    $script:awardAttTKill   = @{}
    $script:awardAttDmgPerKill  = @{}
    $script:awardAttKillsVersus = @{}
    $script:awardAttFlagCap  = @{}
    $script:awardAttFlagTook = @{}
    $script:awardAttFlagTime = @{}

    $script:awardDefKills    = @{}
    $script:awardDefDeath    = @{}
    $script:awardDefDmg      = @{}
    $script:awardDefDmgTaken = @{}
    $script:awardDefDmgTeam  = @{}
    $script:awardDefKD       = @{}
    $script:awardDefTKill    = @{}
    $script:awardDefDmgPerKill  = @{}
    $script:awardDefKillsVersus = @{}

    function awardScaler {
      if ($arrResult.WinningTeam -eq 2) {
        return [math]::Floor($args[0] * (1 + $arrResult.WinRating))
      } else { return $args[0] }
    }

    function GetArrTimeTotal {
      #p1 = round, p2 = player
      switch ($args[0]) {
        '2'     { $arrTime = $arrTimeClassRnd2 }
        '1'     { $arrTime = $arrTimeClassRnd1 }
        default { $arrTime = $arrTimeClass }
      }
      (($arrTime.keys -match "^$($args[1] -replace $regExReplaceFix)_[1-9]$" | foreach { $arrTime.$_ } ) | Measure-Object -Sum).Sum
    }

    #Attack - Rnd1=T1 and Rnd2=T2 - Get Player list and get required Data sets
    # Teams sorted in order, i.e. 1&2 = Att 2x, 2&1 = Def 2x.
    $script:playerListAttRnd1 = ($arrTeamRnd1.Keys | foreach { if ($arrTeamRnd1.$_ -match '^(1|1&2)$' -and (GetArrTimeTotal 1 $_) -gt  $round1EndTime  - 60) { $_ } })
    $script:playerListAttRnd2 = ($arrTeamRnd2.Keys | foreach { if ($arrTeamRnd2.$_ -match '^(2|1&2)$' -and (GetArrTimeTotal 2 $_) -gt  ($arrResult.time - $round1EndTime - 60)) { $_ } })

    ## Generate Attack/Def Tables, e.g. for att Rnd1 = Team1 attack + Rnd2 = Team2 attack
    $count = 1

    foreach ($array in @($playerListAttRnd1, $playerListAttRnd2)) {
      foreach ($p in $array) {
        #disqualify a player if they were on multiple teams
        if ($arrTeam.$p -notmatch '^(1|2)$') { continue }

        if ($arrResult.WinningTeam -eq 2) {
          $scaler = 1 / $arrResult.winRating
        } else { $scaler = 1 }
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
        } else {
          $awardAttKills.Add($p, (awardScaler $arrPlayerTable[$pos].Kills ))
          $awardAttDeath.Add($p, (awardScaler $arrPlayerTable[$pos].Death))
          $awardAttDmg.Add(  $p, (awardScaler $arrPlayerTable[$pos].Dmg))
          $awardAttDmgTaken.Add(  $p, (awardScaler $arrPlayerTable[$pos].DmgTaken))
          $awardAttDmgTeam.Add(  $p, (awardScaler $arrPlayerTable[$pos].DmgTeam))
          $awardAttTkill.Add($p, (awardScaler $arrPlayerTable[$pos].TKill))

          $awardAttKD.Add(   $p, (awardScaler ($arrPlayerTable[$pos].Kills - $arrPlayerTable[$pos].Death)) )
        }
        if ($arrPlayerTable[$pos].Kills -notin $null,'','0') { $awardAttDmgPerKill.Add($p, [math]::Round($arrPlayerTable[$pos].Dmg / $arrPlayerTable[$pos].Kills) ) }
      }
      $count += 1
    }


    #defence - Rnd2=T2 and Rnd2=T1 - Get Player list and get required Data sets
    ## Generate Attack/Def Tables, e.g. for att Rnd1 = Team2 def + Rnd2 = Team1 def
    $script:playerListDefRnd1 = ($arrTeamRnd1.Keys | foreach { if ($arrTeamRnd1.$_ -match '^(2|2&1)$' -and (GetArrTimeTotal 1 $_) -gt $round1EndTime  - 60) { $_ } })
    $script:playerListDefRnd2 = ($arrTeamRnd2.Keys | foreach { if ($arrTeamRnd2.$_ -match '^(1|2&1)$' -and (GetArrTimeTotal 2 $_) -gt $arrResult.time - $round1EndTime - 60) { $_ } })

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
        } else {
          $awardDefKills.Add($p, (awardScaler $arrPlayerTable[$pos].Kills ))
          $awardDefDeath.Add($p, (awardScaler $arrPlayerTable[$pos].Death))
          $awardDefDmg.Add(  $p, (awardScaler $arrPlayerTable[$pos].Dmg))
          $awardDefDmgTaken.Add(  $p, (awardScaler $arrPlayerTable[$pos].DmgTaken))
          $awardDefDmgTeam.Add(  $p, (awardScaler $arrPlayerTable[$pos].DmgTeam))
          $awardDefTkill.Add($p, (awardScaler $arrPlayerTable[$pos].TKill))

          $awardDefKD.Add(   $p, (awardScaler ($arrPlayerTable[$pos].Kills - $arrPlayerTable[$pos].Death)) )
        }
        if ($arrPlayerTable[$pos].Kills -notin $null,'','0') { $awardDefDmgPerKill.Add($p, [math]::Round($arrPlayerTable[$pos].Dmg / $arrPlayerTable[$pos].Kills) ) }

      }
      $count += 1
    }

    #function to tally up multiple sources
    function awardTallyTables {
      $htOut = @{}
      $keyList = $args[0].Keys
      $keyList += ($args[1].Keys -notmatch $args[0].Keys)

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
    foreach ($p in $awardDefTKill.Keys)   { $awardDefMagoo.$p += $awardDefTKill.$p / $tkAvg }
    foreach ($p in $awardDefDmgTeam.Keys) { $awardDefMagoo.$p = [Math]::Round(($awardDefMagoo.$p + ($awardDefDmgTeam.$p / $tdAvg))/2,2) }
    Remove-Variable tkAvg,tdAvg


    # Repeatable function for Killed Class Lookup
    function awardFromKilledClass {
      # p1 = att/def p2 = regex
      $htOut = @{}
      switch ($args[0]) {
        'Att'   { $plRnd1 = $playerListAttRnd1; $plRnd2 = $playerListAttRnd2 }
        'Def'   { $plRnd1 = $playerListDefRnd1; $plRnd2 = $playerListDefRnd2 }
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

    $awardAttKilledDemo  = (awardFromKilledClass 'Att' '.*_4$')
    $awardDefKilledSold  = (awardFromKilledClass 'Def' '.*_3$')
    $awardDefKilledLight = (awardFromKilledClass 'Def' '.*_(1|5|8|9)$')
    $awardAttKilledHeavy = (awardFromKilledClass 'Att' '.*_(3|4|6|7)$')
    $awardDefKilledHeavy = (awardFromKilledClass 'Def' '.*_(3|4|6|7)$')
    $awardAttLightKills  = (awardFromKilledClass 'Att' '.*_(1|5|8|9)_.*$')
    $awardAttKilledSG    = (awardFromKilledClass 'Att' '.*_10$')


    #####
    #Get MAX and MIN for each of the new tables starting with awardAtt/awardDef
    # CREATE ALL $awardDef and $awardAtt tables BEFORE THIS POINT!!
    ######
    #attack
    ####
    foreach ($v in (Get-Variable 'award*' -Exclude '*_*','awardsHtml')) {
      Set-Variable -Name  "$($v.Name)_Max" -Value (($v.Value).Values | Measure-Object -Maximum).Maximum
      Set-Variable -Name  "$($v.Name)_Min" -Value (($v.Value).Values | Measure-Object -Minimum).Minimum
    }

    function addTokenToString {
      if ($args[0] -in $null,'') { $args[1] }
      elseif ($args[1] -notin ($args[0] -split ', ')) { "$($args[0]), $($args[1])" }
      else { $args[0] }
    }

    # Get the Names of each Max/Min award table
    foreach ($p in $PlayerList) {
      foreach ($vlist in @((Get-Variable 'award*_Max' -Exclude '*Versus*'),(Get-Variable 'award*_Min' -Exclude '*Versus*'))) {    
        foreach ($v in $vlist) {
          $arrayName = ($v.Name -Split '_')[0]
          $name  = "$($v.Name)Name"
          $value = $v.Value[1]
          if (Test-Path "variable:$($name)") { $leader = Get-Variable $name -ValueOnly }
          else { $leader = '' }
          
          if ((Get-Variable $arrayName).Value.$p -eq $v.Value) { Set-Variable -Name $name -Value (addTokenToString $leader $p) }
        }
      }
    }

    # Most Frag  on a player 
    $attMax = ''
    $awardAttPlayerFrag_MaxName   = ''
    $awardAttPlayerFrag_Victim = ''
    $awardAttPlayerFrag_Value  = ''
    $defMax = ''
    $awardDefPlayerFrag_MaxName   = ''
    $awardDefPlayerFrag_Victim = ''
    $awardDefPlayerFrag_Value  = ''

    $count = 1
    ### Frag versus statistics
    foreach ($array in @($arrFragVersusRnd1,$arrFragVersusRnd2)) {
      foreach ($item in $array.keys) {
        #player/target
        $pt = $item -split '_'
        switch ($count) {
          1       { $pl = $playerListAttRnd1; $value = $array.$item }
          default { $pl = $playerListAttRnd2; $value = awardScaler $array.$item }
        }

        if ($pt[0] -ne $pt[1] -and $pt[0] -in $pl) {  
          if ($max -eq '' -or  $value -ge $attMax) {
            if ($value -eq $attMax) {
              $awardAttPlayerFrag_MaxName = (addTokenToString $awardAttPlayerFrag_MaxName $pt[0])
              $awardAttPlayerFrag_Victim  = (addTokenToString $awardAttPlayerFrag_Victim  $pt[1])
            } else {
              $awardAttPlayerFrag_MaxName = $pt[0]
              $awardAttPlayerFrag_Victim = $pt[1]
            }
            $awardAttPlayerFrag_Value  = $value
            $attMax = $value
          }
        }

        switch ($count) {
          1       { $pl = $playerListDefRnd1 }
          default { $pl = $playerListDefRnd2 }
        }

        if ($pt[0] -ne $pt[1] -and $pt[0] -in $pl) {  
          if ($max -eq '' -or  $value -ge $defMax) {
            if ($value -eq $defMax) {
              $awardDefPlayerFrag_MaxName = (addTokenToString $awardDefPlayerFrag_MaxName $pt[0])
              $awardDefPlayerFrag_Victim  = (addTokenToString $awardDefPlayerFrag_Victim  $pt[1])
            } else {
              $awardDefPlayerFrag_MaxName = $pt[0]
              $awardDefPlayerFrag_Victim  = $pt[1]
            }
            $awardDefPlayerFrag_Value  = $value
            $defMax = $value
          } 
        }
      }
      $count += 1
    }

    # Most Dmg  on a player 
    $attMax = ''
    $awardAttPlayerDmg_MaxName   = ''
    $awardAttPlayerDmg_Victim = ''
    $awardAttPlayerDmg_Value  = ''
    $defMax = ''
    $awardDefPlayerDmg_MaxName   = ''
    $awardDefPlayerDmg_Victim = ''
    $awardDefPlayerDmg_Value  = ''

    $count = 1
    ### Damage versus statistics
    foreach ($array in @($arrDmgVersusRnd1,$arrDmgVersusRnd2)) {
      foreach ($item in $array.keys) {
        #player/target
        $pt = $item -split '_'
        switch ($count) {
          1       { $pl = $playerListAttRnd1; $value = $array.$item }
          default { $pl = $playerListAttRnd2; $value = awardScaler $array.$item }
        }

        if ($pt[0] -ne $pt[1] -and $pt[0] -in $pl) {  
          if ($max -eq '' -or  $value -ge $attMax) {
            if ($value -eq $attMax) {
              $awardAttPlayerDmg_MaxName = (addTokenToString $awardAttPlayerDmg_MaxName   $pt[0])
              $awardAttPlayerDmg_Victim  = (addTokenToString $awardAttPlayerDmg_Victim $pt[1])
            } else {
              $awardAttPlayerDmg_MaxName = $pt[0]
              $awardAttPlayerDmg_Victim = $pt[1]
            }
            $awardAttPlayerDmg_Value  = $value
            $attMax = $value
          }
        }

        switch ($count) {
          1       { $pl = $playerListDefRnd1 }
          default { $pl = $playerListDefRnd2 }
        }

        if ($pt[0] -ne $pt[1] -and $pt[0] -in $pl) {  
          if ($max -eq '' -or  $value -ge $defMax) {
            if ($value -eq $defMax) {
              $awardDefPlayerDmg_MaxName = (addTokenToString $awardDefPlayerDmg_MaxName $pt[0])
              $awardDefPlayerDmg_Victim  = (addTokenToString $awardDefPlayerDmg_Victim  $pt[1])
            } else {
              $awardDefPlayerDmg_MaxName = $pt[0]
              $awardDefPlayerDmg_Victim  = $pt[1]
            }
            $awardDefPlayerDmg_Value  = $value
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
      
      $players = $args[1] -split', '
      switch ($args[0]) {
        'Att'     { $pl = $playerListAttRnd2 }
        default   { $pl = $playerListDefRnd2 }
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
    <table>
    <tr><th colspan=3><h3>The Attackers</h3></th></tr>
    <tr><th>Award</h>            <th>Winner</th>                          <th>Description</th></tr>
    <tr><td>Commando</td>        <td align=center width=150px>$(awardScaleCaveat 'Att' $awardAttKills_MaxName)</td>      <td>Most kills ($($awardAttKills_Max))</td></tr>
    <tr><td>Rambo</td>           <td align=center width=150px>$(awardScaleCaveat 'Att' $awardAttDmg_MaxName)</td>        <td>Most damage ($($awardAttDmg_Max))</td></tr>
    <tr><td>Golden Hands</td>    <td align=center width=150px>$($awardAttFlagCap_MaxName)</td>    <td>Most caps ($($awardAttFlagCap_Max))</td></tr>
    <tr><td>Running Man</td>     <td align=center width=150px>$($awardAttFlagTime_MaxName)</td>   <td>Most time with flag ($($awardAttFlagTime_Max)s)</td></tr>
    <tr><td>Brawler</td>         <td align=center width=150px>$(awardScaleCaveat 'Att' $awardAttKilledHeavy_MaxName)</td><td>Most kills on heavy classes ($($awardAttKilledHeavy_Max))</td></tr>
    <tr><td>David</td>           <td align=center width=150px>$(awardScaleCaveat 'Att' $awardAttLightKills_MaxName)</td> <td>Most kills as a light class ($($awardAttLightKills_Max))</td></tr>
    <tr><td>Spec Ops</td>        <td align=center width=150px>$(awardScaleCaveat 'Att' $awardAttKilledDemo_MaxName)</td> <td>Most kills on demo ($($awardAttKilledDemo_Max))</td></tr>
    <tr><td>Sapper</td>          <td align=center width=150px>$(awardScaleCaveat 'Att' $awardAttKilledSG_MaxName)</td>   <td>Most kills on a SG ($($awardAttKilledSG_Max))</td></tr>
    <tr><td>Lemming</td>         <td align=center width=150px>$(awardScaleCaveat 'Att' $awardAttDeath_MaxName)</td>      <td>Most Deaths ($($awardAttDeath_Max))</td></tr>
    <tr><td>Battering Ram</td>   <td align=center width=150px>$(awardScaleCaveat 'Att' $awardAttKD_MinName)</td>         <td>Lowest Kill-Death rank ($($awardAttKD_Min))</td></tr>
    <tr><td>Buck shot</td>       <td align=center width=150px>$($awardAttDmgPerKill_MaxName)</td>                        <td>Most Damage per kill ($($awardAttDmgPerKill_Max))</td></tr>
    <tr><td>Predator</td>        <td align=center width=150px>$(awardScaleCaveat 'Att' $awardAttPlayerFrag_MaxName)</td> <td>Most kills on a defender ($($awardAttPlayerFrag_Value) on $($awardAttPlayerFrag_Victim))</td></tr>
    <tr><td>Hulk Smash</td>      <td align=center width=150px>$(awardScaleCaveat 'Att' $awardAttPlayerDmg_MaxName)</td>  <td>Most damage on a defender ($($awardAttPlayerDmg_Value) on $($awardAttPlayerDmg_Victim))</td></tr>
    "

    if ($arrResult.winningTeam -eq 2) {
    $awardsHtml += "<tr><td colspan=3 align=right><i>*Team2 scaled: Only $('{0:p0}' -f [math]::Round((1 - $arrResult.winRating),2)) of Rnd2 played</i></td></tr>`n"
    }

    $awardsHtml += "</table></div>
    <div class=column style=`"width:580;display:inline-table`"> 
    <table>
    <tr><th colspan=3><h3>The Defenders<h3></th></tr>
    <tr><th>Award</h>                <th>Winner</th>                                                  <th>Description</th></tr>
    <tr><td>Slaughterhouse</td>      <td align=center width=150px>$(awardScaleCaveat 'Def' $awardDefKills_MaxName)</td>      <td>Most kills ($($awardDefKills_Max))</td></tr>
    <tr><td>Terminator</td>          <td align=center width=150px>$(awardScaleCaveat 'Def' $awardDefKD_MaxName)</td>         <td>Kills-death rank ($($awardDefKD_Max))</td></tr>
    <tr><td>Juggernaut</td>          <td align=center width=150px>$(awardScaleCaveat 'Def' $awardDefDmg_MaxName)</td>        <td>Most damage ($($awardDefDmg_Max))</td></tr>
    <tr><td>Dark Knight</td>         <td align=center width=150px>$(awardScaleCaveat 'Def' $awardDefKilledSold_MaxName)</td> <td>Most kills on Soldier ($($awardDefKilledSold_Max))</td></tr>
    <tr><td>Tank</td>                <td align=center width=150px>$(awardScaleCaveat 'Def' $awardDefKilledHeavy_MaxName)</td><td>Most kills on a heavy class ($($awardDefKilledHeavy_Max))</td></tr>
    <tr><td>Goliath</td>             <td align=center width=150px>$(awardScaleCaveat 'Def' $awardDefKilledLight_MaxName)</td><td>Most kills on a light class ($($awardDefKilledLight_Max))</td></tr>
    <tr><td>Sly Fox</td>             <td align=center width=150px>$(awardScaleCaveat 'Def' $awardDefDeath_MinName)</td>      <td>Lowest Deaths ($($awardDefDeath_Min))</td></tr>
    <tr><td>Team Player</td>         <td align=center width=150px>$($awardDefDmgPerKill_MaxName)</td>                        <td>Most damage per kill ($($awardDefDmgPerKill_Max))</td></tr>
    <tr><td>Nemesis</td>             <td align=center width=150px>$(awardScaleCaveat 'Def' $awardDefPlayerFrag_MaxName)</td> <td>Most Kills on an attacker ($($awardDefPlayerFrag_Value) on $($awardDefPlayerFrag_Victim))</td></tr>
    <tr><td>No quarter</td>          <td align=center width=150px>$($awardDefDmgPerKill_MinName)</td>                        <td>Lowest damage per kill ($($awardDefDmgPerKill_Min))</td></tr>
    <tr><td>Attention whore</td>     <td align=center width=150px>$(awardScaleCaveat 'Def' $awardDefDmgAll_MaxName)</td>     <td>Most damage given + taken ($($awardDefDmgAll_Max))</td></tr>
    <tr><td>Shy Guy</td>             <td align=center width=150px>$(awardScaleCaveat 'Def' $awardDefDmgTaken_MinName)</td>   <td>Lowest damage taken ($($awardDefDmgTaken_Min))</td></tr>
    <tr><td>Mr Magoo</td>            <td align=center width=150px>$($awardDefMagoo_MaxName)</td>      <td>Team Kill/Damage above avg ($('{0:p0}' -f $awardDefMagoo_Max))</td></tr>`n"

    if ($arrResult.winningTeam -eq 2) {
      $awardsHtml += "<tr><td colspan=3 align=right><i>*Team1 scaled: Only $('{0:p0}' -f [math]::Round((1 - $arrResult.winRating),2)) of Rnd2 played</i></td></tr>`n"
    }
    $awardsHtml += "</table></div></div>"

    ###
    # Generate the HTML Ouput
    ###
    $htmlOut = "<html>
      <head>
        <style>
          table, th, td {
            border: 1px solid black;
            border-collapse: collapse;
            min-width: 20px;
          }
        </style>
      </head>
      <body>
        <h1>$($jsonFile.Name)</h1>"


    $htmlOut += "<table cellpadding=`"3`">
    <tr><th>Result</th><th>Scores</th><th>Win Rating</th></tr>
    <tr><td bgcolor=`"$(teamColorCode $arrResult.winningTeam)`">"  

    switch ($arrResult.winningTeam) {
      '0'     { $htmlOut += "DRAW! "                                  }
      default { $htmlOut += "TEAM $($arrResult.winningTeam) WINS! "   }
    }

    $htmlOut += "</td><td>Team1: $($arrResult.team1Score) vs Team2: $($arrResult.team2Score)</td><td>$('{0:p0}' -f $arrResult.winRating) ($($arrResult.winRatingDesc))</td></tr>`n</table>`n"  

    #### awards
    $htmlOut += "<hr><h2>Awards</h2>`n"
    $htmlOut += $awardsHtml

    #Frag Total Table
    $htmlOut += "<hr><h2>TOTAL - Frags and Damage</h2>`n"  
    $htmlOut += GenerateFragHtmlTable ''
    $htmlOut += GenerateDmgHtmlTable ''
   

    $htmlOut += "<hr><h2>Frags - Round 1 and Round 2</h2>`n"  
    $htmlOut += GenerateFragHtmlTable -Round '1'
    $htmlOut += GenerateFragHtmlTable -Round '2'

  

    #Damage by Round Table
    $htmlOut += "<hr><h2>Damage - Round 1 and Round 2</h2>`n"  
    $htmlOut += GenerateDmgHtmlTable -Round '1'
    $htmlOut += GenerateDmgHtmlTable -Round '2'
   

    ###
    # frag/death per mins
    ###

    $htmlOut += "<hr><h2>Per Minute - Frags/Deaths</h2>`n"  

    $tableHeader = "<table style=""display:inline-table"">$($tableStyle2)
    <tr><th colspan=6></ht><th colspan=$([math]::Ceiling($round1EndTime / 60) + 1)>Rnd1</ht><th colspan=$($timeBlock - $([math]::Ceiling($round1EndTime / 60)) + 1)>Rnd2</th></tr>
    <tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Kills</th><th $($columStyle)>Dth</th><th $($columStyle)>TK</h>"
    $table = ''

    foreach ($min in 1..$timeBlock) { 
      $tableHeader += "<th $($columStyle)>$($min)</th>" 
      if ($min -in $timeBlock,([math]::Floor($round1EndTime / 60))) { 
        $tableHeader += "<th $($columStyle)>Total</th>" 
      }
    }
    $tableHeader += "</tr>`n"

    $count = 1
    $subtotalFrg = @(1..$timeBlock | foreach { 0 } )
    $subtotalDth = @(1..$timeBlock | foreach { 0 } )

    foreach ($p in $playerList) {
      $kills = ($arrPlayerTable | Where Name -eq $p | Measure Kills -Sum).Sum
      $death = ($arrPlayerTable | Where Name -eq $p | Measure Death -Sum).Sum
      $tKill = ($arrPlayerTable | Where Name -eq $p | Measure TKill -Sum).Sum
      $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($kills)</td><td>$($death)</td><td>$($tKill)</td>"
      
      $count2 = 0  
      foreach ($min in 1..$timeBlock) {
        $key = "$($min)_$($p)"
        $kills = $arrFragMin.$key
        $dth   = $arrDeathMin.$key
        if ($kills -in '',$null -and $dth -in '',$null) { 
          $value  = ''
          $cellCC = nullValueColorCode
        } else {
          $cellCC = $ccGreen
          if ($kills -lt $dth) { $cellCC = $ccAmber }
          if ($kills -eq '' -or $kills -lt 1) { $kills = '0'; $cellCC = $ccOrange }
          if ($dth   -eq '' -or $dth   -lt 1) { $dth   = '0' }

          $value = "$($kills)/$($dth)"
        }

        $table += "<td bgcolor=`"$($cellCC)`" width=40px>$($value)</td>"
        
        $subtotalFrg[$count2] += $kills
        $subtotalDth[$count2] += $dth


        if ($min -in $timeBlock,([math]::Floor($round1EndTime / 60))) {
          #rnd total
          if ($min -le ([math]::Floor($round1EndTime / 60)))  {
            $round = 1            
          } else {
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

    $table += '<tr><td colspan=6 align=right padding=2px><b>Total:</b></td>'
    $count = 0
    foreach ($st in $subtotalFrg) { 
      $table += "<td>$([int]$subtotalFrg[$count])/$([int]$subtotaldth[$count])</td>"
      $count += 1 
      if ($count -in $timeBlock,([math]::Floor($round1EndTime / 60))) { $table += "<td></td>" }
    }
    $table += "</tr>`n"

    $htmlOut += $tableHeader      
    $htmlOut += $table            
    $htmlOut += "</table>`n"        

    ###
    # Damage per mins
    ###
    $htmlOut += "<hr><h2>Per Minute - Damage <i>(excluding friendly-fire)</i></h2>`n"  
    #$tableHeader = "<table style=""width:30%;display:inline-table"">$($tableStyle2)<tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Kills</th><th $($columStyle)>Dth</th><th $($columStyle)>TK</h>"
    #resue the previous table header.

    $table = ''
    $subtotalDmg = @(1..$timeBlock | foreach { 0 } )
    $count = 1

    $tableHeader = $tableHeader -replace '>Kills<','>Dmg<'

    foreach ($p in $playerList) {
      $dmg   = ($arrPlayerTable | Where Name -eq $p | Measure Dmg -Sum).Sum
      $death = ($arrPlayerTable | Where Name -eq $p | Measure Death -Sum).Sum
      $tKill = ($arrPlayerTable | Where Name -eq $p | Measure TKill -Sum).Sum
      $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($dmg)</td><td>$($death)</td><td>$($tKill)</td>"
      
      $count2 = 0  
      foreach ($min in 1..$timeBlock) {
        $key = "$($min)_$($p)"
        $dmg = $arrDmgMin.$key
        if ($kills -eq '' -or $kills -lt 1) { $kills = 0 }

        $table += "<td bgcolor=`"$((nullValueColorCode $dmg $ccGreen))`" width=40px>$($dmg)</td>"

        $subtotalDmg[$count2] += $dmg

        if ($min -in $timeBlock,([math]::Floor($round1EndTime / 60))) {
          #rnd total
          if ($min -le ([math]::Floor($round1EndTime / 60)))  {
            $round = 1
          } else {
            $round = 2
          }
          $dmg   = ($arrPlayerTable | Where { $_.Name -eq $p -and $_.Round -eq $round } | Measure Dmg -Sum).Sum
          $table += "<td>$($dmg)</td>"
        }

        $count2 +=1
      }

      $table += "</tr>`n"
      $count += 1 
    }

    $table += '<tr><td colspan=6 align=right padding=2px><b>Total:</b></td>'

    $count = 0
    foreach ($st in $subtotalDmg) { 
      $table += "<td>$($subtotalDmg[$count])</td>"
      $count += 1

      if ($count -in $timeBlock,([math]::Floor($round1EndTime / 60))) { $table += "<td></td>" }
    }
    $table += "</tr>`n"

    $htmlOut += $tableHeader      
    $htmlOut += $table            
    $htmlOut += "</table>`n"        


    ###
    # Flag Cap/Took/Drop per min
    ###
    $htmlOut += "<hr><h2>Per Minute - Flag stats</h2>`n"  

    $tableHeader = "<table style=""width:30%;display:inline-table"">$($tableStyle2)
    <tr><th colspan=8></ht><th colspan=$([math]::Ceiling($round1EndTime / 60))>Rnd1 <i>(Cp/Tk/Thr or Stop)</i></ht><th colspan=$($timeBlock - $([math]::Ceiling($round1EndTime / 60)))>Rnd2 <i>(Cp/Tk/Thr or Stop)</i></th></tr>
    <tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Caps</th><th $($columStyle)>Took</th><th $($columStyle)>Throw</h><th $($columStyle)>Time</h><th $($columStyle)>Stop</h>"
    $table = ''

    foreach ($min in 1..$timeBlock) { $tableHeader += "<th $($columStyle)>$($min)</th>" }
    $tableHeader += "</tr>`n"

    $count = 1
    $subtotalCap   = @(1..$timeBlock | foreach { 0 } )
    $subtotalTook  = @(1..$timeBlock | foreach { 0 } )
    $subtotalThrow = @(1..$timeBlock | foreach { 0 } )

    foreach ($p in $playerList) {    
      #$pos = arrFindPlayer -Table ([ref]$arrPlayerTable) -Player $p 
      $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td>
                    <td>$(($arrPlayerTable | Where Name -EQ $p | Measure FlagCap   -Sum).Sum)</td>
                    <td>$(($arrPlayerTable | Where Name -EQ $p | Measure FlagTake  -Sum).Sum)</td>
                    <td>$(($arrPlayerTable | Where Name -EQ $p | Measure FlagThrow -Sum).Sum)</td>
                    <td>$("{0:m\:ss}" -f [timespan]::FromSeconds( ($arrPlayerTable | Where Name -EQ $p | Measure FlagTime -Sum).Sum ) )</td>
                    <td>$(($arrPlayerTable | Where Name -EQ $p | Measure FlagStop -Sum).Sum)</td>"
      
      
      $count2 = 0
      foreach ($min in 1..$timeBlock) {
        $key = "$($min)_$($p)"
        $cap    = $arrFlagCapMin.$key
        $took   = $arrFlagTookMin.$key
        $throw  = $arrFlagThrowMin.$key
        $stop   = $arrFlagStopMin.$key

        if ($cap -in '',$null -and $took -in '',$null) { 
          if ($Stop -notin '',$null) {
            $value = $stop
            $cellCC = $ccAmber
          } else {
            $value  = ''
            $cellCC = nullValueColorCode
          }
        } else {
          $subtotalCap[$count2]  += $cap
          if ($took -in '',$null) { $took = 0 }
          $subtotalTook[$count2] += $Took
          if ($throw -in '',$null) { $throw = 0 }
          $subtotalThrow[$count2] += $Throw
          $cellCC = $ccGreen
          if ($cap  -in '',$null) { $cap =  '0'; $cellCC = $ccOrange }
          $value = "$($cap)/$($Took)/$($throw)"
        }

        $table += "<td bgcolor=`"$($cellCC)`">$($value)</td>"
        $count2 +=1
      }

      $table += "</tr>`n"
      $count += 1 
    }

    $table += '<tr><td colspan=8 align=right padding=2px><b>Total:</b></td>'
    $count = 0
    foreach ($st in $subtotalCap) { 
      $table += "<td>$($subtotalCap[$count])/$($subtotalTook[$count])/$($subtotalThrow[$count])</td>"
      $count += 1
    }
    $table += "</tr>`n"

    $htmlOut += $tableHeader      
    $htmlOut += $table
    $htmlOut += "</table>`n"

    Remove-Variable cellCC,value,took,cap,key,subtotalCap,subtotalTook

    ###
    # Class related tables....
    ###

    $count = 1
    $tableHeader = "<table>
    <tr><th colspan=13 height=21px></th></tr>
    <tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Kills</th>
    <th $($columStyle)>Sco</th>
    <th $($columStyle)>Sold</th>
    <th $($columStyle)>Demo</th>
    <th $($columStyle)>Med</th>
    <th $($columStyle)>HwG</th>
    <th $($columStyle)>Pyro</th>
    <th $($columStyle)>Spy</th>
    <th $($columStyle)>Eng</th>
    <th $($columStyle)>SG</th></tr>`n"

    $table = ''
    $subtotalFrg = @($ClassAllowedwithSG | foreach { 0 }) 
    $subtotalDth = @($ClassAllowedwithSG | foreach { 0 }) 

    foreach ($p in $playerList) { 
      $kills = ($arrPlayerTable | Where Name -eq $p | Measure Kills -sum).Sum
      $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($kills)</td>"

      $count2 = 0
      foreach ($o in ($ClassAllowedwithSG)) {
        $key = "$($p)_$($o)"
        $kills = ($arrWeaponTable | Where { $_.Name -eq $p -and $_.PlayerClass -eq $o } | Measure-Object Kills -Sum).Sum
        $dth   = ($arrWeaponTable | Where { $_.Name -eq $p -and $_.PlayerClass -eq $o } | Measure-Object Death -Sum).Sum

        if ($kills + $dth -gt 0) {
          $table += "<td>$($kills)/$($dth)</td>"
        } else {
          $table += "<td bgcolor=`"#F1F1F1`"></td>"
        }

        $subtotalFrg[$count2] += $kills
        $subtotalDth[$count2] += $dth
        $count2 +=1
      }

      $table += "</tr>`n"
      $count += 1 
    }

    $table += '<tr><td colspan=4 align=right padding=2px><b>Total:</b></td>'
    $count = 0
    foreach ($st in $subtotalFrg) { $table += "<td>$(if (0 -ne $subtotalFrg[$count] + $subtotalDth[$count]) { "$($subtotalFrg[$count])/$($subtotalDth[$count])" })</td>"; $count++ }


    #'<div class="row"><div class="column">' | Out-File -FilePath $$htmlOut +=  -Append
    $htmlOut += '<hr><div class="row">'             
    $htmlOut += '<div class="column" style="width:550px;display:inline-table">' 
    $htmlOut += "<h2>Kills/Deaths By Class</h2>`n"  
    $htmlOut += $tableHeader                        
    $htmlOut += $table                              
    $htmlOut += '</table>'      
    $htmlOut += '</div><div class="column" style="width:550px;display:inline-table">' 


    $table = ''
    $tableHeader = "<table><tr><th colspan=3></th><th colspan=9>Rnd1</th><th colspan=9>Rnd2</th></tr>
    <tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th>K/D</h>
    <th $($columStyle)>Sco</th><th $($columStyle)>Sold</th><th $($columStyle)>Demo</th><th $($columStyle)>Med</th><th $($columStyle)>HwG</th><th $($columStyle)>Pyro</th><th $($columStyle)>Spy</th><th $($columStyle)>Eng</th>
    <th>K/D</h><th $($columStyle)>Sco</th><th $($columStyle)>Sold</th><th $($columStyle)>Demo</th><th $($columStyle)>Med</th><th $($columStyle)>HwG</th><th $($columStyle)>Pyro</th><th $($columStyle)>Spy</th><th $($columStyle)>Eng</th>
    </tr>"

    $count = 1
    foreach ($p in $playerList) {
        $pos = arrFindPlayer -Table ([ref]$arrPlayerTable) -Player $p -Round $r
        if ($arrPlayerTable[$pos].Death -in 0,'',$null) { $kd = 'n/a' }
        else { $kd = [math]::Round( $arrPlayerTable[$pos].Kills / $arrPlayerTable[$pos].Death ,2) }


        $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td>"
        
      foreach ($r in 1..2) {
        $table += "<td>$($kd)</td>"

        $count2 = 1
        foreach ($o in $classAllowed) {
          $key = "$($p)_$($o)"
        
          if ((Get-Variable "arrTimeClassRnd$r").Value.$key -in '',$null -or $kd -eq 'n/a') { $time = '' }
          else { $time = "{0:m\:ss}" -f [timespan]::FromSeconds((Get-Variable "arrTimeClassRnd$r").Value.$key) }

          if ($time) { $table += "<td>$($time)</td>" }
          else       { $table += "<td bgcolor=`"#F1F1F1`"></td>" }
          $count2 +=1
        }
      }
      $table += "</tr>`n"
      $count += 1 
    }

      
    #'<div class="column">'                
    $htmlOut += "<h2>Estimated Time per Class</h2>`n"
    $htmlOut += $tableHeader                          
    $htmlOut += $table                                
    $htmlOut += '</table>'          
    $htmlOut += '</div></div>'          

    #Stats for each player
    $htmlOut += "<hr><h2>Player Weapon Stats </h2>`n"   

    $count = 1
    $table = ''
    $tableHeader =  '<table><tr><th colspan="2"></th><th colspan="6">Rnd1</th><th colspan="6">Rnd2</th></tr>' #<th colspan="6">Total</th></tr>'
    $tableHeader += "<tr><th $($columStyle)>Weapon</th><th>Class</th><th $($columStyle)>Shots</th><th $($columStyle)>Hit%</th><th $($columStyle)>Kills</th><th $($columStyle)>Dmg</th><th $($columStyle)>Dth</th><th $($columStyle)>DmgT</th><th $($columStyle)>Shots</th><th $($columStyle)>Hit%</th><th $($columStyle)>Kills</th><th $($columStyle)>Dmg</th><th $($columStyle)>Dth</th><th $($columStyle)>DmgT</th></tr>`n" #<th $($columStyle)>Shots</th><th $($columStyle)>Hit%</th><th $($columStyle)>Kills</th><th $($columStyle)>Dmg</th><th $($columStyle)>Dth</th><th $($columStyle)>DmgT</th></tr>`n"

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

      $pClassKeys = @()
      $totalTime  = 0
      $classStats = ''
      $pClassKeys = $arrTimeClassRnd1.Keys | foreach { if ($_ -match "^$($p -replace $regExReplaceFix)_[1-9]`$") { $_ } } 
      foreach ($i in $pClassKeys) { $totalTime += $arrTimeClassRnd1.$i }
      foreach ($i in $pClassKeys) { $classStats += "$($ClassToStr[($i -split '_')[1]]) ($('{0:p0}' -f ($arrTimeClassRnd1.$i / $totalTime))) " } 
    
      $htmlOut += "<b>Rnd1:</b> $($classStats) | " 

      $pClassKeys = @()
      $totalTime  = 0
      $classStats = ''
      $pClassKeys = $arrTimeClassRnd2.Keys | foreach { if ($_ -match "^$($p -replace $regExReplaceFix)_[1-9]`$") { $_ } } 

      foreach ($i in $pClassKeys) { $totalTime += $arrTimeClassRnd2.$i }
      foreach ($i in $pClassKeys) { $classStats += "$($ClassToStr[($i -split '_')[1]]) ($('{0:p0}' -f ($arrTimeClassRnd2.$i / $totalTime))) " }

      $htmlOut += "<b>Rnd2:</b> $($classStats)<br><br>" 
      Remove-Variable pClassKeys, totalTime, classStats

      $playerStats = ''
      $lastClass   = ''
      $totKill  = @(0,0,0)
      $totDmg   = @(0,0,0)
      $totDth   = @(0,0,0)
      $totDmgTk = @(0,0,0)
      $foundFF  = 0

      $allWeapKeys  = $arrWeaponTable | Where { $_.Name -eq $p -and $_.Weapon -notmatch '^(world|suicide|.*-ff)$'} `
                                      | Group-Object Class,Weapon `
                                      | %{ $_.Group | Select Class,Weapon -First 1 } `
                                      | Sort-Object Class,Weapon
      $allWeapKeys += $arrWeaponTable | Where { $_.Name -eq $p -and $_.Weapon -match '^(world|suicide|.*-ff)$'} `
                                      | Group-Object Class,Weapon `
                                      | %{ $_.Group | Select Class,Weapon -First 1 } `
                                      | Sort-Object Class,Weapon

      foreach ($w in $allWeapKeys) {
        if ($w.Class -eq 10) { $class = 9 }
        else                 { $class = $w.Class}
        $weapon = $w.Weapon

        $objRnd1 = [PSCustomObject]@{ Name=$p; Class=$class; Kills=0; Dmg=0; Death=0; DmgTaken=0; AttackCount=''; HitPercent=''; pos=-1 }
        $objRnd2 = [PSCustomObject]@{ Name=$p; Class=$class; Kills=0; Dmg=0; Death=0; DmgTaken=0; AttackCount=''; HitPercent=''; pos=-1 }
        $objRnd1.pos = arrFindPlayer-WeaponTable -Name $p -Round 1 -Weapon $weapon -Class $w.Class
        $objRnd2.pos = arrFindPlayer-WeaponTable -Name $p -Round 2 -Weapon $weapon -Class $w.Class
        
        foreach ($o in @($objRnd1,$objRnd2)) {
          if ($o.pos -gt -1) {  
            $o.Kills = $arrWeaponTable[$o.pos].Kills
            $o.Dmg   = [double]$arrWeaponTable[$o.pos].Dmg
            $o.Death = [double]$arrWeaponTable[$o.pos].Death
            $o.DmgTaken = [double]$arrWeaponTable[$o.pos].DmgTaken
            if ($arrWeaponTable[$o.pos].AttackCount -gt 0) {
              $o.AttackCount = [double]$arrWeaponTable[$o.pos].AttackCount
              $o.HitPercent  = [double]$arrWeaponTable[$o.pos].DmgCount / [double]$arrWeaponTable[$o.pos].AttackCount
            }
            
          }
        } 

        if ($class -ne $lastClass -and $foundFF -lt 1) {        
          if ($lastClass -ne '') {
            $playerStats += "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td colspan=2 align=right><b>$($ClassToStr[$lastClass]) Totals:</b></td>
                              <td></td><td></td><td>$(nullValueAsBlank $totKill[0])</td><td>$(nullValueAsBlank $totDmg[0])</td><td>$(nullValueAsBlank $totDth[0])</td><td>$(nullValueAsBlank $totDmgTk[0])</td>
                              <td></td><td></td><td>$(nullValueAsBlank $totKill[1])</td><td>$(nullValueAsBlank $totDmg[1])</td><td>$(nullValueAsBlank $totDth[1])</td><td>$(nullValueAsBlank $totDmgTk[1])</td></tr>"
                              #<td></td><td></td><td>$(nullValueAsBlank $totKill[2])</td><td>$(nullValueAsBlank $totDmg[2])</td><td>$(nullValueAsBlank $totDth[2])</td><td>$(nullValueAsBlank $totDmgTk[2])</td></tr>"
          }
          
          if ($weapon -match '(world|suicide|-ff)$') { $foundFF++ }
          
          $lastClass = $class
          $totKill  = @(0,0,0)
          $totDmg   = @(0,0,0)
          $totDth   = @(0,0,0)
          $totDmgTk = @(0,0,0)
        }

        $totKill[0]  += [double]$objRnd1.Kills;    $totKill[1]  += [double]$objRnd2.Kills;    $totKill[2]  = ([double]$totKill[0]  + [double]$totKill[1])
        $totDmg[0]   += [double]$objRnd1.Dmg;      $totDmg[1]   += [double]$objRnd2.Dmg;      $totDmg[2]   = ([double]$totDmg[0]   + [double]$totDmg[1])  
        $totDth[0]   += [double]$objRnd1.Death;    $totDth[1]   += [double]$objRnd2.Death;    $totDth[2]   = ([double]$totDth[0]   + [double]$totDth[1])
        $totDmgTk[0] += [double]$objRnd1.DmgTaken; $totDmgTk[1] += [double]$objRnd2.DmgTaken; $totDmgTk[2] = ([double]$totDmgTk[0] + [double]$totDmgTk[1])
        
        if ($weapon -match '^(world|suicide|.*-ff$)') {
          $ccNormOrSuicide = $ccAmber
        } else {
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

        $playerStats += "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($weapon)</td><td>$($ClassToStr[$class])</td>
                          <td bgcolor=`"$(nullValueColorCode ($objRnd1.AttackCount) $ccGreen)`">$(nullValueAsBlank $objRnd1.AttackCount)</td>
                            <td bgcolor=`"$(nullValueColorCode ($objRnd1.HitPercent) $ccGreen)`">$('{0:P0}' -f (nullValueAsBlank $objRnd1.HitPercent))</td>
                            <td bgcolor=`"$(nullValueColorCode ($objRnd1.Kills) $ccGreen)`">$(nullValueAsBlank $objRnd1.Kills)</td>
                            <td bgcolor=`"$(nullValueColorCode ($objRnd1.Dmg) $ccGreen)`">$(nullValueAsBlank $objRnd1.Dmg)</td>
                            <td bgcolor=`"$(nullValueColorCode ($objRnd1.Death) $ccNormOrSuicide)`">$(nullValueAsBlank $objRnd1.Death)</td>
                            <td bgcolor=`"$(nullValueColorCode ($objRnd1.DmgTaken) $ccNormOrSuicide)`">$(nullValueAsBlank $objRnd1.DmgTaken)</td>
                          <td bgcolor=`"$(nullValueColorCode ($objRnd2.AttackCount) $ccGreen)`">$(nullValueAsBlank $objRnd2.AttackCount)</td>
                            <td bgcolor=`"$(nullValueColorCode ($objRnd2.HitPercent) $ccGreen)`">$('{0:P0}' -f (nullValueAsBlank $objRnd2.HitPercent))</td>
                            <td bgcolor=`"$(nullValueColorCode ($objRnd2.Kills) $ccGreen)`">$(nullValueAsBlank $objRnd2.Kills)</td>
                            <td bgcolor=`"$(nullValueColorCode ($objRnd2.Dmg) $ccGreen)`">$(nullValueAsBlank $objRnd2.Dmg)</td>
                            <td bgcolor=`"$(nullValueColorCode ($objRnd2.Death) $ccNormOrSuicide)`">$(nullValueAsBlank $objRnd2.Death)</td>
                            <td bgcolor=`"$(nullValueColorCode ($objRnd2.DmgTaken) $ccNormOrSuicide)`">$(nullValueAsBlank $objRnd2.DmgTaken)</td></tr>`n"
                          <# Removed Sub totals - too large
                            <td bgcolor=`"$(nullValueColorCode $subTotalShot    $ccGreen)`">$(nullValueAsBlank $subTotalShot)</td>
                            <td bgcolor=`"$(nullValueColorCode $subTotalHit   $ccGreen)`">$('{0:P0}' -f (nullValueAsBlank $subTotalHit))</td>
                            <td bgcolor=`"$(nullValueColorCode $subTotalKill  $ccGreen)`">$(nullValueAsBlank $subTotalKill)</td>
                            <td bgcolor=`"$(nullValueColorCode $subTotalDmg   $ccGreen)`">$(nullValueAsBlank $subTotalDmg)</td>    
                            <td bgcolor=`"$(nullValueColorCode $subTotalDth   $ccNormOrSuicide)`">$(nullValueAsBlank $subTotalDth)</td>
                            <td bgcolor=`"$(nullValueColorCode $subTotalDmgTk $ccNormOrSuicide)`">$(nullValueAsBlank $subTotalDmgTk)</td></tr>`n"#>

      } #end foreach

      if ($foundFF) { $lastClass = 'Friendly' }
      
      $playerStats += "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td colspan=2 align=right><b>$($lastClass) Totals:</b></td>
                      <td></td><td></td><td>$(nullValueAsBlank $totKill[0])</td><td>$(nullValueAsBlank $totDmg[0])</td><td>$(nullValueAsBlank $totDth[0])</td><td>$(nullValueAsBlank $totDmgTk[0])</td>
                      <td></td><td></td><td>$(nullValueAsBlank $totKill[1])</td><td>$(nullValueAsBlank $totDmg[1])</td><td>$(nullValueAsBlank $totDth[1])</td><td>$(nullValueAsBlank $totDmgTk[1])</td></tr>`n"
                      #<td></td><td></td><td>$(nullValueAsBlank $totKill[2])</td><td>$(nullValueAsBlank $totDmg[2])</td><td>$(nullValueAsBlank $totDth[2])</td><td>$(nullValueAsBlank $totDmgTk[2])</td></tr>`n"

      $htmlOut += $tableHeader       
      $htmlOut += $playerStats       
      $htmlOut += "</table>`n"         


      $count += 1 
    }

    $htmlOut += '</div></div>' 
    $htmlOut += "</body></html>"     

    $htmlOut | Out-File -FilePath "$outFileStr.html"
    if ($OpenHTML) { & "$outFileStr.html" }
  }   #end html generation



  ## Object/Table for Text-base Summaries
  $arrResultTable += [pscustomobject]@{ 
                         Match      = $jsonFile.BaseName -replace '_blue_vs_red.*',''
                         Winner = switch ($arrResult.winningTeam) { '0' { "Draw" }; "1" { "Team1" }; "2" { "Team2" } } 
                         Rating = $arrResult.winRating
                         Score1 = $arrResult.team1Score
                         Score2 = $arrResult.team2Score
                         Team1 = ($playerlist | ForEach-Object { if ($arrTeam.$_ -match "1") { $_ } }) -join ','
                         Team2 = ($playerlist | ForEach-Object { if ($arrTeam.$_ -match "2") { $_ } }) -join ','
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
          $key = "$($p)_$($i)"
          $time  = [int](Get-Variable "arrTimeClassRnd$round").Value.$key
          $kills = ($arrWeaponTable | Where { $_.Name -eq $p -and $_.Class -eq $i -and $_.Round -eq $round } | Measure-Object Kills -Sum).Sum
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
        $arrTeam.$p -match "[1-2]&[1-2]"}  { 
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


function Format-MinSec {
  param($sec)

  $ts = New-TimeSpan -Seconds $sec
  $mins = ($ts.Days * 24 + $ts.Hours) * 60 + $ts.minutes
  return "$($mins):$("{0:d2}" -f $ts.Seconds)"
}

#Value Per Minute
function Table-CalculateVPM {
  param($Value,$TimePlayed,$Round)
  
  if ($Value -eq 0) { return '' }
  if ($Round -in '',$null) { $Round = 2 }

  if (!$TimePlayed) { return '' }
  return [math]::Round($Value / ($TimePlayed/60),$Round)
}

function Table-ClassInfo {
  param([ref]$Table,$Name,$TimePlayed)
  $out = ''
  $classlist = @{}
  foreach ($p in [array]$Table.Value) {
    if ($p.Name -eq $Name) {
      foreach ($class in $ClassAllowed) {
        $strClass = $ClassToStr[$class]
        $time     = $p.($strClass)

        if ($time -notin 0,'',$null) {
          $classlist.$strClass = ($time / $TimePlayed)
        }
      }

      foreach ($c in ($classlist.GetEnumerator() | Sort-Object Value -Descending)) {        
        $out += "$(($c.Name).PadRight(4)) $(('{0:P0}' -f $c.Value).PadLeft(3))|"
      }
      
      return $out -replace '\|$',''
    }
  }
}


$textOut = ''
$textOut += "###############"
$textOut += "`n   Game Log "
$textOut += "`n###############"
$textOut += $arrResultTable | Format-Table Match,Winner,@{L='Rating';E={'{0:P0}' -f $_.Rating}},Score1,Team1,Score2,Team2 -Wrap | Out-String

$textOut += "`n##############$(if ($jsonFileCount -gt 1) { "##############" })"
$textOut += "`n FINAL TOTALS $(if ($jsonFileCount -gt 1) { " - $jsonFileCount games" })"
$textOut += "`n##############$(if ($jsonFileCount -gt 1) { "##############" })`n"
$textOut += "`nAttack Summary`n"

# Update the Attack Table into presentation format
foreach ($i in $arrSummaryAttTable) {
  $i.KPM = Table-CalculateVPM $i.Kills $i.TimePlayed
  if ($i.Death) { $i.KD  = [math]::Round($i.Kills / $i.Death,2) }
  $i.DPM = Table-CalculateVPM $i.Dmg $i.TimePlayed 0
  $i.Classes    = (Table-ClassInfo ([ref]$arrClassTimeAttTable) $i.Name $i.TimePlayed)
  $i.FlagTime   = "{0:m\:ss}" -f [timespan]::FromSeconds( $i.FlagTime )
  $i.TimePlayed = Format-MinSec $i.TimePlayed
}

$textOut += $arrSummaryAttTable | Format-Table Name,KPM,KD,Kills,Death,TKill,Dmg,DPM,FlagCap,FlagTake,FlagTime,TimePlayed,Classes | Out-String
                                   <# OLD - See presentation format above
                                   @{Label='KPM';Expression={ Table-CalculateVPM $_.Kills $_.TimePlayed }},@{Label='K/D';Expression={ [math]::Round($_.Kills / $_.Death,2) }}, ` 
                                   Kills,Death,TKill,Dmg, `
                                   @{Label='DPM';Expression={ Table-CalculateVPM $_.Dmg $_.TimePlayed 0 }}, `
                                   FlagCap,FlagTake,FlagTime, `
                                   @{Label='TimePlayed';Expression={ Format-MinSec $_.TimePlayed }}, `
                                   @{Label='Classes';Expression={ Table-ClassInfo ([ref]$arrClassTimeAttTable) $_.Name $_.TimePlayed }}  `
                                | Out-String#>


# Update the Def Table into presentation format
foreach ($j in $arrSummaryDefTable) {
  $j.KPM = Table-CalculateVPM $j.Kills $j.TimePlayed
  $j.KD  = [math]::Round($j.Kills / $j.Death,2)
  $j.DPM = Table-CalculateVPM $j.Dmg $j.TimePlayed 0
  $j.Classes    = (Table-ClassInfo ([ref]$arrClassTimeDefTable) $j.Name $j.TimePlayed)
  $j.TimePlayed = Format-MinSec $j.TimePlayed
}

$textOut += "Defence Summary`n"
$textOut += $arrSummaryDefTable | Format-Table Name,KPM,KD,Kills,Death,TKill,Dmg,DPM,FlagStop,Win,Draw,Loss,TimePlayed,Classes | Out-String
                                   <# OLD - See presentation format above
                                   @{Label='KPM';Expression={ Table-CalculateVPM $_.Kills $_.TimePlayed }},@{Label='K/D';Expression={ [math]::Round($_.Kills / $_.Death,2) }}, `
                                   Kills,Death,TKill,Dmg, `
                                   @{Label='DPM';Expression={ Table-CalculateVPM $_.Dmg $_.TimePlayed 0 }}, `
                                   FlagStop,Win,Draw,Loss, `
                                   @{Label='TimePlayed';Expression={ Format-MinSec $_.TimePlayed }}, `
                                   @{Label='Classes';Expression={ Table-ClassInfo ([ref]$arrClassTimeDefTable) $_.Name  $_.TimePlayed  }}  `
                                | Out-String#>

$textOut += "Class Kills / KPM Summary - Attack`n"
$textOut += $arrClassFragAttTable  | Format-Table Name,Sco,@{L='KPM';E={ Table-CalculateVPM $_.Sco ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Sco  }}, `
                                      Sold, @{L='KPM';E={ Table-CalculateVPM $_.Sold ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Sold }}, `
                                      Demo, @{L='KPM';E={ Table-CalculateVPM $_.Demo ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Demo }}, `
                                      Med,  @{L='KPM';E={ Table-CalculateVPM $_.Med  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Med  }}, `
                                      HwG,  @{L='KPM';E={ Table-CalculateVPM $_.HwG  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).HwG  }}, `
                                      Pyro, @{L='KPM';E={ Table-CalculateVPM $_.Pyro ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Pyro }}, `
                                      Spy,  @{L='KPM';E={ Table-CalculateVPM $_.Spy  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Spy  }}, `
                                      Eng,  @{L='KPM';E={ Table-CalculateVPM $_.Eng  ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Eng  }}, `
                                      SG,   @{L='KPM';E={ Table-CalculateVPM $_.SG   ($arrClassTimeAttTable | Where-Object Name -EQ $_.Name).Eng  }}  `
                                   | Out-String
   
$textOut += "Class Kills / KPM Summary - Defence`n"
$textOut += $arrClassFragDefTable  | Format-Table Name,Sco,@{L='KPM';E={ Table-CalculateVPM $_.Sco ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Sco  }}, `
                                      Sold, @{L='KPM';E={ Table-CalculateVPM $_.Sold ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Sold }}, `
                                      Demo, @{L='KPM';E={ Table-CalculateVPM $_.Demo ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Demo }}, `
                                      Med,  @{L='KPM';E={ Table-CalculateVPM $_.Med  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Med  }}, `
                                      HwG,  @{L='KPM';E={ Table-CalculateVPM $_.HwG  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).HwG  }}, `
                                      Pyro, @{L='KPM';E={ Table-CalculateVPM $_.Pyro ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Pyro }}, `
                                      Spy,  @{L='KPM';E={ Table-CalculateVPM $_.Spy  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Spy  }}, `
                                      Eng,  @{L='KPM';E={ Table-CalculateVPM $_.Eng  ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Eng  }}, `
                                      SG,   @{L='KPM';E={ Table-CalculateVPM $_.SG   ($arrClassTimeDefTable | Where-Object Name -EQ $_.Name).Eng  }}  `
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

Write-Host "`n"
Write-Host $textOut



if ($TextSave) {
    if ($jsonFileCount -eq 1) {
    $outFileStr
      $TextFileStr = "$outFileStr.txt"
    } else {   
      $TextFileStr = "$($inputfile[0].Directory.FullName)\FO_Stats_Summary-$($jsonFileCount)games-$('{0:yyMMdd_HHmmss}' -f (Get-Date)).txt"
    }
    Out-File -InputObject $textOut -FilePath $TextFileStr
    Write-Host "Text stats saved: $TextFileStr"
}

<# test Weap counter
$arrWeaponTable | `  # | Where { ($_.AttackCount + $_.DmgCount) -GT 0 }  `
                 Sort Round,Team,Name,Class,Weapon `
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