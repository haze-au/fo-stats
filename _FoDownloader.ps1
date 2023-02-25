﻿######################################################
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
          $TargetDate, #Date pointer - limited by -LimitDate or -LimitDays/-LimitMins
          $LimitDate,
  [int]   $LimitMins,  #Only access files from last X minutes (sum of days and mins)(sum of days and mins)
  [double]$LimitDays,  #Only access files from last X days (sum of days and mins)
  [switch]$DownloadOnly,#Download JSON only
  [switch]$Overwrite,  #Force re-download do the FO_stats again even when file exists
  [switch]$ForceStats, #Force running stats on already existing file
  ### FO_Stats parameters ###################
  [int]   $RoundTime,  #Passed to FO_Stats
  [switch]$TextSave,   #Passed to FO_Stats
  [switch]$NoStatJson, #Passed to FO_stats
  [switch]$TextOnly,   #Passed to FO_Stats
  [switch]$OpenHTML,   #Passed to FO_Stats
  [switch]$DailyBatch  #For HTTP server daily tallying functions (no use on client)
)

if ($Demos) { $AwsUrl = 'https://fortressone-demos.s3.amazonaws.com/' }
else        { $AwsUrl = 'https://fortressone-stats.s3.amazonaws.com/' }

$OCEPaths = @('sydney/','melbourne/','sydney-gz/','snoozer/')
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

if ($TargetDate) {
  if ($TargetDate.GetType() -eq [string]) { $TargetDate = [datetime]::Parse($TargetDate) }
  if ($TargetDate.GetType() -ne [datetime]) { 'ERROR: -StartDate invalid'; return }
} 

if ($LimitDate) {
  if ($LimitDate.getType() -eq [string]) { $LimitDate = [datetime]::Parse($LimitDate) }
  if ($LimitDate.GetType() -ne [datetime]) { 'ERROR: -EndDate invalid'; return }

  if ($TargetDate -gt $LimitDate) {  
    $temp = $TargetDate
    $TargetDate = $LimitDate
    $LimitDate   = $temp
    Remove-Variable temp
  }
}

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

function New-UrlStatFile { return [PSCustomObject]@{ Name=$args[0]; DateTime=$args[1]; Size=$args[2] } }
$statFiles = @()

if ($FilterFile -and $FilterFile -notmatch '\*') { $FilterFile = "*$FilterFile*" }
if (!$LimitDate -and $LimitMins -eq 0 -and $LimitDays -eq 0) {
  if ($FilterFile)     { $LimitDays = 30 }
  elseif ($LatestFile) { $LimitDays = 7  }
  else                 { $LimitDays = 1  }
} 


if (!$TargetDate) { $TargetDate  = $timeUTC.AddMinutes($LimitMins * -1).AddDays($LimitDays * -1) }
if (!$LimitDate)  { $LimitDate   = $timeUTC }

foreach ($p in ($FilterPath -split ',')) {
  $tempDate  = $TargetDate
  while ($tempDate.Year -le $LimitDate.Year -and $tempDate.Month -le $LimitDate.Month) {
    $xml = [xml](invoke-webrequest -Uri "$($AwsUrl)?prefix=$p$($tempDate.Year)-$('{0:d2}' -f $tempDate.Month)") 
    $xml.ListBucketResult.Contents | foreach { if ($_) { $statFiles += (New-UrlStatFile $_.Key $_.LastModified $_.Size) } }
    $tempDate = $tempDate.AddMonths(1)
  }
}

#LatestFileOnly
if ($LatestFile) { $statFiles = ($statFiles | Sort-Object DateTime -Descending)[0] }

write-host "FO Stats Downloader: `n"`
            "-TargetDate:`t$('{0:yyyy-MM-dd-HH-mm-ss}' -f $TargetDate)`n"`
            "-LimitDate: `t$('{0:yyyy-MM-dd-HH-mm-ss}' -f $LimitDate)`n"`
            "-LimitDays:`t$LimitDays`n" `
            "-LimitMins:`t$LimitMins`n" `
            "-FilterPath:`t$FilterPath`n" `
            "-FilterFile:`t$FilterFile`n" `
            "-OutFolder:`t$OutFolder`n"`
            "-Overwrite:`t$Overwrite`n"`
            "-DownloadOny:`t$DownloadOny`n"`
            "-ForceStats:`t$ForceStats`n"


