###
# 10/10/2021 22:20
# PS  COMMAND LINE:- & .\script.ps1 'x:\path\filename.json' [<Rnd1 End Time/Seconds>]
# WIN COMMAND LINE:- powershell -Command "& .\script.ps1" "x:\path\filename.json" [<Rnd1 End Time/Seconds>]
# PS  *.JSON:- foreach ($f in (gci 'H:\stats\*.json')) { & .\FO_stats_v1.ps1 ($f.ToString() -replace '\[','`[' -replace '\]','`]') }
###

$regExReplaceFix = '[[+*?()\\.]','\$&'

$ccGrey   = '#F1F1F1'
$ccAmber  = '#FFD900'
$ccOrange = '#FFB16C'
$ccGreen  = '#96FF8F'
$ccBlue   = '#87ECFF'
$ccRed    = '#FF8080'
$ccPink   = '#FA4CFF'

               # 0        1     2     3      4      5    6      7     8     9       10
$ClassToStr = @('World','Sco','Snp','Sold','Demo','Med','HwG','Pyro','Spy','Eng', 'SG')
$ClassAllowed       = @(1,3,4,5,6,7,8,9)
$ClassAllowedwithSG = @(1,3,4,5,6,7,8,9,10)
$TeamToColor  = @('Civ','Blue','Red','Yellow','Green')

#array of team keys, playername
function getPlayerClasses {
  $class = ''
  $arrClass = $args[0] -match "^$($args[1] -replace $regExReplaceFix)_[1-9]`$"

  foreach ($k in $arrClass) {
    $c = $ClassToStr[($k -split '_')[1]]

    if ($class -eq '') { 
      $class  = $c
    } elseif ($c -notin ($class -split ',')) { 
      $class += ", $($c)" 
    }
  }
  $class
}

