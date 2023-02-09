cd /D %~dp0
powershell -file "%~dp0_FoStatsDownloader.ps1" -LatestFile -FilterPath sydney/staging/
explorer %~dp0
pause