$filesDownloaded = @()

write-host " Downloading..."
write-host "===================================================================================================="

foreach ($f in $statFiles) {
  if ($FilterFile -and $f.Name -notlike $FilterFile) { continue }
  
  if (!($FileFilter) -and ($LimitMins -gt 0 -or $LimitDays -gt 0 -or $LimitDate))  {
    if ($f.Name -notmatch '20[1-3][0-9]-[0-1][0-9]-[0-3][0-9]-[0-9][0-9]-[0-5][0-9]-[0-5][0-9]') {
      Write-Host "ERROR: Minute/Day limit not possible - file has invalid date/time [$($f.Name)]"
      continue
    } else {
      $f_date = ([DateTime]::ParseExact($matches[0],'yyyy-MM-dd-HH-mm-ss',$null))
      if ($f_date -lt $TargetDate -or $f_date -gt $LimitDate) { continue }
    }

  }

  $filePath  = "$OutFolder\$(Split-Path $f.Name)"
  $fileName  = "$OutFolder\$($f.Name)"

  if (!$Overwrite -and (Test-Path -LiteralPath ($fileName -replace '\.json$','.html') )) {
    write-host "SKIPPED: File Already exists [$($f.Name)]"
    if ($ForceStats) { $filesDownloaded += (Get-Item -LiteralPath $fileName) }
    $filesSkipped += 1
    continue
  } 

  if (!(Test-Path -LiteralPath $filePath)) { New-Item -Path $filePath -ItemType Directory | Out-Null }
  write-host "Downloading:- $($f.Name)"
  (invoke-webrequest -Uri "$($AwsUrl)$($f.Name)").Content | Out-File -LiteralPath  $fileName
  $filesDownloaded += (Get-Item -LiteralPath $fileName)
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

if (!$DownloadOnly -and !$Demos) { 
    write-host "====================================================================================================`n"
    foreach ($fileName in $filesDownloaded) {
      $param = @{ StatFile=$fileName }
      if ($RoundTime)  { $param.RoundTime  = $RoundTime }
      if ($TextOnly)   { $param.TextOnly   = $true  }
      if ($TextSave)   { $param.TextSave   = $true  }
      if ($NoStatJson) { $param.NoStatJson = $true  }
      if ($OpenHTML)   { $param.$OpenHTML  = $true  }

      $i++
      write-host "===================================================================================================="
      write-host "FO Stats ($i of $($filesDownloaded.Length)):- `t$($fileName)"
      if ($param.Count -gt 1) { Write-Host "Parameters: $($param.GetEnumerator() | foreach { if ($_.Name -ne 'StatFile') { " -$($_.Name): $($_.Value)" } })" }
      write-host "----------------------------------------------------------------------------------------------------"
      & $PSScriptRoot\FO_stats_v2.ps1 @param
      
      if (!$NoStatJson) {
        $outJson = (Get-Content -LiteralPath ($fileName -replace '\.json$','_stats.json') -Raw) | ConvertFrom-Json
        $outJson.Matches[0].Match = "$($fileName.Directory.Parent.Name)/$($fileName.Directory.Name)/$($outJson.Matches[0].Match)"
        ($outJson | ConvertTo-JSON) | Out-File -LiteralPath ($fileName -replace '\.json$','_stats.json')
      }
      write-host "----------------------------------------------------------------------------------------------------"
      write-host "FO Stats Completed:-`t$($fileName)"
      write-host "----------------------------------------------------------------------------------------------------"

      if ($DailyBatch) { Remove-Item -LiteralPath $fileName -Force }
    }
}

if ($DailyBatch) { 
  $DayReportOCE = [datetime]::Parse('19:00') # Syd 6am
  $DayReportUS  = [datetime]::Parse('14:00') # Cali 6am
  $DayReportEU  = [datetime]::Parse('6:00')  # UTC time
  
  #OCE 19-23 +1 day, 00-18 Same day, 13-18 6am grace period
  if     ([DateTime]::UtcNow.hour -in 19..23) { $DayReportOCE = $DayReportOCE.AddDays(-1) }
  elseif ([DateTime]::UtcNow.hour -in 13..18) { $DayReportOCE = $DayReportOCE.AddDays(-1) }
  
  #US 14-23 same day, 0-7 +1 day, 8-14 6am grace period
  if     ([DateTime]::UtcNow.hour  -in 0..7)    { $DayReportUS  = $DayReportUS.AddDays(-1)  }
  elseif ([DateTime]::UtcNow.hour  -in 8..13)   { $DayReportUS  = $DayReportUS.AddDays(-1) }
  
  #EU UTC time, 0-6 6am grace period
  if ([DateTime]::UtcNow.hour  -in 0..6) { $DayReportEU  = $DayReportEU.AddDays(-1)  }
  
  & $PSScriptRoot\FO_stats_join-json.ps1 -StartDateTime $DayReportOCE.ToString() -Region OCE -OutFile "$PSScriptRoot/_daily/oceania/oceania_DailyStats_$('{0:yyyy-MM-dd}' -f $DayReportOCE).json"
  & $PSScriptRoot\FO_stats_join-json.ps1 -StartDateTime $DayReportUS.ToString()  -Region US  -OutFile "$PSScriptRoot/_daily/north-america/north-america_DailyStats_$('{0:yyyy-MM-dd}' -f $DayReportUS).json"
  & $PSScriptRoot\FO_stats_join-json.ps1 -StartDateTime $DayReportEU.ToString()  -Region EU  -OutFile "$PSScriptRoot/_daily/europe/europe_DailyStats_$('{0:yyyy-MM-dd}' -f $DayReportEU).json"
}


# SIG # Begin signature block
# MIIbngYJKoZIhvcNAQcCoIIbjzCCG4sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUUaxidpr+djxOJt1ci47CXa2R
# NYagghYTMIIDCDCCAfCgAwIBAgIQVxZN0cTEa7NFKtjIhSbFETANBgkqhkiG9w0B
# AQsFADAcMRowGAYDVQQDDBFIYXplIEF1dGhlbnRpY29kZTAeFw0yMzAyMTAwNTM3
# MzRaFw0yNDAyMTAwNTU3MzRaMBwxGjAYBgNVBAMMEUhhemUgQXV0aGVudGljb2Rl
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1M46e4LcpTytNDpPe4AN
# aUJrafdLCl23kH5G7qTsBRRwI6qpRhZc5TBI19oEwulC4t8h7nI6D78kYx8FdI2h
# tb0wWmhcPBAAT7iywe0G0Q3NgZxZKOyI0yto69Z7TMPnbGKhCegPuvAT0LejgTrK
# +OAH0a/uGBVCGgu1EsIOtVitWsuxTKNR5bX3b2Zoc1xaEVOMFGy74IvXzIx+VyaN
# pSH6JYo3iSLWmQNRMBvMPsRfcvkh9R1DXemAJX3LHEm0Bei3xco+20zhRQtCO1Md
# rAEAL3aq3oFDQ2KV1RCNqo5kvnwBBDumAveg7JnjuUd3DvqCF0+Hs+q2KjRy02vt
# MQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMw
# HQYDVR0OBBYEFFwWkpE7S3mEJiqQ8mTrbI0pUNm+MA0GCSqGSIb3DQEBCwUAA4IB
# AQC9XvfYZgwF/9CysiCloHccqkH8T+AJJCX1Uq1lZ9DTO7olZfTmrI/JQWrSDdrK
# hsEi9wp6uTjfapE18EQW9CBIAMNLFjhFv/uLGEp9vZpUWpuG+2hqVu0thtZbw/Gm
# gMh8yhm/lTXUj1tcltPDkgWnd2u44O2fdF2kE6hevBEXM71a45OiMic3SgpLi6m3
# nMrsdQ0wu3qDm5I2Tm/Htq7Telmq0V3Lu1CKK6lYxxR1+Epsxumyiu0q9IKeKLMR
# RlbKKqHPcKoOadWNfZ1kR+5sO4q3+Tnc1evHS4HbJHQVZtR2k/tdsOvNi8qk9Sh9
# +GFTkJDGhZR9TsyW2Se2KTUMMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAY
# WjANBgkqhkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNl
# cnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdp
# Q2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5
# MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVz
# dGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBz
# aN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbr
# VsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTR
# EEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJ
# z82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyO
# j4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6R
# AXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k
# 98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJ
# tppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUa
# dmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZB
# dd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVf
# nSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0T
# AQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0j
# BBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsG
# AQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9j
# cmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYD
# VR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3Qb
# PbYW1/e/Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5
# +KH38nLeJLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+n
# BgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc
# /RzY9HdaXFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVr
# zyerbHbObyMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o
# 4rmUMIIGrjCCBJagAwIBAgIQBzY3tyRUfNhHrP0oZipeWzANBgkqhkiG9w0BAQsF
# ADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQL
# ExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJv
# b3QgRzQwHhcNMjIwMzIzMDAwMDAwWhcNMzcwMzIyMjM1OTU5WjBjMQswCQYDVQQG
# EwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0
# IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxoY1BkmzwT1ySVFVxyUDxPKRN6mX
# UaHW0oPRnkyibaCwzIP5WvYRoUQVQl+kiPNo+n3znIkLf50fng8zH1ATCyZzlm34
# V6gCff1DtITaEfFzsbPuK4CEiiIY3+vaPcQXf6sZKz5C3GeO6lE98NZW1OcoLevT
# sbV15x8GZY2UKdPZ7Gnf2ZCHRgB720RBidx8ald68Dd5n12sy+iEZLRS8nZH92GD
# Gd1ftFQLIWhuNyG7QKxfst5Kfc71ORJn7w6lY2zkpsUdzTYNXNXmG6jBZHRAp8By
# xbpOH7G1WE15/tePc5OsLDnipUjW8LAxE6lXKZYnLvWHpo9OdhVVJnCYJn+gGkcg
# Q+NDY4B7dW4nJZCYOjgRs/b2nuY7W+yB3iIU2YIqx5K/oN7jPqJz+ucfWmyU8lKV
# EStYdEAoq3NDzt9KoRxrOMUp88qqlnNCaJ+2RrOdOqPVA+C/8KI8ykLcGEh/FDTP
# 0kyr75s9/g64ZCr6dSgkQe1CvwWcZklSUPRR8zZJTYsg0ixXNXkrqPNFYLwjjVj3
# 3GHek/45wPmyMKVM1+mYSlg+0wOI/rOP015LdhJRk8mMDDtbiiKowSYI+RQQEgN9
# XyO7ZONj4KbhPvbCdLI/Hgl27KtdRnXiYKNYCQEoAA6EVO7O6V3IXjASvUaetdN2
# udIOa5kM0jO0zbECAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYD
# VR0OBBYEFLoW2W1NhS9zKXaaL3WMaiCPnshvMB8GA1UdIwQYMBaAFOzX44LScV1k
# TN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcD
# CDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0
# cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmww
# IAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUA
# A4ICAQB9WY7Ak7ZvmKlEIgF+ZtbYIULhsBguEE0TzzBTzr8Y+8dQXeJLKftwig2q
# KWn8acHPHQfpPmDI2AvlXFvXbYf6hCAlNDFnzbYSlm/EUExiHQwIgqgWvalWzxVz
# jQEiJc6VaT9Hd/tydBTX/6tPiix6q4XNQ1/tYLaqT5Fmniye4Iqs5f2MvGQmh2yS
# vZ180HAKfO+ovHVPulr3qRCyXen/KFSJ8NWKcXZl2szwcqMj+sAngkSumScbqyQe
# JsG33irr9p6xeZmBo1aGqwpFyd/EjaDnmPv7pp1yr8THwcFqcdnGE4AJxLafzYeH
# JLtPo0m5d2aR8XKc6UsCUqc3fpNTrDsdCEkPlM05et3/JWOZJyw9P2un8WbDQc1P
# tkCbISFA0LcTJM3cHXg65J6t5TRxktcma+Q4c6umAU+9Pzt4rUyt+8SVe+0KXzM5
# h0F4ejjpnOHdI/0dKNPH+ejxmF/7K9h+8kaddSweJywm228Vex4Ziza4k9Tm8heZ
# Wcpw8De/mADfIBZPJ/tgZxahZrrdVcA6KYawmKAr7ZVBtzrVFZgxtGIJDwq9gdkT
# /r+k0fNX2bwE+oLeMt8EifAAzV3C+dAjfwAL5HYCJtnwZXZCpimHCUcr5n8apIUP
# /JiW9lVUKx+A+sDyDivl1vupL0QVSucTDh3bNzgaoSv27dZ8/DCCBsAwggSooAMC
# AQICEAxNaXJLlPo8Kko9KQeAPVowDQYJKoZIhvcNAQELBQAwYzELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBU
# cnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTAeFw0yMjA5
# MjEwMDAwMDBaFw0zMzExMjEyMzU5NTlaMEYxCzAJBgNVBAYTAlVTMREwDwYDVQQK
# EwhEaWdpQ2VydDEkMCIGA1UEAxMbRGlnaUNlcnQgVGltZXN0YW1wIDIwMjIgLSAy
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAz+ylJjrGqfJru43BDZrb
# oegUhXQzGias0BxVHh42bbySVQxh9J0Jdz0Vlggva2Sk/QaDFteRkjgcMQKW+3Kx
# lzpVrzPsYYrppijbkGNcvYlT4DotjIdCriak5Lt4eLl6FuFWxsC6ZFO7KhbnUEi7
# iGkMiMbxvuAvfTuxylONQIMe58tySSgeTIAehVbnhe3yYbyqOgd99qtu5Wbd4lz1
# L+2N1E2VhGjjgMtqedHSEJFGKes+JvK0jM1MuWbIu6pQOA3ljJRdGVq/9XtAbm8W
# qJqclUeGhXk+DF5mjBoKJL6cqtKctvdPbnjEKD+jHA9QBje6CNk1prUe2nhYHTno
# +EyREJZ+TeHdwq2lfvgtGx/sK0YYoxn2Off1wU9xLokDEaJLu5i/+k/kezbvBkTk
# Vf826uV8MefzwlLE5hZ7Wn6lJXPbwGqZIS1j5Vn1TS+QHye30qsU5Thmh1EIa/tT
# QznQZPpWz+D0CuYUbWR4u5j9lMNzIfMvwi4g14Gs0/EH1OG92V1LbjGUKYvmQaRl
# lMBY5eUuKZCmt2Fk+tkgbBhRYLqmgQ8JJVPxvzvpqwcOagc5YhnJ1oV/E9mNec9i
# xezhe7nMZxMHmsF47caIyLBuMnnHC1mDjcbu9Sx8e47LZInxscS451NeX1XSfRkp
# WQNO+l3qRXMchH7XzuLUOncCAwEAAaOCAYswggGHMA4GA1UdDwEB/wQEAwIHgDAM
# BgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMCAGA1UdIAQZMBcw
# CAYGZ4EMAQQCMAsGCWCGSAGG/WwHATAfBgNVHSMEGDAWgBS6FtltTYUvcyl2mi91
# jGogj57IbzAdBgNVHQ4EFgQUYore0GH8jzEU7ZcLzT0qlBTfUpwwWgYDVR0fBFMw
# UTBPoE2gS4ZJaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3Rl
# ZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNybDCBkAYIKwYBBQUHAQEE
# gYMwgYAwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBYBggr
# BgEFBQcwAoZMaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1
# c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNydDANBgkqhkiG9w0B
# AQsFAAOCAgEAVaoqGvNG83hXNzD8deNP1oUj8fz5lTmbJeb3coqYw3fUZPwV+zbC
# SVEseIhjVQlGOQD8adTKmyn7oz/AyQCbEx2wmIncePLNfIXNU52vYuJhZqMUKkWH
# SphCK1D8G7WeCDAJ+uQt1wmJefkJ5ojOfRu4aqKbwVNgCeijuJ3XrR8cuOyYQfD2
# DoD75P/fnRCn6wC6X0qPGjpStOq/CUkVNTZZmg9U0rIbf35eCa12VIp0bcrSBWcr
# duv/mLImlTgZiEQU5QpZomvnIj5EIdI/HMCb7XxIstiSDJFPPGaUr10CU+ue4p7k
# 0x+GAWScAMLpWnR1DT3heYi/HAGXyRkjgNc2Wl+WFrFjDMZGQDvOXTXUWT5Dmhiu
# w8nLw/ubE19qtcfg8wXDWd8nYiveQclTuf80EGf2JjKYe/5cQpSBlIKdrAqLxksV
# StOYkEVgM4DgI974A6T2RUflzrgDQkfoQTZxd639ouiXdE4u2h4djFrIHprVwvDG
# IqhPm73YHJpRxC+a9l+nJ5e6li6FV8Bg53hWf2rvwpWaSxECyIKcyRoFfLpxtU56
# mWz06J7UWpjIn7+NuxhcQ/XQKujiYu54BNu90ftbCqhwfvCXhHjjCANdRyxjqCU4
# lwHSPzra5eX25pvcfizM/xdMTQCi2NYBDriL7ubgclWJLCcZYfZ3AYwxggT1MIIE
# 8QIBATAwMBwxGjAYBgNVBAMMEUhhemUgQXV0aGVudGljb2RlAhBXFk3RxMRrs0Uq
# 2MiFJsURMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkG
# CSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEE
# AYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQZM5tdyB4jRv8WjlEyDrmvsRBFVTANBgkq
# hkiG9w0BAQEFAASCAQB+tjTQKUZbWy2W/nIrNx1lz8D3z6j6tWckWyg1GSYSjaFO
# /rvgfMBiIvoQBAnFQeMu6c01UQ9hg1/nYzoyxoCtILNWKllTfh//AK/v3cWwo3dh
# YzkwOiMu6WF//WRkWqjbVb1/ZoCX3HuEQQ6jt6Nv0E0aTE5fOjFdkRpzqbhpHfUa
# a5MIXSmaiqWKKaMS6WnJ0kZ8IFKy6l25+PVKKFHO8ICf6cpgqBqanxOOTmqmg1Lp
# Cp5ovYl+LlIlfzbQXBVKNQRrcQxKje3hKpr524m5qPBmfGfK92d13kIwA4Oqrzd7
# sHXFGcTltJKxZHiRuVX+DoV1JJ8cONb4tVGnwSVWoYIDIDCCAxwGCSqGSIb3DQEJ
# BjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0
# LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hB
# MjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwqSj0pB4A9WjANBglghkgBZQME
# AgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTIzMDIyNTEwMjkxN1owLwYJKoZIhvcNAQkEMSIEILmTa2hQzReGAOud+7HgCf1S
# GmnKzyMXnyu7MfL0a8VZMA0GCSqGSIb3DQEBAQUABIICAE0LVa2cgL+YBC8kTKgi
# JukaDNIilWpscY1Kx3hhPrZXmoL0MDiWklbxfLuEibjusVQbKYerUPT/wNbSmFXn
# NlhSf+4xpMa0Xrvbm9Pj3xGpxKgAUjDa8AhbBKLMLPheT/QNWRxo7OeXOBDsJH1g
# 36+VvL1Lnfy7rWEPwGasVF71GgcgMtGUsWaf8i3qh1OYqo/v4i6rtOIlMd42yIZq
# Og22hZH+wvwnE/gq8XEcxmGo/6TxyNN8gLLoh0gYinkwz0INB0zdtS1aTMOizKpb
# KwbM4DCCw46eF26f8praNSgo0TrEcqZ3511bDHCa08xKvp5C7yJkrZ1mwVOOBK7Z
# yaU9pfLCCVVABjUIj37OBOMvETLby74ooQOoaLunXgu077AQGux8Lj826dDr39YZ
# 6sx2bLWzc9xwRPETWAjtWYHnW4FD7Ces0V59PYVj5Bd17xosfDo0wTF6zdtq+L9m
# GA9wz8LdmoWImfRK86V3bW3jGNsHGcODMlIHXYdsLzPURauDWVZYklmg/QZeKnVp
# Gl6G+1h6BxxYwiD91WsPB7Hq0OkFzkn06kyWRWyyfgcI1RJ5VxcuAmjBVXSOyxMU
# /6+5XRQuJJG/Mc1+irL0HWeeaddUDzvg0kUGlsibweLXhn6+CMSpGS92yJbzgaVh
# 9TYOapcgjwbVy5GPp0WkQMPj
# SIG # End signature block