function nullValueColorCode {
  switch ($args[0]) {
    ''      { $ccGrey  }
    default { $args[1] }
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
    #common
    'info_tfgoal'   { 'laser' }
    'supershotgun'  { 'ssg'   }
    'shotgun'       { 'sg'    }
    'normalgrenade' { 'hgren' }
    'grentimer'     { 'hgren' }
    'axe'           { 'axe'   }
    'spike'         { 'ng'   }

    #scout
    'flashgrenade'  { 'flash' }
    
    #sold
    'proj_rocket'   { 'rl'    }
    'shockgrenade'  { 'shock' }

    #demo 
    'detpack'           { 'detp' }
    'pipebomb'          { 'pipe' }
    'grenade'           { 'gl'   }
    'mirvsinglegrenade' { 'mirv' }
    'mirvgrenade'       { 'mirv' }

    #medic
    'medikit'       { 'bio'  }
    'superspike'    { 'sng'  }

    #hwg
    'proj_bullet'   { 'cann' }

    #pyro
    'pyro_rocket'   { 'incen' }
    'fire'          { 'fire' }
    'flamerflame'   { 'flame' }
    
    #spy - knife
    'proj_tranq'    { 'tranq' }

    #eng
    'spanner'       { 'spann' }
    'empgrenade'    { 'emp'  }
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

# Process input file, make sure it is valid.
$inputFileStr = [String]$args[0] -replace '(?<!`)[\[\]]','`$&'
$inputFile    = (gi $inputFileStr)
$txt          = (gc $inputFileStr)

# Enure JSON files with [ at start and ] (not added in log files)
if ($txt[0] -notmatch '^\[.*') {
  $txt[0] = "[$($txt[0])"
  $txt[$txt.count - 1] = "$($txt[$txt.count - 1])]"
  $txt | Out-File $inputFileStr
}
Remove-Variable txt

if (!(gi $inputFileStr).Exists) { echo "ERROR: File not found - $($inputFileStr)"; return }

# Out file with same-name.html - remove pesky [] braces.
$outFileStr = ($inputFileStr -replace '\.json$','.html'  -replace '`(\[|\])','')
$json = ((Get-Content -Path $inputFileStr -Raw) | ConvertFrom-Json)
"Output file: $($outFileStr)"

#Check for end round time (seconds) - default to 600secs (10mins)
if ($args[1] -is [int] -and $args[1] -gt 0) { $round1EndTime = $args[1] }
else { $round1EndTime = 600 }

$script:arrTeam = @{}
$script:arrFragTotal     = @{}
$script:arrFragTotalRnd1 = @{}
$script:arrFragTotalRnd2 = @{}
$script:arrFragVersus     = @{}
$script:arrFragVersusRnd1 = @{}
$script:arrFragVersusRnd2 = @{}
$script:arrDeath     = @{}
$script:arrDeathRnd1 = @{}
$script:arrDeathRnd2 = @{}
$script:arrTKill     = @{}
$script:arrTKillRnd1 = @{}
$script:arrTKillRnd2 = @{}
$script:arrDmgTotal      = @{}
$script:arrDmgTotalRnd1  = @{}
$script:arrDmgTotalRnd2  = @{}
$script:arrDmgTaken      = @{}
$script:arrDmgTakenRnd1  = @{}
$script:arrDmgTakenRnd2  = @{}
$script:arrDmgTeam       = @{}
$script:arrDmgTeamRnd1   = @{}
$script:arrDmgTeamRnd2   = @{}
$script:arrDmgVersus     = @{}
$script:arrDmgVersusRnd1 = @{}
$script:arrDmgVersusRnd2 = @{}

$script:arrFragClass  = @{}
$script:arrDeathClass = @{}
$script:arrDmgClass   = @{}

$script:arrKilledClass     = @{}
$script:arrKilledClassRnd1 = @{}
$script:arrKilledClassRnd2 = @{}

$script:arrTimeClass = @{}
$script:arrTimeClassRnd1 = @{}
$script:arrTimeClassRnd2 = @{}

$script:arrTimeFlag = @{}
$script:arrTimeFlagRnd1 = @{}
$script:arrTimeFlagRnd2 = @{}

$script:arrTimeTrack = @{}
$script:arrTeam     = @{}
$script:arrTeamRnd1 = @{}
$script:arrTeamRnd2 = @{}

$script:arrWeapFrag = @{}
$script:arrWeapFragRnd1 = @{}
$script:arrWeapFragRnd2 = @{}
$script:arrWeapDmg  = @{}
$script:arrWeapDmgRnd1  = @{}
$script:arrWeapDmgRnd2  = @{}
$script:arrWeapDmgTaken  = @{}
$script:arrWeapDmgTakenRnd1  = @{}
$script:arrWeapDmgTakenRnd2  = @{}
$script:arrWeapDeath  = @{}
$script:arrWeapDeathRnd1  = @{}
$script:arrWeapDeathRnd2  = @{}
$script:arrResult = @{}

$script:arrFragMin     = @{}
$script:arrDmgMin      = @{} 
$script:arrDeathMin    = @{} 

$script:arrFlagCap      = @{}
$script:arrFlagCapMin   = @{}
$script:arrFlagDrop     = @{}
$script:arrFlagDropMin  = @{}
$script:arrFlagTook     = @{}
$script:arrFlagTookMin  = @{}

$script:arrFlagThrow  = @{}
$script:arrFlagStop = @{}
$script:arrFlagThrowMin  = @{}
$script:arrFlagStopMin = @{}

###
# Process the JSON into above arrays (created 'Script' to be readable by all functions)
# keys: Frags/playername, Versus.player_enemy, Classes/player_class#, Weapons/player_weapon
###
$script:round = 1
$script:timeBlock = 1

ForEach ($item in $json) {
  $type    = $item.type
  $kind    = $item.kind

  #Remove any underscores for _ tokens used in Keys 
  $player  = $item.player -replace '_','.' -replace '\s','' # -replace '\[','\[' -replace '\]','\]S'
  $target  = $item.target -replace '_','.' -replace '\s','' #-replace '\[','\[' -replace '\]','\]'
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
        $weap = 'gas'
      } else { continue }
    } 
  }

  # add -ff to weap for friendly-fire
  if ($p_team -eq $t_team -and $weap -ne 'laser') { $weap += '-ff' }

  # change weapon to suidcide for self kills
  if ($player -notin '',$null -and $player -eq $target) { $weap  = 'suicide' }
  
  $key       = "$($player)_$($target)"
  $keyTime   = "$($timeBlock)_$($player)"
  $keyTimeT  = "$($timeBlock)_$($target)"
  $keyClass  = "$($player)_$($class)"
  $KeyClassNoSG = "$($player)_$($classNoSG)"
  $keyClassT = "$($target)_$($t_class)"
  $keyClassK = "$($player)_$($class)_$($t_class)"
  $keyWeap   = "$($player)_$($class)_$($weap)"
  $keyWeapT  = "$($target)_$($class)_$($weap)" 
  
  
  #Round tracking
  #if (($class -eq '0' -and $player -eq 'world' -and $p_team -eq '0' -and $weap -eq 'worldspawn' -and $time -ge $round1EndTime) -and $round -le 1) {    #(($kind -eq 'enemy' -and ..)
  if ($time -gt $round1EndTime -and $round -lt 2) { 
    $round += 1
    
    if ($arrTrackTime.flagPlayer -notin $null,'') {
      $arrTimeFlag."$($arrTrackTime.flagPlayer)" = $arrTrackTime.flagTook - $round1EndTime
      $arrTrackTime.flagTook   = 0
      $arrTrackTime.flagPlayer = ''
    }

    foreach ($p in $arrTeam.Keys) { 
      $arrTimeClass."$($p)_$($arrTimeTrack."$($p)_lastClass")"     += $round1EndTime - $arrTimeTrack."$($p)_lastChange"
      $arrTimeClassRnd1."$($p)_$($arrTimeTrack."$($p)_lastClass")" += $round1EndTime - $arrTimeTrack."$($p)_lastChange"
	  $arrTimeTrack."$($p)_lastClass"  = ''
      $arrTimeTrack."$($p)_lastChange" = $round1EndTime
    }
  } else {
  
    if ($type -in 'playerStart','changeClass') { continue }
    # Class tracking - Player and Target
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
        $arrTimeClass."$($pc[0])_$($lastClass)" += $lastChangeDiff
        if ($round -eq 1) { $arrTimeClassRnd1."$($pc[0])_$($lastClass)" += $lastChangeDiff } 
		else { $arrTimeClassRnd2."$($pc[0])_$($lastClass)" += $lastChangeDiff }
   
		#Update tracker after stuff is tallied
        $arrTimeTrack."$($pc[0])_lastClass"  = $pc[1]
        $arrTimeTrack."$($pc[0])_lastChange" = $time
      }
	}
  }
  
  #Skip environment/world events for kills/dmg stats (or after this), let laser and team scores pass thru
  if ((($player -eq '') -Or ($p_team -eq '0') -or ($t_team -eq '0') -or ($t_class -eq '0') -or ($weap -eq 'worldSpawn')) -and ($type -ne 'teamScores' -and $weap -ne 'laser')) { continue } 
  

  #team tracking
  if ($p_team -notin $null,'' -and $p_team -gt 0 -and $class -gt 0 -and $type -notin 'damageTaken') {     
    if ($arrTeam.$player -in '',$null) {
      #Initialise team info when null
      $arrTeam.$player = $p_team
    } elseif ($p_team -notin ($arrTeam.$player -split '&')) {
      #Else if team not in list add it
      $arrTeam.$player += "&$($p_team)"
    }

    #Do the same for Rnd1 / Rnd2
    switch ($round) {
      '1'     {
        if ($arrTeamRnd1.$player -in '',$null) {
          #Initialise team info when null
          $arrTeamRnd1.$player = $p_team
        } elseif ($p_team -notin ($arrTeamRnd1.$player -split '&')) {
          #Else if team not in list add it
          $arrTeamRnd1.$player += "&$($p_team)"
        }
      }
      default {
        if ($arrTeamRnd2.$player -in '',$null) {
          #Initialise team info when null
          $arrTeamRnd2.$player = $p_team
        } elseif ($p_team -notin ($arrTeamRnd2.$player -split '&')) {
          #Else if team not in list add it
          $arrTeamRnd2.$player += "&$($p_team)"
        }
      
      }
    }
  }

  # Frag and damage counter, + flags + scores + result
  switch ($type) { 
    'kill' {    
      if ($player -ne $target -and $player -notin $null,'') {
        #make sure player did not killed himself and has a name
        if ($p_team -eq $t_team) {
          #team kill recorded, not a normal kill
          $arrTKill.$player += 1
 
          switch ($round) {
            '1'     { $arrTKillRnd1.$player += 1 }
            default { $arrTKillRnd2.$player += 1 }
          }
        } else {
          #Record the normal kill
          switch ($round) {
            '1'     { $arrFragTotalRnd1.$player += 1; $arrWeapFragRnd1.$keyWeap  += 1; $arrKilledClassRnd1.$keyClassK += 1 }
            default { $arrFragTotalRnd2.$player += 1; $arrWeapFragRnd2.$keyWeap  += 1; $arrKilledClassRnd2.$keyClassK += 1 }
          }

          $arrFragTotal.$player   += 1
          $arrFragClass.$keyClass += 1
          $arrKilledClass.$keyClassK += 1
          $arrWeapFrag.$keyWeap   += 1
          $arrFragMin.$keyTime    += 1
        }
      }
    
      #track all deaths on targets AND all versus kills (to see self/team kills in table). Exclude sentry death for player totals.
      #dont track SG deaths except in the class and weapons stats. 
      if ($t_class -ne '10') {
        if ($player -notin $null,'') {
          $arrFragVersus.$key       += 1
          switch ($round) {
            '1'     { $arrFragVersusRnd1.$key += 1 }
            default { $arrFragVersusRnd2.$key += 1 }
          }
        }

        $arrDeath.$target         += 1
        $arrDeathMin.$keyTimeT    += 1
        $arrWeapDeath.$keyWeapT   += 1      

        switch ($round) {
          '1'     { $arrDeathRnd1.$target += 1; $arrWeapDeathRnd1.$keyWeapT += 1 }
          default { $arrDeathRnd2.$target += 1; $arrWeapDeathRnd2.$keyWeapT += 1 }
        }
      } 
	  #record sg deahts in class table only i.e.e Class 10/SG.
      $arrDeathClass.$keyClassT += 1
    }

    'damageDone' {
      if ($player -ne $target) { 
         #make sure player did not hurt himself, not record in totals - versus only.
        if ($p_team -ne $t_team) {
          #track enemy damage only in the total	  
          $arrDmgTotal.$player   += $dmg
          $arrDmgTaken.$target   += $dmg
          $arrDmgClass.$keyClass += $dmg
          $arrWeapDmg.$keyWeap   += $dmg
          $arrDmgMin.$keyTime    += $dmg
          $arrWeapDmgTaken.$keyWeapT += $dmg

          switch ($round) {
            '1'     { $arrDmgTotalRnd1.$player += $dmg; $arrDmgTakenRnd1.$target += $dmg; $arrWeapDmgRnd1.$keyWeap  += $dmg; $arrWeapDmgTakenRnd1.$keyWeapT  += $dmg }
            default { $arrDmgTotalRnd2.$player += $dmg; $arrDmgTakenRnd2.$target += $dmg; $arrWeapDmgRnd2.$keyWeap  += $dmg; $arrWeapDmgTakenRnd2.$keyWeapT  += $dmg }
          }		  
        } else {
          #team dmg
          $arrDmgTeam.$player   += $dmg

          switch ($round) {
            '1'     { $arrDmgTeamRnd1.$player += $dmg }
            default { $arrDmgTeamRnd2.$player += $dmg }
          }
        }
      }
      #record all damage including self/team in versus table
      $arrDmgVersus.$key += $dmg
      switch ($round) {
        '1'     { $arrDmgVersusRnd1.$key += $dmg }
        default { $arrDmgVersusRnd2.$key += $dmg }
      }
    }

    'gameStart' { $map = $item.map }
     
    'goal' {
      #$arrTimeFlag."$($arrTimeTrack.flagPlayer)"    += $time - $arrTimeTrack.flagTook
      #$arrTimeTrack.flagTook   = 0
      #$arrTimeTrack.flagPlayer = ''
      $arrFlagCap.$player     += 1
      $arrFlagCapMin.$keyTime += 1
    }

    'fumble' {
      $arrTimeFlag."$($arrTimeTrack.flagPlayer)"  += $time - $arrTimeTrack.flagTook
      $arrTimeTrack.'flagPlayer' = ''
      $arrTimeTrack.'flagTook'    = 0
      $arrFlagDrop.$player     += 1
      $arrFlagDropMin.$keyTime += 1

       # work out if death or throw
      if ($prevItem.type -eq 'death' -and $prevItem.player -eq $player -and $prevItem.time -eq $time -and $prevItem.kind -ne 'self') {
        $arrFlagStop.($prevItem.attacker) += 1
        $arrFlagStopMin."$($timeBlock)_$($prevItem.attacker)" += 1
      } elseif ($prevItem.kind -ne 'self') { $arrFlagThrow.$player  += 1; $arrFlagThrowMin.$keyTime += 1 }
    }

    'pickup' {
      $arrTimeTrack.flagTook   = $time
      $arrTimeTrack.flagPlayer = $player
      $arrFlagTook.$player     += 1
      $arrFlagTookMin.$keyTime += 1
    }

    'teamScores' {
      # For the final team score message
      $arrResult.team1Score  = $item.team1Score
      $arrResult.team2Score  = $item.team2Score
      $arrResult.winningTeam = $item.winningTeam
      $arrResult.time        = $time

      
      switch ($arrResult.winningTeam) {
        '0'     { $arrResult.winRating = 0;                                                          $arrResult.winRatingDesc = 'Nobody wins' }
        '1'     { $arrResult.winRating = 1 - ($arrResult.team2Score / $arrResult.team1Score);        $arrResult.winRatingDesc = "Wins by $($item.team1Score - $item.team2Score) points" }
        default { $arrResult.winRating = (($round1EndTime * 2) - $arrResult.time ) / $round1EndTime; $arrResult.winRatingDesc = "$("{0:m\:ss}" -f ([timespan]::fromseconds(($round1EndTime * 2) - $arrResult.time))) mins left" }
      }
    }
  } #end type switch
  $prevItem = $item
}#end for


