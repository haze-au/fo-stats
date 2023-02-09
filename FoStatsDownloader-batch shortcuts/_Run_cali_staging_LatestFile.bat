cd /D %~dp0
powershell -file "%~dp0_FoStatsDownloader.ps1" -LatestFile -FilterPath california/staging/
explorer %~dp0
pause
