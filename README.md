# fo-stats

This takes the json stats object and converts it to a html file. Made by haze.

```
PS  COMMAND LINE:- & .\script.ps1 'x:\path\filename.json' [<Rnd1 End Time/Seconds>]
WIN COMMAND LINE:- powershell -Command "& .\script.ps1" "x:\path\filename.json" [<Rnd1 End Time/Seconds>]
PS  *.JSON:- foreach ($f in (gci 'H:\stats\*.json')) { & .\FO_stats_v1.ps1 ($f.ToString() -replace '\[','`[' -replace '\]','`]') }
```
