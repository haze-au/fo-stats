cd /D %~dp0
powershell -File "%~dp0_FoDownloader.ps1" -LimitMins 720 -Region US -Demos
explorer %~dp0
pause





















