cd /D %~dp0
powershell -File "%~dp0_FoDownloader.ps1" -LimitDays 1 -Region EU
explorer %~dp0
pause



















