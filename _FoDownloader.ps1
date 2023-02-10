######################################################
# FO Stats Downloader from the FortressOne AWS Bucket
######################################################
# Sample Commands
#-----------------------------------------------------
# 1. US Stats from last 24hrs.
#     & .\_FoDownloader.ps1 -Region US
#
# 2. Euro demos from last 7 days:
#     & .\_FoDownloader.ps1 -Region EU -LimitDays 7 -Demos
#
# 3. Stats from 1x server in last 24hrs.
#     & .\_FoDownloader.ps1 -FilterPath 'sydney/staging/'
#
# 4. Last stat file availabe in ALL regions.
#     & .\_FoDownloader.ps1 -Region ALL -LatestFile
#
# 5. Re-download existing stats from last 2hrs.
#     & .\_FoDownloader.ps1 -Region US -LimitMins 120 -Overwrite
#
# 6. Do not download stats again but run FO Stats again.
#     & .\_FoDownloader.ps1 -Region US -ForceStats
#
# 7. Demos from ALL regions - Staging servers only in last 24hrs.
#     & .\_FoDownloader.ps1 -Region ALL -FilterPath 'staging/' -Demos
#
# 8. Results from in Sydney & Dallas Stagin where map = well6.
#     & .\_FoDownloader.ps1 -FilterPath 'sydney/staging/,dallas/statging/' -FilterFile '*`[well6`]*'
#
# 9. Stats from ALL regions, save to specific folder and save text-based output.
#     & .\_FoDownloader.ps1 -Region ALL -OutFolder 'C:\FoStats' -TextSave
#
######################################################


param (
  #AWS Result limit is 1000 files, so please filter to target your results
  [switch]$Demos,      #Demos instead of stats
  [ValidateSet('ALL','US','EU','OCE','INT')]
          $Region,     # All | US | EU | OCE | Int
  [string]$FilterPath, #Stats folder on repo, replicated locally, default='sydney/staging/' 
  [string]$FilterFile, #Filter the filenames from the XML results, use * for wildcards.
  [string]$OutFolder,  #Path of ouput JSON and HTML
  [switch]$LatestFile, #Last modified file only (from the filtered list)
  [int]   $LimitMins,  #Only access files from last X minutes (sum of days and mins)(sum of days and mins)
  [int]   $LimitDays,  #Only access files from last X days (sum of days and mins)
  [switch]$DownloadOnly,#Download JSON only
  [switch]$Overwrite,  #Force re-download do the FO_stats again even when file exists
  [switch]$ForceStats, #Force running stats on already existing file
  [int]   $RoundTime,  #Passed to FO_Stats
  [switch]$TextSave,   #Passed to FO_Stats
  [switch]$TextOnly,   #Passed to FO_Stats
  [switch]$OpenHTML    #Passed to FO_Stats

)

if ($Demos) { $AwsUrl = 'https://fortressone-demos.s3.amazonaws.com/' }
else        { $AwsUrl = 'https://fortressone-stats.s3.amazonaws.com/' }

$OCEPaths = @('sydney/','sydney-gz/','snoozer/')
$USPaths  = @('california/','coach/','dallas/','dallas2/','iowa/','phoenix/','virginia/')
$EUPaths  = @('dublin/','ireland/','stockholm/')
$IntPaths = @('bahrain/','guam/','mumbai/','nz/','timbuktu/','tokyo/')

if     ($Region -eq 'ALL') { $LatestPaths = $OCEPaths + $USPaths + $EUPaths + $IntPaths }
elseif ($Region -eq 'US')  { $LatestPaths = $USPaths  }
elseif ($Region -eq 'EU')  { $LatestPaths = $EUPaths  }
elseif ($Region -eq 'OCE') { $LatestPaths = $OCEPaths }
elseif ($Region -eq 'INT') { $LatestPaths = $IntPaths }


if (!$OutFolder) { $OutFolder = "$PSScriptRoot" }
if (!(Test-Path -LiteralPath "$OutFolder" )) { New-Item $OutFolder -ItemType Directory -Force | Out-Null }
$OutFolder = Get-Item -LiteralPath $OutFolder

$timeUTC = (Get-Date).ToUniversalTime()

if (!$FilterPath -and `
    !$Region    )   { $FilterPath = 'sydney/staging/' }

if (!$FilterFile -and $FilterPath) { $FilterPath = (($FilterPath -split ',' | foreach { if ($_ -notmatch '.*/$') { "$_/" } else { $_ } }) -join ',') }
#if ($FilterPath -match    '/.*')  { $FilterPath =  $FilterPath.TrimStart("/") }


if ($Region) {
  if (!$FilterPath) { $FilterPath = 'quad/,staging/'  }
  foreach ($lp in $LatestPaths) {
    foreach ($fp in ($FilterPath -split ',')) { $temp += "$(if ($temp) { ',' })$lp$fp"  } 
  }
  $FilterPath = $temp
} 

function New-UrlStatFile { return [PSCustomObject]@{ Name=$args[0]; DateTime=$args[1] } }
$statFiles = @()

if ($FilterFile -and $FilterFile -notmatch '\*') { $FilterFile = "*$FilterFile*" }
if ($LimitMins -eq 0 -and $LimitDays -eq 0) {
  if ($LatestFile -or `
      $FilterFile) { $LimitDays = 30 }
  else             { $LimitDays = 1  }
} 


