$backupDir = New-Item ".\.backup_$('{0:yyyy-MM-dd-hh-mm-ss}' -f (Get-Date))" -ItemType Directory

foreach ($f in @('FO_stats_v2.ps1','FO_stats_join-json.ps1','_FoDownloader.ps1','.fo_stats.css')) {

Copy-Item $f $backupDir
(Invoke-WebRequest https://raw.githubusercontent.com/haze-au/fo-stats/main/$f -Headers @{"Cache-Control"="no-cache"}).Content | Out-File $f

}
