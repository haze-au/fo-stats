# fo-stats

This takes the json stats object and converts it to a html file. Made by haze.

```
PS  COMMAND LINE:- & .\FO_stats_v2.ps1 -StatFile 'x:\path\filename.json' [-RoundTime <seconds>] [-TextOnly] [-TextSave] [-NoStatJson]
WIN COMMAND LINE:- powershell -Command "& .\FO_stats_v2.ps1 -StatFile 'x:\path\filename.json' [-RountTime <seconds>] [-TextOnly] [-TextSave] [-NoStatJson]"

NOTE: StatFile parameter now accepts *.json wildcard to generate many HTMLs, Text/Json stats are ALL STATS COMBINED.

For individual TextJson Only stats for many stat files - i.e. not all games combined.
PS  *.JSON:- foreach ($f in (gci 'x:\stats\*.json')) { & .\FO_stats_v2.ps1 -StatFile ($f.ToString() -replace '\[','`[' -replace '\]','`]') -TextOnly }
```
