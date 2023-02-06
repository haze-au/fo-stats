$findReplace = @{}
#$files = gci .\2022_T\220531_SF-!\*.json
$files = gci '.\2022_T\_ALL\2022-05-01_10-38-53_`[turtler`]_blue_vs_red.json'


#Hashtable items to replace
$findReplace.'bentski' = 'bent'
$findReplace.'sobrahbent' = 'bent'
$findReplace.'sobrahzel' = 'zel'
$findReplace.'‹sobrah‹zel' = 'zel'
$findReplace.'‡s‡meht' = 'meht'
$findReplace.'sobrahmeht' = 'meht'
$findReplace.'\(1\)spas' = '!spas'
$findReplace.'"spas"' = '"!spas"'
$findReplace.'!hello' = '!pecan'
$findReplace.'‰b‰lagfox' = '‰b‰redfox'
$findReplace.'‡s‡meht' = 'meht'
$findReplace.'seabo' = 'seano'
$findReplace.'"shitpeas"' = '"seano"'
$findReplace.'(1)shitpeas' = 'seano'
$findReplace.'seanpeas' = 'seano'

$findReplace.'"awm"' = '"‰b‰wm"'
$findReplace.'"loddy"' = '"!lordy"'
$findReplace.'"loddy"' = '"!lordy"'

$files
'---'
foreach ($f in $files) {
$fn = $f -replace '\[','`[' -replace '\]','`]'

$txt = gc -Path ($fn) -Raw

foreach ($fr in $findReplace.Keys) {
  $txt = $txt -replace $fr,$findReplace.$fr
}

$txt | Out-File $fn

}







