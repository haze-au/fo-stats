cd /D %~dp0
powershell -File "%~dp0_FoDownloader.ps1" -LimitMins 720 -Region OCE
explorer %~dp0
pause




















