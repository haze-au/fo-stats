cd /D %~dp0
powershell -File "%~dp0_FoStatsDownloader.ps1" -LimitDays 1 -FilterPath california/staging/
explorer %~dp0
pause