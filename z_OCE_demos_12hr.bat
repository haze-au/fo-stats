cd /D %~dp0
powershell -File "%~dp0_FoDownloader.ps1" -LimitDays 0.5 -Region OCE -Demos
explorer %~dp0
pause




















