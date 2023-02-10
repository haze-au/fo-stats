cd /D %~dp0
powershell -File "%~dp0_FoDownloader.ps1" -LimitDays 1 -Region ALL -Demos
explorer %~dp0
pause



