foreach ($p in ($FilterPath -split ',')) {
  $startDate = $timeUTC.AddMinutes($LimitMins * -1).AddDays($LimitDays * -1)
  $tempDate  = $startDate
  while ($tempDate.Year -le $timeUTC.Year -and $tempDate.Month -le $timeUTC.Month) {
    $xml = [xml](invoke-webrequest -Uri "$($AwsUrl)?prefix=$p$($tempDate.Year)-$('{0:d2}' -f $tempDate.Month)") 
    $xml.ListBucketResult.Contents | foreach { if ($_) { $statFiles += (New-UrlStatFile $_.Key $_.LastModified) } }
    $tempDate = $tempDate.AddMonths(1)
  }
}

$statFiles
#LatestFileOnly
if ($LatestFile) { $statFiles = ($statFiles | Sort DateTime -Descending)[0] }

write-host "FO Stats Downloader: `n"`
            "Date Limiter:`t$('{0:yyyy-MM-dd-HH-mm-ss}' -f $startDate)`n"`
            "-LimitDays:`t$LimitDays`n" `
            "-LimitMins:`t$LimitMins`n" `
            "-FilterPath:`t$FilterPath`n" `
            "-FilterFile:`t$FilterFile`n" `
            "-OutFolder:`t$OutFolder`n"`
            "-Overwrite:`t$Overwrite`n"`


$filesDownloaded = @()

write-host " Downloading..."
write-host "===================================================================================================="

foreach ($f in $statFiles) {
  if ($FilterFile -and $f.Name -notlike $FilterFile) { continue }
  
  if (!($FileFilter) -and ($LimitMins -gt 0 -or $LimitDays -gt 0))  {
    if ($f.Name -notmatch '20[1-3][0-9]-[0-1][0-9]-[0-3][0-9]-[0-9][0-9]-[0-5][0-9]-[0-5][0-9]') {
      $f
      Write-Host "ERROR: Minute/Day limit not possible - file has invalid date/time [$($f.Name)]"
      continue
    } else {
      $f_date = ([DateTime]::ParseExact($matches[0],'yyyy-MM-dd-HH-mm-ss',$null))
      if ($f_date -lt $timeUTC.AddMinutes($LimitMins * -1).AddDays($LimitDays * -1)) { continue }
    }
  }

  $filePath  = "$OutFolder\$(Split-Path $f.Name)"
  $fileName  = "$OutFolder\$($f.Name)"

  if (!$Overwrite -and (Test-Path -LiteralPath $fileName)) {
    write-host "SKIPPED: File Already exists [$($f.Name)]"
    if ($ForceStats) { $filesDownloaded += (Get-Item ($fileName -replace '\[','`[' -replace '\]','`]')) }
    $filesSkipped += 1
    continue
  } 

  if (!(Test-Path -LiteralPath $filePath)) { New-Item -Path $filePath -ItemType Directory | Out-Null }
  write-host "Downloading:- $($f.Name)"
  ([string](invoke-webrequest -Uri "$($AwsUrl)$($f.Name)")) | Out-File -LiteralPath  $fileName
  $filesDownloaded += (Get-Item ($fileName -replace '\[','`[' -replace '\]','`]'))
}

if (!$filesSkipped -and $filesDownloaded.Count -eq 0) {
  Write-Host "No stat files matched from the $($statFiles.Count) AWSresults filtered."
  Write-Host "NOTE: AWS results are capped at 1000 files, limit your days/mins or paths."
  Write-Host ""
  Write-Host "`tFirst file date:`t$(if ($statFiles.Count -gt 0) { $statFiles[0].DateTime  } else { 'No results' } )"
  Write-Host "`tLast  file date:`t$(if ($statFiles.Count -gt 0) { $statFiles[-1].DateTime } else { 'No results' } )"
  Write-Host ""
  Write-Host "Please check your search filters and try again."
  write-host "===================================================================================================="
  return
}

if ($DownloadOnly -or $Demos) { return }

write-host "====================================================================================================`n"
foreach ($fileName in $filesDownloaded) {
  $param = @{ StatFile=$fileName }
  if ($RoundTime) { $param.RoundTime = $RoundTime }
  if ($TextOnly)  { $param.TextOnly = $true  }
  if ($TextSave)  { $param.TextSave = $true  }
  if ($OpenHTML)  { $param.$OpenHTML = $true }

  $i++
  write-host "===================================================================================================="
  write-host "FO Stats ($i of $($filesDownloaded.Length)):- `t$($fileName)"
  if ($param.Count -gt 1) { Write-Host "Parameters: $($param.GetEnumerator() | foreach { if ($_.Name -ne 'StatFile') { " -$($_.Name): $($_.Value)" } })" }
  write-host "----------------------------------------------------------------------------------------------------"
  & .\FO_stats_v2.ps1 @param
  write-host "----------------------------------------------------------------------------------------------------"
  write-host "FO Stats Completed:-`t$($fileName)"
  write-host "----------------------------------------------------------------------------------------------------"

}

