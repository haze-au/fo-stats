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
  elseif ($Property -eq 'Team') {
    if (!$script:arrPlayerTable[$pos].Team) { $script:arrPlayerTable[$pos].Team = $Value }
    elseif ($Value -notin ($script:arrPlayerTable[$pos].Team -split '&')) {
        $script:arrPlayerTable[$pos].$Property = $script:arrPlayerTable[$pos].Team,$Value -join '&'
    }
  } else            { $script:arrPlayerTable[$pos].$Property  = $Value }
}



$json = (gc 'H:\_stats\211211_LAN\json\2021-12-11_04-23-48_`[turtler`]_blue_vs_red.json' | ConvertFrom-Json )
$round1EndTime = 600

$playerListAtt = $json   | Where Player `
                         | Where { ($_.playerTeam -eq 1 -and $_.time -lt $round1EndTime) -or ($_.playerTeam -eq 2 -and $_.time -ge $round1EndTime) } `
                         | %{ [pscustomobject]@{Player=$_.player; Team=$_.playerTeam} } | Sort Team,Player -Unique
$playerListDef = $json   | Where Player `
                         | Where { ($_.playerTeam -eq 1 -and $_.time -ge $round1EndTime) -or ($_.playerTeam -eq 2 -and $_.time -lt $round1EndTime) } `
                         | %{ [pscustomobject]@{Player=$_.player; Team=$_.playerTeam} } | Sort Team,Player -Unique
$arrPlayerTable = @()

function getRound { if ($args[0] -lt $round1EndTime) { 1 } else { 2 } } 

$json | Where { $_.player -ne '' -and $_.playerTeam } `
      | %{ arrPlayerTable-UpdatePlayer -Name $_.player -Round (getRound $_.time) `
                                        -Property 'Team' -Value $_.playerTeam } 

$json | Where { $_.player -ne '' -and $_.type -eq 'kill' -and $_.kind -eq 'enemy' } `
      | Where { $_.playerClass -ne '0' -and $_.target -ne ''} `
      | %{ arrPlayerTable-UpdatePlayer -Name $_.player -Round (getRound $_.time) `
                                        -Property 'Kills' -Increment } 

$json | Where { $_.player -ne '' -and $_.type -eq 'kill' -and $_.kind -eq 'team' } `
      | Where { $_.playerClass -ne 0 -and $_.target -ne ''} `
      | %{ arrPlayerTable-UpdatePlayer -Name $_.player -Round (getRound $_.time) `
                                        -Property 'TKill' -Increment } 

$json | Where { $_.player -ne '' -and $_.type -eq 'Death' -and $_.kind -eq 'enemy' } `
      | Where { $_.playerClass -ne 0 -and $_.target -ne ''} `
      | %{ arrPlayerTable-UpdatePlayer -Name $_.player -Round (getRound $_.time) `
                                        -Property 'death' -Increment } 

$json | Where { $_.player -ne '' -and $_.type -eq 'damageDone' -and $_.kind -eq 'enemy' } `
      | Where { $_.playerClass -ne 0 -and $_.target -ne ''} `
      | %{ arrPlayerTable-UpdatePlayer -Name $_.player -Round (getRound $_.time) `
                                        -Property 'Dmg' -Value $_.damage -Increment } 
$json | Where { $_.player -ne '' -and $_.type -eq 'damageTaken' -and $_.kind -eq 'enemy' } `
      | Where { $_.playerClass -ne 0 -and $_.target -ne ''} `
      | %{ arrPlayerTable-UpdatePlayer -Name $_.player -Round (getRound $_.time) `
                                        -Property 'DmgTaken' -Value $_.damage -Increment } 
$json | Where { $_.player -ne '' -and $_.type -eq 'damageDone' -and $_.kind -eq 'team' } `
      | Where { $_.playerClass -ne 0 -and $_.target -ne ''} `
      | %{ arrPlayerTable-UpdatePlayer -Name $_.player -Round (getRound $_.time) `
                                        -Property 'DmgTeam' -Value $_.damage -Increment } 
$json | Where { $_.player -ne '' -and $_.type -eq 'goal' } `
      | Where { $_.playerClass -ne 0 } `
      | %{ arrPlayerTable-UpdatePlayer -Name $_.player -Round (getRound $_.time) `
                                        -Property 'FlagCap' -Increment }
$json | Where { $_.player -ne '' -and $_.type -eq 'pickup' } `
      | Where { $_.playerClass -ne 0 } `
      | %{ arrPlayerTable-UpdatePlayer -Name $_.player -Round (getRound $_.time) `
                                        -Property 'FlagTake' -Increment }

$json | Where { $_.player -ne '' -and $_.type -eq 'fumble' } `
      | Where { $_.playerClass -ne 0 } `
      | %{ $prop = 'FlagDrop'; $prev = $json[ ([array]::IndexOf($json, $_) - 1)]
           if ($prev.type -ne 'death' -or $prev.player -ne $_.player) { $prop = 'FlagThrow' }
           arrPlayerTable-UpdatePlayer -Name $_.player -Round (getRound $_.time) `
                                        -Property $prop -Increment 
           if ($prop -eq 'FlagDrop' -and $prev.type -eq 'death' -and $prev.attackerClass -gt 0) { 
               arrPlayerTable-UpdatePlayer -Name $prev.attacker -Round (getRound $_.time) -Property 'FlagStop' -Increment }}

<#$arrPlayerTable = @()
$json | Where { $_.player -eq '' -and $_.type -eq 'damageDone' -and $_.inflictor -eq 'worldspawn' } `
      | Where { $_.time -le ((getRound $_.time) * 600) -or $_.time -ge (((getRound $_.time) * 600) - 600) } `
      | Sort -Unique | %{ $_ } #if ($_.length -eq 1) {  
          arrPlayerTable-UpdatePlayer -Name $_.player -Round (getRound $_.time) -Property 'Dmg' -Increment }}
$arrPlayerTable | FT *#>


function weapSN {
  
  switch ($args[0]) {
    #common
    'info_tfgoal'   { 'laser' }
    'supershotgun'  { 'ssg'   }
    'shotgun'       { 'sg'    }
    'normalgrenade' { 'hgren' }
    'grentimer'     { 'naplm' }
    'axe'           { 'axe'   }
    'spike'         { 'ng'    }
    'nailgun'       { 'ng'    }

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

      

$arrPlayerTable | Sort Round,Team,Name | FT *