#Close the arrTimeTrack flag + class stats a
$arrTimeTrack.flagPlayer = ''
$arrTimeTrack.flagTook    = 0

foreach ($p in $arrTeam.Keys) {
  $lastClass = $arrTimeTrack."$($p)_lastClass"
  $key       = "$($p)_$($lastClass)"

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

#cleanup class times less that 15 seconds
$arrTimeClass     = timeClassCleanup $arrTimeClass
$arrTimeClassRnd1 = timeClassCleanup $arrTimeClassRnd1
$arrTimeClassRnd2 = timeClassCleanup $arrTimeClassRnd2



######
#Create Ordered Player List 
#####
$playerList  = ($arrTeam.GetEnumerator()| Sort-Object -Property Value,Name).Key

###
# Calculate awards
##

#create variables here, min/max values to be generated for awardAtt* + awardDef* (exclude *versus)
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
    [math]::Floor($args[0] * (1 / (1 - $arrResult.WinRating)))
  } else { $args[0] }
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
$script:playerListAttRnd1 = ($arrTeamRnd1.Keys | foreach { if ($arrTeamRnd1.$_ -match '^(1|1&2)$' -and (GetArrTimeTotal 1 $_) -gt $round1EndTime - 60) { $_ } })
$script:playerListAttRnd2 = ($arrTeamRnd2.Keys | foreach { if ($arrTeamRnd2.$_ -match '^(2|2&1)$' -and (GetArrTimeTotal 2 $_) -gt (awardScaler 2 ($round1EndTime - 60))) { $_ } })

$playerListAttRnd2

## Generate Attack/Def Tables, e.g. for att Rnd1 = Team1 attack + Rnd2 = Team2 attack
$count = 1

