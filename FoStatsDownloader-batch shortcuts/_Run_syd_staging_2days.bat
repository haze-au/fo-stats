cd /D %~dp0
powershell -file "%~dp0_FoStatsDownloader.ps1" -LimitDays 2 -FilterPath sydney/staging/
explorer %~dp0
pause
