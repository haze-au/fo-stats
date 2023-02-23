$strOut = ''

foreach ($l in (gc '.\2022_T\220213_ZAF-BDE\unedited-swoop\2022-02-13_09-24-50_`[ff-swoop`]_blue_vs_red.json')) {
  
if ($l -match '"playerTeam": ([1-2])') {   $l = $l -replace """playerTeam"": [1-2]","""playerTeam"": $(Switch ($matches[1]) { 1 { '2' }; 2 { '1' } })" }
if ($l -match '"targetTeam": ([1-2])') {   $l = $l -replace """targetTeam"": [1-2]","""targetTeam"": $(Switch ($matches[1]) { 1 { '2' }; 2 { '1' } })" }
if ($l -match '"attackerTeam": ([1-2])') { $l = $l -replace """attackerTeam"": [1-2]","""attackerTeam"": $(Switch ($matches[1]) { 1 { '2' }; 2 { '1' } })" }
if ($l -match '"time": ([0-9]{1,4})') {    $l = $l -replace """time"": $($matches[1])","""time"": $([int]$matches[1] + 600)" }

$strOut += "$l`n"

}


$strOut | Out-File .\new.txt
& .\new.txt