foreach ($array in @($playerListAttRnd1, $playerListAttRnd2)) {
  foreach ($p in $array) {
    if ($arrResult.WinningTeam -eq 2) {
      $scaler = 1 / $arrResult.winRating
    } else { $scaler = 1 }
    
    $awardAttFlagCap.Add( $p, $arrFlagCap.$p)
    $awardAttFlagTook.Add($p,$arrFlagTook.$p)
    $awardAttFlagTime.Add($p, $arrTimeFlag.$p)
   
    if ($count -eq 1) {
      $awardAttKills.Add($p, $arrFragTotalRnd1.$p)
      $awardAttDeath.Add($p, $arrDeathRnd1.$p )
      $awardAttDmg.Add(  $p, $arrDmgTotalRnd1.$p )
      $awardAttDmgTaken.Add($p, $arrDmgTakenRnd1.$p)
      $awardAttDmgTeam.Add(  $p, $arrDmgTeamRnd1.$p)
      $awardAttTkill.Add($p, $arrTKillRnd1.$p)
      $awardAttKD.Add(   $p, ($arrFragTotalRnd1.$p - $arrDeathRnd1.$p))

      if ($arrFragTotalRnd1.$p -notin $null,'','0') { $awardAttDmgPerKill.Add($p, [math]::Round($arrDmgTotalRnd1.$p / $arrFragTotalRnd1.$p,1) ) }
    } else {
      $awardAttKills.Add($p, (awardScaler $arrFragTotalRnd2.$p ))
      $awardAttDeath.Add($p, (awardScaler $arrDeathRnd2.$p))
      $awardAttDmg.Add(  $p, (awardScaler $arrDmgTotalRnd2.$p))
      $awardAttDmgTaken.Add(  $p, (awardScaler $arrDmgTakenRnd2.$p))
      $awardAttDmgTeam.Add(  $p, (awardScaler $arrDmgTeamRnd2.$p))
      $awardAttTkill.Add($p, (awardScaler $arrTKillRnd2.$p))

      $awardAttKD.Add(   $p, (awardScaler ($arrFragTotalRnd2.$p - $arrDeathRnd2.$p)))
  
      if ($arrFragTotalRnd2.$p -notin $null,'','0') { $awardAttDmgPerKill.Add($p, [math]::Round($arrDmgTotalRnd2.$p / $arrFragTotalRnd2.$p,1)) }
    }
  }
  $count += 1
}


#defence - Rnd2=T2 and Rnd2=T1 - Get Player list and get required Data sets
## Generate Attack/Def Tables, e.g. for att Rnd1 = Team2 def + Rnd2 = Team1 def
$script:playerListDefRnd1 = ($arrTeamRnd1.Keys | foreach { if ($arrTeamRnd1.$_ -match '^2$' -and (GetArrTimeTotal 1 $_) -gt $round1EndTime - 60) { $_ } })
$script:playerListDefRnd2 = ($arrTeamRnd2.Keys | foreach { if ($arrTeamRnd2.$_ -match '^1$' -and (GetArrTimeTotal 2 $_) -gt (awardScaler 2 ($round1EndTime - 60))) { $_ } })

