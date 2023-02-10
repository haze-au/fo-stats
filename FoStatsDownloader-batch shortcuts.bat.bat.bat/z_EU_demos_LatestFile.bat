cd /D %~dp0
powershell -file "%~dp0_FoDownloader.ps1" -LatestFile -Region EU -Demos
explorer %~dp0
pause




