$count = 1
foreach ($array in @($playerListDefRnd1, $playerListDefRnd2)) {
  foreach ($p in $array) {
    if ($count -eq 1) {
      $awardDefKills.Add($p, [int]$arrFragTotalRnd1.$p)
      $awardDefDeath.Add($p, [int]$arrDeathRnd1.$p)
      $awardDefDmg.Add(  $p, [int]$arrDmgTotalRnd1.$p)
      $awardDefDmgTaken.Add(  $p, [int]$arrDmgTakenRnd1.$p)
      $awardDefDmgTeam.Add(  $p, [int]$arrDmgTeamRnd1.$p)
      $awardDefTkill.Add($p, [int]$arrTKillRnd1.$p)
      $awardDefKD.Add(   $p, [int]$arrFragTotalRnd1.$p - [int]$arrDeathRnd1.$p)
      
      if ($arrFragTotalRnd1.$p -notin $null,'','0') { $awardDefDmgPerKill.Add($p, [math]::Round($arrDmgTotalRnd1.$p / $arrFragTotalRnd1.$p,1)) }
    } else {
      $awardDefKills.Add($p, [int](awardScaler $arrFragTotalRnd2.$p))
      $awardDefDeath.Add($p, [int](awardScaler $arrDeathRnd2.$p))
      $awardDefDmg.Add(  $p, [int](awardScaler $arrDmgTotalRnd2.$p))
      $awardDefDmgTaken.Add(  $p, [int](awardScaler $arrDmgTakenRnd2.$p))
      $awardDefDmgTeam.Add(  $p, [int](awardScaler $arrDmgTeamRnd2.$p))
      $awardDefTkill.Add($p, [int](awardScaler $arrTKillRnd2.$p))
      $awardDefKD.Add(   $p, [int](awardScaler ($arrFragTotalRnd2.$p - [int]$arrDeathRnd2.$p)))
  
      if ($arrFragTotalRnd2.$p -notin $null,'','0') { $awardDefDmgPerKill.Add($p, [math]::Round($arrDmgTotalRnd2.$p / $arrFragTotalRnd2.$p,1)) }
    }

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

<#
$script:awardDefDmgAll = @{}
$awardDefDmgAll = (awardTallyTables $awardDefDmg $awardDefDmgTaken)
foreach ($item in $awardDefDmgAll.key) { 
  $awardDefDmgAll.$item = $awardDefDmgAll.$item / $awardDefDeath.$item
}
#>

<# old magoo based on rank... changed to % above average
$tkRank = ($awardDefTKill.GetEnumerator() | Sort -Property Value)
$tdRank = ($awardDefDmgTeam.GetEnumerator() | Sort -Property Value)

$awardDefMagoo = @{}
$score = 0 # score is count of pst
$count = 1 # keep track of playeer pos
foreach ($p in $tkRank.Key) {
  if ($tkMax -ne $awardDefTkill.$p -or $tkMax -eq '') {
    $tkMax = $awardDefTKill.$p
    $score = $count
  }
  $awardDefMagoo.$p += $score
  $prevScore = $awardDefMagoo.$p
  $count += 1
}

$score = 0 # score is count of pst
$count = 1 # keep track of playeer pos
foreach ($p in $tdRank.Key) {
  $adjDMG = [Math]::Round($awardDefDmgTeam.$p / 100) * 100
  if ($tdMax -ne $adjDMG -or $tdMax -eq '') {
    $tdMax = $adjDMG
    $score = $count
  }
  $awardDefMagoo.$p += $score
  $prevScore = $awardDefMagoo.$p
  $count += 1
}
Remove-Variable adjDMG,prevScore,tdMax,tkMax,score
#>


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
    if ($name -in $plRnd1) { $htOut.$name += $arrKilledClassRnd1.$item }
  }
  foreach ($item in $arrKilledClassRnd2.Keys -match $args[1]) { 
    $name = $($item -split '_')[0]

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
foreach ($v in (Get-Variable 'award*' -Exclude '*_*')) {
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
 $awardsHtml += "<tr><td colspan=3 align=right><i>*Team2 scaled: Only $('{0:p0}' -f [math]::Round((1 - $arrResult.winRating),2)) of Rnd2 played</i></td></tr>"
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
<tr><td>Mr Magoo</td>            <td align=center width=150px>$($awardDefMagoo_MaxName)</td>      <td>Team Kill/Damage above avg ($('{0:p0}' -f $awardDefMagoo_Max))</td></tr>"

if ($arrResult.winningTeam -eq 2) {
  $awardsHtml += "<tr><td colspan=3 align=right><i>*Team1 scaled: Only $('{0:p0}' -f [math]::Round((1 - $arrResult.winRating),2)) of Rnd2 played</i></td></tr>"
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
    <h1>$($inputFile.Name)</h1>"


$htmlOut += "<table cellpadding=`"3`">
<tr><th>Result</th><th>Scores</th><th>Win Rating</th></tr>
<tr><td bgcolor=`"$(teamColorCode $arrResult.winningTeam)`">"  

switch ($arrResult.winningTeam) {
  '0'     { $htmlOut += "DRAW! "                                  }
  default { $htmlOut += "TEAM $($arrResult.winningTeam) WINS! "   }
}

$htmlOut += "</td><td>Team1: $($arrResult.team1Score) vs Team2: $($arrResult.team2Score)</td><td>$('{0:p0}' -f $arrResult.winRating) ($($arrResult.winRatingDesc))</td></tr></table>"  

#### awards
$htmlOut += "<hr><h2>Awards</h2>"
$htmlOut += $awardsHtml



#Frag Total Table
$htmlOut += "<hr><h2>TOTAL - Frags and Damage</h2>"  

$count = 1
$tableHeader = "<table style=`"width:600px;display:inline-table`"><tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Kills</th><th $($columStyle)>Dth</th><th $($columStyle)>TK</h>"
$table = ''
$subtotal = @($playerList | foreach { 0 } )

foreach ($p in $playerList) {
  $tableHeader += "<th $($columStyle)>$($count)</th>"

  $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($arrFragTotal.$p)</td><td>$($arrDeath.$p)</td><td>$($arrTKill.$p)</td>"
  
  $count2  = 0
  foreach ($o in $playerList) {
    $key = "$($p)_$($o)"
    $kills = $arrFragVersus.$key
    if ($kills -eq '' -or $kills -lt 1) { $kills = 0 }

    $table += "<td bgcolor=`"$(actionColorCode $arrTeam $p $o)`">$($kills)</td>"
    
    $subtotal[$count2] = $kills + $subtotal[$count2]
    $count2 += 1
  }

  $table += "<td>$(getPlayerClasses $arrTimeClass.Keys $p)</td>"
  $table += "</tr>`n"
  
  $count += 1 
}

$tableHeader += "<th>Classes</th></tr>"
$tableHeader += "</tr>"

$table += '<tr><td colspan=6 align=right padding=2px><b>Total:</b></td>'
foreach ($st in $subtotal) { $table += "<td>$($st)</td>" }
$table += '</tr>'

$htmlOut += $tableHeader      
$htmlOut += $table            
$htmlOut += "</table>"        

#Damage Table - side by side with frags
#"<h2>Damage</h2>"  
$tableHeader = "<table style=""width:700px;display:inline-table""><tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Dmg</th>"

$count = 1
$table = ''
$subtotal = @($playerList | foreach { 0 } )

foreach ($p in $playerList) {
  $tableHeader += "<th $($columStyle)>$($count)</th>"
  $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($arrDmgTotal.$p)</td>"

  $count2 = 0
  foreach ($o in $playerList) {
    $key = "$($p)_$($o)"
    $dmg = $arrDmgVersus.$key
    if ($dmg -eq '' -or $dmg -lt 1) { $dmg = 0 }

    $table += "<td bgcolor=`"$(actionColorCode $arrTeam $p $o)`">$($dmg)</td>"
    
    #don't count self dmg
    if ($p -ne $o) { $subtotal[$count2] = $dmg + $subtotal[$count2] }
    $count2 += 1
  }

  $table += "<td>$(getPlayerClasses $arrTimeClass.Keys $p)</td>"
  $table += "</tr>`n"
  
  $count += 1 
}

$tableHeader += "<th>Classes</th></tr>"
$tableHeader += "</tr>"

$table += '<tr><td colspan=4 align=right padding=2px><b>Total:</b><i> *minus self-dmg</i></td>'
foreach ($st in $subtotal) { $table += "<td>$($st)</td>" }


$htmlOut += $tableHeader   
$htmlOut += $table         
$htmlOut += "</table>"     

#Frag Rnd1 v Rnd2  Table
$htmlOut += "<hr><h2>Frags - Round 1 and Round 2</h2>"  

$count = 1
$tableHeader = "<table style=""width:600px;display:inline-table"">$($tableStyle2)<tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Kills</th><th $($columStyle)>Dth</th><th $($columStyle)>TK</h>"
$table = ''
$subtotal = @($playerList | foreach { 0 } )

foreach ($p in $playerList) {
  $tableHeader += "<th $($columStyle)>$($count)</th>"
  $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeamRnd1.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeamRnd1.$p)</td><td>$($arrFragTotalRnd1.$p)</td><td>$($arrDeathRnd1.$p)</td><td>$($arrTKillRnd1.$p)</td>"
  
  $count2 = 0
  foreach ($o in $playerList) {
    $key = "$($p)_$($o)"
    $kills = $arrFragVersusRnd1.$key
    if ($kills -eq '' -or $kills -lt 1) { $kills = 0 }

    $table += "<td bgcolor=`"$(actionColorCode $arrTeamRnd1 $p $o)`">$($kills)</td>"

    $subtotal[$count2] = $kills + $subtotal[$count2]
    $count2 +=1
  }

  $table += "<td>$(getPlayerClasses $arrTimeClassRnd1.Keys $p)</td>"
  $table += "</tr>`n"
  
  $count += 1 
}

$tableHeader += "<th>Classes</th></tr>"
$tableHeader += "</tr>"

$table += '<tr><td colspan=6 align=right padding=2px><b>Total:</b></td>'
foreach ($st in $subtotal) { $table += "<td>$($st)</td>" }

$htmlOut += $tableHeader      
$htmlOut += $table            
$htmlOut += "</table>"        

#Frag Rnd2  Table
#"<h2>Frags - Round 2</h2>"  

$count = 1
$tableHeader = "<table style=""width:600px;display:inline-table"">$($tableStyle2)<tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Kills</th><th $($columStyle)>Dth</th><th $($columStyle)>TK</h>"
$table = ''
$subtotal = @($playerList | foreach { 0 } )

foreach ($p in $playerList) {
  $tableHeader += "<th $($columStyle)>$($count)</th>"
  $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeamRnd2.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeamRnd2.$p)</td><td>$($arrFragTotalRnd2.$p)</td><td>$($arrDeathRnd2.$p)</td><td>$($arrTKillRnd2.$p)</td>"
  
  $count2 = 0
  foreach ($o in $playerList) {
    $key = "$($p)_$($o)"
    $kills = $arrFragVersusRnd2.$key
    if ($kills -eq '' -or $kills -lt 1) { $kills = 0 }

    $table += "<td bgcolor=`"$(actionColorCode $arrTeamRnd2 $p $o)`">$($kills)</td>"

    $subtotal[$count2] = $kills + $subtotal[$count2]
    $count2 +=1
  }

  $table += "<td>$(getPlayerClasses $arrTimeClassRnd2.Keys $p)</td>"
  $table += "</tr>`n"
  
  $count += 1 
}

$tableHeader += "<th>Classes</th></tr>"
$tableHeader += "</tr>"

$table += '<tr><td colspan=6 align=right padding=2px><b>Total:</b></td>'
foreach ($st in $subtotal) { $table += "<td>$($st)</td>" }

$htmlOut += $tableHeader      
$htmlOut += $table            
$htmlOut += "</table>"        



#Damage by Round Table
$htmlOut += "<hr><h2>Damage - Round 1 and Round 2</h2>"  

$count = 1
$tableHeader = "<table style=""width:700px;display:inline-table""><tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Dmg</th>"
$table = ''
$subtotal = @($playerList | foreach { 0 } )

foreach ($p in $playerList) {
  $tableHeader += "<th $($columStyle)>$($count)</th>"
  $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeamRnd1.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeamRnd1.$p)</td><td>$($arrDmgTotalRnd1.$p)</td>"

  $count2 = 0
  foreach ($o in $playerList) {
    $key = "$($p)_$($o)"
    $dmg = $arrDmgVersusRnd1.$key
    if ($dmg -eq '' -or $dmg -lt 1) { $dmg = 0 }

    $table += "<td bgcolor=`"$(actionColorCode $arrTeamRnd1 $p $o)`">$($dmg)</td>"

    #don't count self dmg
    if ($p -ne $o) { $subtotal[$count2] = $dmg + $subtotal[$count2] }
    $count2 +=1
  }

  $table += "<td>$(getPlayerClasses $arrTimeClassRnd1.Keys $p)</td>"
  $table += "</tr>`n"
  
  $count += 1 
}

$tableHeader += "<th>Classes</th></tr>"
$tableHeader += "</tr>"

$table += '<tr><td colspan=4 align=right padding=2px><b>Total:</b><i> *minus self-dmg</i></td>'
foreach ($st in $subtotal) { $table += "<td>$($st)</td>" }

$htmlOut += $tableHeader   
$htmlOut += $table         
$htmlOut += "</table>"     

$count = 1
$tableHeader = "<table style=""width:700px;display:inline-table""><tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Dmg</th>"
$table = ''
$subtotal = @($playerList | foreach { 0 } )


foreach ($p in $playerList) {
  $tableHeader += "<th $($columStyle)>$($count)</th>"
  $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeamRnd2.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeamRnd2.$p)</td><td>$($arrDmgTotalRnd2.$p)</td>"

  $count2 = 0
  foreach ($o in $playerList) {
    $key = "$($p)_$($o)"
    $dmg = $arrDmgVersusRnd2.$key
    if ($dmg -eq '' -or $dmg -lt 1) { $dmg = 0 }

    $table += "<td bgcolor=`"$(actionColorCode $arrTeamRnd2 $p $o)`">$($dmg)</td>"

    #don't count self dmg
    if ($p -ne $o) { $subtotal[$count2] = $dmg + $subtotal[$count2] }
    $count2 +=1
  }

  $table += "<td>$(getPlayerClasses $arrTimeClassRnd2.Keys $p)</td>"
  $table += "</tr>`n"
  
  $count += 1 
}

$tableHeader += "<th>Classes</th></tr>"
$tableHeader += "</tr>"

$table += '<tr><td colspan=4 align=right padding=2px><b>Total:</b><i> *minus self-dmg</i></td>'
foreach ($st in $subtotal) { $table += "<td>$($st)</td>" }

$htmlOut += $tableHeader   
$htmlOut += $table         
$htmlOut += "</table>"     

###
# frag/death per mins
###

$htmlOut += "<hr><h2>Per Minute - Frags/Deaths</h2>"  

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
$tableHeader += "</tr>"

$count = 1
$subtotalFrg = @(1..$timeBlock | foreach { 0 } )
$subtotalDth = @(1..$timeBlock | foreach { 0 } )

foreach ($p in $playerList) {
  $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($arrFragTotal.$p)</td><td>$($arrDeath.$p)</td><td>$($arrTKill.$p)</td>"
  
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
        $table += "<td>$([int]$arrFragTotalRnd1.$p)/$([int]$arrDeathRnd1.$p)</td>"
      } else {
        $table += "<td>$([int]$arrFragTotalRnd2.$p)/$([int]$arrDeathRnd2.$p)</td>"
      }
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
$table += "</tr>"

$htmlOut += $tableHeader      
$htmlOut += $table            
$htmlOut += "</table>"        

###
# Damage per mins
###
$htmlOut += "<hr><h2>Per Minute - Damage <i>(excluding friendly-fire)</i></h2>"  
#$tableHeader = "<table style=""width:30%;display:inline-table"">$($tableStyle2)<tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Kills</th><th $($columStyle)>Dth</th><th $($columStyle)>TK</h>"
#resue the previous table header.

$table = ''
$subtotalDmg = @(1..$timeBlock | foreach { 0 } )
$count = 1

$tableHeader = $tableHeader -replace '>Kills<','>Dmg<'

foreach ($p in $playerList) {
  $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($arrDmgTotal.$p)</td><td>$($arrDeath.$p)</td><td>$($arrTKill.$p)</td>"
  
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
        $table += "<td>$($arrDmgTotalRnd1.$p)</td>"
      } else {
        $table += "<td>$($arrDmgTotalRnd2.$p)</td>"
      }
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
$table += "</tr>"

$htmlOut += $tableHeader      
$htmlOut += $table            
$htmlOut += "</table>"        


###
# Flag Cap/Took/Drop per min
###

$htmlOut += "<hr><h2>Per Minute - Flag stats</h2>"  

$tableHeader = "<table style=""width:30%;display:inline-table"">$($tableStyle2)
<tr><th colspan=8></ht><th colspan=$([math]::Ceiling($round1EndTime / 60))>Rnd1 <i>(Cp/Tk/Thr or Stop)</i></ht><th colspan=$($timeBlock - $([math]::Ceiling($round1EndTime / 60)))>Rnd2 <i>(Cp/Tk/Thr or Stop)</i></th></tr>
<tr><th $($columStyle)>#</th><th $($columStyle)>Player</th><th $($columStyle)>Team</th><th $($columStyle)>Caps</th><th $($columStyle)>Took</th><th $($columStyle)>Throw</h><th $($columStyle)>Time</h><th $($columStyle)>Stop</h>"
$table = ''

foreach ($min in 1..$timeBlock) { $tableHeader += "<th $($columStyle)>$($min)</th>" }
$tableHeader += "</tr>"

$count = 1
$subtotalCap   = @(1..$timeBlock | foreach { 0 } )
$subtotalTook  = @(1..$timeBlock | foreach { 0 } )
$subtotalThrow = @(1..$timeBlock | foreach { 0 } )

foreach ($p in $playerList) {
  $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($arrFlagCap.$p)</td><td>$($arrFlagTook.$p)</td><td>$($arrFlagThrow.$p)</td><td>$("{0:m\:ss}" -f [timespan]::FromSeconds($arrTimeFlag.$p))</td><td>$($arrFlagStop.$p)</td>"
  
  $count2 = 0
  foreach ($min in 1..$timeBlock) {
    $key = "$($min)_$($p)"
    $cap    = $arrFlagCapMin.$key
    #$took   = $arrFlagTookMin.$key
    $Took   = $arrFlagTookMin.$key
    $Throw  = $arrFlagThrowMin.$key
    $Stop   = $arrFlagStopMin.$key

    if ($cap -in '',$null -and $took -in '',$null) { 
      if ($Stop -notin '',$null) {
        $value = $arrFlagStopMin.$key
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
$table += "</tr>"

$htmlOut += $tableHeader      
$htmlOut += $table
$htmlOut += "</table>"        

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
<th $($columStyle)>SG</th></tr>"

$table = ''
$subtotalFrg = @($ClassAllowedwithSG | foreach { 0 }) 
$subtotalDth = @($ClassAllowedwithSG | foreach { 0 }) 

foreach ($p in $playerList) { 
  $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($arrFragTotal.$p)</td>"

  $count2 = 0
  foreach ($o in ($ClassAllowedwithSG)) {
    $key = "$($p)_$($o)"
    $kills = $arrFragClass.$key
    $dth   = $arrDeathClass.$key

    if ($kills -eq '' -or $kills -lt 1) { $kills = 0 }
    if ($dth -eq ''   -or $dth   -lt 1) { $dth   = 0 }

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
$htmlOut += '<h2>Kills/Deaths By Class</h2>'    
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
  
  if ($arrDeathRnd1.$p -in $null,'') { $kd = 'n/a' }
  else { $kd = [math]::Round($arrFragTotalRnd1.$p/$arrDeathRnd1.$p,2) }
 
  $table +=  "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td><td>$($kd)</td>"
 
  $count2 = 1
  foreach ($o in $classAllowed) {
    $key = "$($p)_$($o)"
   
    if ($arrTimeClassRnd1.$key -in '',$null -or $kd -eq 'n/a') { $time = '' }
    else { $time = "{0:m\:ss}" -f [timespan]::FromSeconds($arrTimeClassRnd1.$key) }

    if ($time) { $table += "<td>$($time)</td>" }
    else       { $table += "<td bgcolor=`"#F1F1F1`"></td>" }
    $count2 +=1
  }

  if ($arrDeathRnd2.$p -in $null,'') { $kd = 'n/a' }
  else { $kd = [math]::Round($arrFragTotalRnd2.$p/$arrDeathRnd2.$p,2) }
  $table += "<td>$($kd)</td>"

  $count2 = 1
  foreach ($o in $classAllowed) {
    $key = "$($p)_$($o)"
    #$time = [math]::Round($arrTimeClass.$key / 60,1)
    
    if ($arrTimeClassRnd2.$key -in '',$null -or $kd -eq 'n/a') { $time = '' }
    else { $time = "{0:m\:ss}" -f [timespan]::FromSeconds($arrTimeClassRnd2.$key) }

    if ($time) { $table += "<td>$($time)</td>" }
    else       { $table += "<td bgcolor=`"#F1F1F1`"></td>" }
    $count2 +=1
  }

  $table += "</tr>`n"
  $count += 1 
}

   
#'<div class="column">'                
$htmlOut += '<h2>Estimated Time per Class</h2>'   
$htmlOut += $tableHeader                          
$htmlOut += $table                                
$htmlOut += '</table>'          
$htmlOut += '</div></div>'          

#Stats for each player
$htmlOut += "<hr><h2>Player Weapon Stats </h2>"   

$count = 1
$table = ''
$tableHeader =  '<table><tr><th colspan="2"></th><th colspan="4">Rnd1</th><th colspan="4">Rnd2</th><th colspan="4">Total</th></tr>'
$tableHeader += "<tr><th $($columStyle)>Weapon</th><th>Class</th><th $($columStyle)>Kills</th><th $($columStyle)>Dmg</th><th $($columStyle)>Dth</th><th $($columStyle)>DmgT</th><th $($columStyle)>Kills</th><th $($columStyle)>Dmg</th><th $($columStyle)>Dth</th><th $($columStyle)>DmgT</th><th $($columStyle)>Kills</th><th $($columStyle)>Dmg</th><th $($columStyle)>Dth</th><th $($columStyle)>DmgT</th></tr>"


$allFragDeathKeys = @()
$allFragDeathKeys =  $arrWeapFrag.Keys
$allFragDeathKeys += $arrWeapDeath.Keys
$allFragDeathKeys += $arrWeapDmgTaken.Keys

$allWeapKeys = @()
foreach ($w in $allFragDeathKeys) {
  $weap = $w -split '_'
  $weap = "$($weap[1])_$($weap[2])"

  if ($weap -ne '' -and $weap -notin $allWeapKeys) { $allWeapKeys += $weap }
}

$tmp  = @()
$tmp   = $allWeapKeys -notmatch '(_suicide|-ff$)' -match '^[1-9]_.*$'| Sort
$tmp  += $allWeapKeys -notmatch '(_suicide|-ff$)' -match '^10_.*$'| Sort
#$tmp  += '10_sentdmg' not working
$tmp  += $allWeapKeys -notmatch '(_suicide|-ff$)' -match '^0_.*$'| Sort
$tmp  += $allWeapKeys -match '_suicide$' | Sort
$tmp  += $allWeapKeys -match '-ff$' | Sort
$allWeapKeys = $tmp
Remove-Variable tmp

$divCol = 1
$htmlOut += '<div class="row">' 
$htmlOut += '<div class="column" style="width:600;display:inline-table">' 
$htmlOut += '<h3>Team 1</h3>' 

foreach ($p in $playerList) { 
  #$table +=  "<tr><td>$($count)</td><td>$($p)</td><td>$($arrTeam.$p)</td>"
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
  $foundFF = 0

  foreach ($w in $allWeapKeys) {
    $key      = "$($p)_$($w)"

    if ($arrWeapFrag.$key -gt 0 -or $arrWeapDeath.$key -gt 0 -or $arrWeapDmg.$key -gt 0 -or $arrWeapDmgTaken.$key -gt 0) {    
      $arrSplit = ($w -split '_')
      #if ($arrSplit[0] -eq 10) { $class = $ClassToStr[9] }
      #else { $class    = $ClassToStr[$arrSplit[0]] }
	  $class    = $ClassToStr[$arrSplit[0]]

      if ($class -ne $lastClass -and $foundFF -lt 1) {        
        if ($lastClass -ne '') {
          #Do subtotal and reset total counter
          $totKill  = $totKill  | foreach { if ($_ -eq 0) { '' } else { $_ } }
          $totDmg   = $totDmg   | foreach { if ($_ -eq 0) { '' } else { $_ } }
          $totDth   = $totDth   | foreach { if ($_ -eq 0) { '' } else { $_ } }
		  $totDmgTk = $totDmgTk | foreach { if ($_ -eq 0) { '' } else { $_ } }
          $playerStats += "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td colspan=2 align=right><b>$($lastClass) Totals:</b></td><td>$($totKill[0])</td><td>$($totDmg[0])</td><td>$($totDth[0])</td><td>$($totDmgTk[0])</td><td>$($totKill[1])</td><td>$($totDmg[1])</td><td>$($totDth[1])</td><td>$($totDmgTk[1])</td><td>$($totKill[2])</td><td>$($totDmg[2])</td><td>$($totDth[2])</td><td>$($totDmgTk[2])</td>"
        }
        
        if ($w -match '-ff$' -or $w -match '_suicide$') { $foundFF++ }

        $lastClass = $class
        $totKill = @(0,0,0)
        $totDmg  = @(0,0,0)
        $totDth  = @(0,0,0)
		$totDmgTk = @(0,0,0)
      }

      $totKill[0] += $arrWeapFragRnd1.$key;  $totKill[1] += $arrWeapFragRnd2.$key;  $totKill[2] += $arrWeapFrag.$key;
      $totDmg[0]  += $arrWeapDmgRnd1.$key;   $totDmg[1]  += $arrWeapDmgRnd2.$key;   $totDmg[2]  += $arrWeapDmg.$key;  
      $totDth[0]  += $arrWeapDeathRnd1.$key; $totDth[1]  += $arrWeapDeathRnd2.$key; $totDth[2]  += $arrWeapDeath.$key;
	  $totDmgTk[0]  += $arrWeapDmgTakenRnd1.$key; $totDmgTk[1]  += $arrWeapDmgTakenRnd2.$key; $totDmgTk[2]  += $arrWeapDmgTaken.$key;
      
      if ($arrSplit[1] -eq 'suicide' -or $w -match '.*-ff$') {
        $ccNormOrSuicide = $ccAmber
      } else {
        $ccNormOrSuicide = $ccOrange
      }

      $playerStats += "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td>$($arrSplit[1])</td><td>$($class)</td>
                         <td bgcolor=`"$(nullValueColorCode $arrWeapFragRnd1.$key $ccGreen)`">$($arrWeapFragRnd1.$key)</td><td bgcolor=`"$(nullValueColorCode $arrWeapDmgRnd1.$key $ccGreen)`">$($arrWeapDmgRnd1.$key)</td><td bgcolor=`"$(nullValueColorCode $arrWeapDeathRnd1.$key $ccNormOrSuicide)`">$($arrWeapDeathRnd1.$key)</td><td bgcolor=`"$(nullValueColorCode $arrWeapDmgTakenRnd1.$key $ccNormOrSuicide)`">$($arrWeapDmgTakenRnd1.$key)</td>
                         <td bgcolor=`"$(nullValueColorCode $arrWeapFragRnd2.$key $ccGreen)`">$($arrWeapFragRnd2.$key)</td><td bgcolor=`"$(nullValueColorCode $arrWeapDmgRnd2.$key $ccGreen)`">$($arrWeapDmgRnd2.$key)</td><td bgcolor=`"$(nullValueColorCode $arrWeapDeathRnd2.$key $ccNormOrSuicide)`">$($arrWeapDeathRnd2.$key)</td><td bgcolor=`"$(nullValueColorCode $arrWeapDmgTakenRnd2.$key $ccNormOrSuicide)`">$($arrWeapDmgTakenRnd2.$key)</td>
                         <td bgcolor=`"$(nullValueColorCode $arrWeapFrag.$key $ccGreen)`"    >$($arrWeapFrag.$key)</td>    <td bgcolor=`"$(nullValueColorCode $arrWeapDmg.$key $ccGreen)`"    >$($arrWeapDmg.$key)</td>    <td bgcolor=`"$(nullValueColorCode $arrWeapDeath.$key $ccNormOrSuicide)`">$($arrWeapDeath.$key)</td><td bgcolor=`"$(nullValueColorCode $arrWeapDmgTaken.$key $ccNormOrSuicide)`"    >$($arrWeapDmgTaken.$key)</td></tr>"
    }
  }

  # Do the last total - Do I bother fixing same code in the loop?
  $totKill = $totKill | foreach { if ($_ -eq 0) { '' } else { $_ } }
  $totDmg  = $totDmg  | foreach { if ($_ -eq 0) { '' } else { $_ } }
  $totDth  = $totDth  | foreach { if ($_ -eq 0) { '' } else { $_ } }
  if ($foundFF) { $lastClass = 'Friendly' }
  $playerStats += "<tr bgcolor=`"$(teamColorCode $arrTeam.$p)`"><td colspan=2 align=right><b>$($lastClass) Totals:</b></td><td>$($totKill[0])</td><td>$($totDmg[0])</td><td>$($totDth[0])</td><td>$($totDmgTk[0])</td><td>$($totKill[1])</td><td>$($totDmg[1])</td><td>$($totDth[1])</td><td>$($totDmgTk[1])</td><td>$($totKill[2])</td><td>$($totDmg[2])</td><td>$($totDth[2])</td><td>$($totDmgTk[0])</td>"

  $htmlOut += $tableHeader       
  $htmlOut += $playerStats       
  $htmlOut += "</table>"         


  $count += 1 
}

$htmlOut += '</div></div>' 
$htmlOut += "</body></html>"     

$htmlOut | Out-File -FilePath $outFileStr

& $outFileStr
