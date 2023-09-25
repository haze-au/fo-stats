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
# 7. Demos from ALL regions - Go servers only in last 24hrs.
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
  [ValidateSet('ALL','US','BR','EU','OCE','INT')]
          $Region,     # All | US | BR | EU | OCE | Int
  [switch]$AwsCLI,     # Requires AWS CLI, scans all paths on the AWS bucket (stagine|quad|fo|hue), ignores region/filterpath
  [string]$LocalFile,
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
  [switch]$DailyBatch,  #For HTTP server daily tallying functions (no use on client)
  [switch]$PeriodBatch, #For HTTP server last 24hr / 7days stats
  ### FO_Stats parameters ###################
  [int]   $RoundTime,  #Passed to FO_Stats
  [switch]$TextSave,   #Passed to FO_Stats
  [switch]$NoStatJson, #Passed to FO_stats
  [switch]$TextOnly,   #Passed to FO_Stats
  [switch]$OpenHTML,   #Passed to FO_Stats
  [switch]$CleanUp     #Delete JSON after stats.
)

if ($Demos) { $AwsUrl = 'https://fortressone-demos.s3.amazonaws.com/' }
else        { $AwsUrl = 'https://fortressone-stats.s3.amazonaws.com/' }

# Update me for -Region parameter and Daily Stats updates
$OCEPaths = @('sydney/','melbourne/')
$USPaths  = @('california/','dallas/','virginia/','miami/','phoenix/')
$BRPaths  = @('saopaulo/','fortaleza/')
$EUPaths  = @('ireland/','stockholm/','london/')
$IntPaths = @('bahrain/','guam/','mumbai/','tokyo/')

if     ($Region -eq 'ALL') { $LatestPaths = $OCEPaths + $USPaths + $EUPaths + $IntPaths + $BRPaths }
elseif ($Region -eq 'US')  { $LatestPaths = $USPaths  }
elseif ($Region -eq 'BR')  { $LatestPaths = $BRPaths  }
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

if ($FilterPath -match '^(.*/)+(.*\.json)$') { $FilterPath = $matches[1]; $FilterFile = $matches[2] }
elseif (!$FilterFile -and $FilterPath) { $FilterPath = (($FilterPath -split ',' | foreach { if ($_ -notmatch '.*/$') { "$_/" } else { $_ } }) -join ',') }
#if ($FilterPath -match    '/.*')  { $FilterPath =  $FilterPath.TrimStart("/") }

function New-UrlStatFile { return [PSCustomObject]@{ Name=$args[0]; DateTime=$args[1]; Size=$args[2] } }

if (!$LimitDate -and $LimitMins -eq 0 -and $LimitDays -eq 0) {
  if     ($LocalFile)  { $LimitDays = 90 }
  elseif ($FilterFile) { $LimitDays = 30 }
  elseif ($LatestFile) { $LimitDays = 7  }
  else                 { $LimitDays = 1  }
} 

if (!$TargetDate) { $TargetDate  = $timeUTC.AddMinutes($LimitMins * -1).AddDays($LimitDays * -1) }
if (!$LimitDate)  { $LimitDate   = $timeUTC }

if ($LocalFile) {
  if (!(Test-Path -LiteralPath $LocalFile)) { write-host "ERROR - Local File not found:- $LocalFile"; return }
  elseif ($LocalFile -notmatch '^(.*/)?(20[1-3][0-9]-[0-1][0-9]-[0-3][0-9][_-][0-9][0-9]-[0-5][0-9]-[0-5][0-9]).*[.]json') { write-host "ERROR - No date found in '$LocalFile'"; return }
  else {
    $f_date = ([DateTime]::ParseExact(($matches[2] -replace '_','-'),'yyyy-MM-dd-HH-mm-ss',$null))
    if ($f_date -lt $TargetDate -or $f_date -gt $LimitDate) { write-host "ERROR - Did not meet date/time restrictions:- $LocalFile"; return}
  }
  $filesDownloaded = @(Get-Item -LiteralPath $LocalFile)
  write-host "===================================================================================================="
  write-host " Processing local file: $LocalFile"
} else { 
  if ($Region) {
    if (!$FilterPath) { $FilterPath = 'quad/,staging/,scrim/,tourney/'  }
    foreach ($lp in $LatestPaths) {
      foreach ($fp in ($FilterPath -split ',')) { $temp += "$(if ($temp) { ',' })$lp$fp"  } 
    }
    $FilterPath = $temp
  } 
  $statFiles = @()

  if ($FilterFile -and $FilterFile -notmatch '\*') {
    $statFiles = New-UrlStatFile "$FilterPath$FilterFile" $null -1
  } elseif (!$AwsCLI) {
    foreach ($p in ($FilterPath -split ',')) {
      $tempDate  = $TargetDate
      while ($tempDate -le $LimitDate) {
        $xml = [xml](invoke-webrequest -Uri "$($AwsUrl)?prefix=$p$($tempDate.Year)-$('{0:d2}' -f $tempDate.Month)") 
        $xml.ListBucketResult.Contents | foreach { if ($_) { $statFiles += (New-UrlStatFile $_.Key $_.LastModified $_.Size) } }
        $tempDate = $tempDate.AddMonths(1)
        if ($tempDate -gt $LimitDate -and $TempDate.Month -eq $LimitDate.Month) { $tempDate = $LimitDate }
      }
    } 
  } else {
    $statJson = (& aws s3api list-objects-v2 --bucket fortressone-stats --query "Contents[?LastModified>``$($TargetDate.ToString('yyyy-MM-dd'))``]") | ConvertFrom-Json
    $statFiles += $statJson | Where-Object { $_.Key -match '.*/(quad|staging|scrim|tourney|fo|hue)/.*\.json$' } | foreach { (New-UrlStatFile $_.Key $_.LastModified $_.Size) }
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
              "-DownloadOnly:`t$DownloadOnly`n"`
              "-ForceStats:`t$ForceStats`n"`
              "-CleanUp:`t$CleanUp`n"`
              "-DailyBatch:`t$DailyBatch`n"`
              "-AwsCLI:`t$AwsCLI`n"


  $filesDownloaded = @()

  write-host " Downloading..."
  write-host "===================================================================================================="

  foreach ($f in $statFiles) {
    if ($FilterFile -match '\*' -and $f.Name -notlike "*$($FilterFile)*") { continue }
    if (!($FileFilter) -and (!$AwsCLI -and ($LimitMins -gt 0 -or $LimitDays -gt 0 -or $LimitDate)))  {
      if ($f.Name -notmatch '20[1-3][0-9]-[0-1][0-9]-[0-3][0-9]-[0-9][0-9]-[0-5][0-9]-[0-5][0-9]') {
        Write-Host "ERROR: Minute/Day limit not possible - file has invalid date/time [$($f.Name)]"
        continue
      } else {
        $f_date = ([DateTime]::ParseExact(($matches[0] -replace '_','-'),'yyyy-MM-dd-HH-mm-ss',$null))
        if ($f_date -lt $TargetDate -or $f_date -gt $LimitDate) { continue }
      }

    }

    $filePath  = "$OutFolder\$(Split-Path $f.Name)"
    $fileName  = "$OutFolder\$($f.Name)"

    if (!$Overwrite -and ( (Test-Path -LiteralPath ($fileName -replace '\.json$','.html')) `
                          -or ((Test-Path -LiteralPath $fileName) -and (Get-Item -LiteralPath $fileName).LastWriteTime -gt (Get-Date).AddMinutes(-20)) ) `
        ) {
      write-host "SKIPPED: File Already exists [$($f.Name)]"
      if ($ForceStats) { $filesDownloaded += (Get-Item -LiteralPath $fileName) }
      $filesSkipped += 1
      continue
    } 

    if (!(Test-Path -LiteralPath $filePath)) { New-Item -Path $filePath -ItemType Directory | Out-Null }
    write-host "Downloading:- $($f.Name)"
    
    foreach ($retry in 5..0) {
      try { 
        (invoke-webrequest -Uri "$($AwsUrl)$($f.Name)").Content | Out-File -LiteralPath  $fileName  -Encoding utf8    
        $filesDownloaded += (Get-Item -LiteralPath $fileName)
        break
      } catch {
        Write-Host "Error:- $($_.Exception.Message)"
        Write-Host "URL:- $($AwsUrl)$($f.Name)"
        # Retry for single file downloads only
        if (!$FilterFile -and $FilterFile -match '\*') { break }
        if ($retry -gt 0) { 
          Write-Host "Retrying in 3 seconds - $retry remaining" 
          Start-Sleep -Seconds 3
        }
      }
    }
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
} 

if (!$DownloadOnly -and !$Demos) { 
    write-host "====================================================================================================`n"
    foreach ($fileName in $filesDownloaded) {
      $param = @{ StatFile=$fileName }
      if ($RoundTime)  { $param.RoundTime  = $RoundTime }
      if ($TextOnly)   { $param.TextOnly   = $true  }
      if ($TextSave)   { $param.TextSave   = $true  }
      if ($NoStatJson) { $param.NoStatJson = $true  }
      if ($OpenHTML)   { $param.OpenHTML   = $true  }

      $i++
      write-host "===================================================================================================="
      write-host "FO Stats ($i of $($filesDownloaded.Length)):- `t$($fileName)"
      if ($param.Count -gt 1) { Write-Host "Parameters: $($param.GetEnumerator() | foreach { if ($_.Name -ne 'StatFile') { " -$($_.Name): $($_.Value)" } })" }
      write-host "----------------------------------------------------------------------------------------------------"
      & $PSScriptRoot\FO_stats_v2.ps1 @param
      
      if (!$NoStatJson) {
        $outJson = (Get-Content -LiteralPath ($fileName -replace '\.json$','_stats.json') -Raw) | ConvertFrom-Json
        $outJson.Matches[0].Match = "$($fileName.Directory.Parent.Name)/$($fileName.Directory.Name)/$($outJson.Matches[0].Match)"
        ($outJson | ConvertTo-JSON) | Out-File -LiteralPath ($fileName -replace '\.json$','_stats.json')  -Encoding utf8
      }
      write-host "----------------------------------------------------------------------------------------------------"
      write-host "FO Stats Completed:-`t$($fileName)"
      write-host "----------------------------------------------------------------------------------------------------"

      if ($DailyBatch -or $CleanUp) { Remove-Item -LiteralPath $fileName -Force }
    }
}

if ($DailyBatch) { 
  $DayFilterOCE = [datetime]::Parse('19:00') # Syd 6am
  $DayFilterUS  = [datetime]::Parse('14:00') # Cali 6am
  $DayFilterBR  = [datetime]::Parse('18:00') # Brasil 6am
  $DayFilterEU  = [datetime]::Parse('6:00')  # UTC time
  $DayFilterINT = [datetime]::Parse('16:00') # Dead zone for all regions - 3am Syd
  
  #OCE 19-23 +1 day, 00-18 Same day, 13-18 6am grace period
  if     ([DateTime]::UtcNow.hour -in 19..23) { $DayReportOCE = $DayFilterOCE.AddDays(1)  } 
  elseif ([DateTime]::UtcNow.hour -in 0..12)  { $DayReportOCE = $DayFilterOCE; $DayFilterOCE = $DayFilterOCE.AddDays(-1) }
  elseif ([DateTime]::UtcNow.hour -in 13..18) { $DayReportOCE = $DayFilterOCE; $DayFilterOCE = $DayFilterOCE.AddDays(-1) }
  
  #US 14-23 same day, 0-7 +1 day, 8-14 6am grace period
  if     ([DateTime]::UtcNow.hour  -in 14..23) { $DayReportUS = $DayFilterUS }
  elseif ([DateTime]::UtcNow.hour  -in 0..7)   { $DayFilterUS = $DayFilterUS.AddDays(-1); $DayReportUS = $DayFilterUS }
  elseif ([DateTime]::UtcNow.hour  -in 8..13)  { $DayFilterUS = $DayFilterUS.AddDays(-1); $DayReportUS = $DayFilterUS }
  
  #BR 14-23 same day, 0-7 +1 day, 8-14 6am grace period
  if     ([DateTime]::UtcNow.hour  -in 18..23)  { $DayReportBR = $DayFilterBR }
  elseif ([DateTime]::UtcNow.hour  -in 0..12)   { $DayFilterBR = $DayFilterBR.AddDays(-1); $DayReportBR = $DayFilterBR }
  elseif ([DateTime]::UtcNow.hour  -in 13..17)  { $DayFilterBR = $DayFilterBR.AddDays(-1); $DayReportBR = $DayFilterBR }


  #EU UTC time, 0-6 6am grace period
  if ([DateTime]::UtcNow.hour  -in 0..6) { $DayFilterEU  = $DayFilterEU.AddDays(-1) }
  $DayReportEU = $DayFilterEU

  # Interational cut-off, new days starts at 4pm
  if ([DateTime]::UtcNow.hour -in 0..15) { $DayReportINT = $DayFilterINT.AddDays(-1) }

  & $PSScriptRoot\FO_stats_join-json.ps1 -StartDateTime $DayFilterOCE.ToString() -Region OCE -OutFile "$PSScriptRoot/_daily/oceania/oceania_DailyStats_$('{0:yyyy-MM-dd}' -f $DayReportOCE).json"
  & $PSScriptRoot\FO_stats_join-json.ps1 -StartDateTime $DayFilterUS.ToString()  -Region US  -OutFile "$PSScriptRoot/_daily/north-america/north-america_DailyStats_$('{0:yyyy-MM-dd}' -f $DayReportUS).json"
  & $PSScriptRoot\FO_stats_join-json.ps1 -StartDateTime $DayFilterBR.ToString()  -Region BR  -OutFile "$PSScriptRoot/_daily/brasil/brasil_DailyStats_$('{0:yyyy-MM-dd}' -f $DayReportBR).json"
  & $PSScriptRoot\FO_stats_join-json.ps1 -StartDateTime $DayFilterEU.ToString()  -Region EU  -OutFile "$PSScriptRoot/_daily/europe/europe_DailyStats_$('{0:yyyy-MM-dd}' -f $DayReportEU).json"
  & $PSScriptRoot\FO_stats_join-json.ps1 -StartDateTime $DayReportINT.ToString() -Region INT -OutFile "$PSScriptRoot/_daily/international/international_DailyStats_$('{0:yyyy-MM-dd}' -f $DayReportINT).json"
  if (!$PeriodBatch) {
    & $PSScriptRoot\FO_stats_join-json.ps1 -StartOffSetHours 1 -Region ALL -OutFile "$PSScriptRoot/_stats-last24hrs.json"
    & $PSScriptRoot\FO_stats_join-json.ps1 -StartOffSetHours 1 -Region ALL -OutFile "$PSScriptRoot/_stats-last7days.json"

    $json = (Get-Content -LiteralPath "$PSScriptRoot/_stats-last24hrs.json" -Raw) | ConvertFrom-Json
    foreach ($m in $json.Matches.Match) {
      if ($m -match '.*\/(\d{4}-\d\d-\d\d)-(\d\d-\d\d-\d\d)_.*') {
        $dt = [datetime]::Parse($matches[1] + " " + ($matches[2] -replace '-',':'))
        if ($dt -lt (Get-Date).AddDays(-1).ToUniversalTime()) {
          & $PSScriptRoot/FO_stats_join-json.ps1 -RemoveMatch "$PSScriptRoot/$($m)_blue_vs_red_stats.json" -FromJson "$PSScriptRoot/_stats-last24hrs.json"
        }
      }
    }
    $json = (Get-Content -LiteralPath "$PSScriptRoot/_stats-last7days.json" -Raw) | ConvertFrom-Json
    foreach ($m in $json.Matches.Match) {
      if ($m -match '.*\/(\d{4}-\d\d-\d\d)-(\d\d-\d\d-\d\d)_.*') {
        $dt = [datetime]::Parse($matches[1] + " " + ($matches[2] -replace '-',':'))

        if ($dt -lt (Get-Date).AddDays(-7).ToUniversalTime()) {
          & $PSScriptRoot/FO_stats_join-json.ps1 -RemoveMatch "$PSScriptRoot/$($m)_blue_vs_red_stats.json" -FromJson "$PSScriptRoot/_stats-last7days.json"
        }
      }
    }
  }
}

if ($PeriodBatch) {
  Remove-Item "$PSScriptRoot/_stats-last24hrs.json"
  Remove-Item "$PSScriptRoot/_stats-last7days.json"
  & $PSScriptRoot\FO_stats_join-json.ps1 -StartOffSetDays 1 -Region ALL -OutFile "$PSScriptRoot/_stats-last24hrs.json"
  & $PSScriptRoot\FO_stats_join-json.ps1 -StartOffSetDays 7 -Region ALL -OutFile "$PSScriptRoot/_stats-last7days.json"
}

# SIG # Begin signature block
# MIIboAYJKoZIhvcNAQcCoIIbkTCCG40CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUoeMZs+HX3LhMNBF8eBA/6Qtn
# OlGgghYVMIIDCDCCAfCgAwIBAgIQVxZN0cTEa7NFKtjIhSbFETANBgkqhkiG9w0B
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
# /JiW9lVUKx+A+sDyDivl1vupL0QVSucTDh3bNzgaoSv27dZ8/DCCBsIwggSqoAMC
# AQICEAVEr/OUnQg5pr/bP1/lYRYwDQYJKoZIhvcNAQELBQAwYzELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBU
# cnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTAeFw0yMzA3
# MTQwMDAwMDBaFw0zNDEwMTMyMzU5NTlaMEgxCzAJBgNVBAYTAlVTMRcwFQYDVQQK
# Ew5EaWdpQ2VydCwgSW5jLjEgMB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0YW1wIDIw
# MjMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCjU0WHHYOOW6w+VLMj
# 4M+f1+XS512hDgncL0ijl3o7Kpxn3GIVWMGpkxGnzaqyat0QKYoeYmNp01icNXG/
# OpfrlFCPHCDqx5o7L5Zm42nnaf5bw9YrIBzBl5S0pVCB8s/LB6YwaMqDQtr8fwkk
# lKSCGtpqutg7yl3eGRiF+0XqDWFsnf5xXsQGmjzwxS55DxtmUuPI1j5f2kPThPXQ
# x/ZILV5FdZZ1/t0QoRuDwbjmUpW1R9d4KTlr4HhZl+NEK0rVlc7vCBfqgmRN/yPj
# yobutKQhZHDr1eWg2mOzLukF7qr2JPUdvJscsrdf3/Dudn0xmWVHVZ1KJC+sK5e+
# n+T9e3M+Mu5SNPvUu+vUoCw0m+PebmQZBzcBkQ8ctVHNqkxmg4hoYru8QRt4GW3k
# 2Q/gWEH72LEs4VGvtK0VBhTqYggT02kefGRNnQ/fztFejKqrUBXJs8q818Q7aESj
# pTtC/XN97t0K/3k0EH6mXApYTAA+hWl1x4Nk1nXNjxJ2VqUk+tfEayG66B80mC86
# 6msBsPf7Kobse1I4qZgJoXGybHGvPrhvltXhEBP+YUcKjP7wtsfVx95sJPC/QoLK
# oHE9nJKTBLRpcCcNT7e1NtHJXwikcKPsCvERLmTgyyIryvEoEyFJUX4GZtM7vvrr
# kTjYUQfKlLfiUKHzOtOKg8tAewIDAQABo4IBizCCAYcwDgYDVR0PAQH/BAQDAgeA
# MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYDVR0gBBkw
# FzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1NhS9zKXaa
# L3WMaiCPnshvMB0GA1UdDgQWBBSltu8T5+/N0GSh1VapZTGj3tXjSTBaBgNVHR8E
# UzBRME+gTaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQBggrBgEFBQcB
# AQSBgzCBgDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMFgG
# CCsGAQUFBzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3
# DQEBCwUAA4ICAQCBGtbeoKm1mBe8cI1PijxonNgl/8ss5M3qXSKS7IwiAqm4z4Co
# 2efjxe0mgopxLxjdTrbebNfhYJwr7e09SI64a7p8Xb3CYTdoSXej65CqEtcnhfOO
# HpLawkA4n13IoC4leCWdKgV6hCmYtld5j9smViuw86e9NwzYmHZPVrlSwradOKmB
# 521BXIxp0bkrxMZ7z5z6eOKTGnaiaXXTUOREEr4gDZ6pRND45Ul3CFohxbTPmJUa
# VLq5vMFpGbrPFvKDNzRusEEm3d5al08zjdSNd311RaGlWCZqA0Xe2VC1UIyvVr1M
# xeFGxSjTredDAHDezJieGYkD6tSRN+9NUvPJYCHEVkft2hFLjDLDiOZY4rbbPvlf
# sELWj+MXkdGqwFXjhr+sJyxB0JozSqg21Llyln6XeThIX8rC3D0y33XWNmdaifj2
# p8flTzU8AL2+nCpseQHc2kTmOt44OwdeOVj0fHMxVaCAEcsUDH6uvP6k63llqmjW
# Iso765qCNVcoFstp8jKastLYOrixRoZruhf9xHdsFWyuq69zOuhJRrfVf8y2OMDY
# 7Bz1tqG4QyzfTkx9HmhwwHcK1ALgXGC7KP845VJa1qwXIiNO9OzTF/tQa/8Hdx9x
# l0RBybhG02wyfFgvZ0dl5Rtztpn5aywGRu9BHvDwX+Db2a2QgESvgBBBijGCBPUw
# ggTxAgEBMDAwHDEaMBgGA1UEAwwRSGF6ZSBBdXRoZW50aWNvZGUCEFcWTdHExGuz
# RSrYyIUmxREwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAw
# GQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisG
# AQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFEvlTHYMUvxXZkMrOgSiD+Qz+sONMA0G
# CSqGSIb3DQEBAQUABIIBAG5rqgCt3aO8ThRjyRunYsaKcb4J9CI/qshYjprMFX0E
# nSOnp6sHoBDdcKqDG56riyHRGmIVViMUSfeM0xIKTCxQLfujfr0E5vJmxrNpPnNa
# WleULZ33OPspj8oKwebdJH5BvQqio3/OW66ThtvljxibFFJkHFYwPT8V3AgPFn1D
# YaZ+xN8t3qZik8wjTu1s7MdN7MGG6zFAL8pKR9T+YfvtjZgzLXthQW+meFnWnUUE
# 1zszdGiMvKZSf1tugqx6GMeKik9Jhd0Rlkr2heYQ5Fo2hcrdNYLIRnURu0Mwqxt5
# Cpb0bo7cu57qDCRR+NtCzcCqUAKubHj58bYxDQnt+QOhggMgMIIDHAYJKoZIhvcN
# AQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNl
# cnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBT
# SEEyNTYgVGltZVN0YW1waW5nIENBAhAFRK/zlJ0IOaa/2z9f5WEWMA0GCWCGSAFl
# AwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUx
# DxcNMjMwODIyMDUyODI3WjAvBgkqhkiG9w0BCQQxIgQgA9/+CFmwhhb7IthV66eW
# RnJecNchS4x1PQUDx09kiAYwDQYJKoZIhvcNAQEBBQAEggIAXjEuPtu6aVV+wKFG
# eMBwtRmbu3HvzD3M07pZsyJJ+/nILYtKSGKzYYwxhx1aSeEjKizapLTzQt6dvOCj
# voG0GmAF94XLMM37TKQ0wl7wsmjaRkZmKjkY6wLDBuqu9McZlJSl5R7HlVqrI+wj
# ZDTPmLBQMVarya6QbGgMBdccVHjObCHuxW3p6dyTMt6mcdtbhWJkCosLjvgCDOXk
# QdTfjGkBmRfkviuhmSHFWm/RzGDVht2IZ8tsKA/EA3GX5/xLfZsBgqge0zDF6Zag
# 9JtNdQAqvTpXiZbyr028p/wsPI/mFAY3C5MtCSTXiCJUoQg8jQQ9B2MpHzCgnJg0
# i8Jrg+mrVP+2wunL12O82teXakjsA0GHb1x123U2uvHCu5tciZbi3nzNhkUMAy3d
# +azRMG0gwrPJHup1/FwUHdCkMuIYN5X5kVudXSoi6bystyZcal8d8maAm5OLvGaO
# fhJQGMHnxDpOGo2aF0kyxCg+D9IKdifGj5/aWm0tsLwFUDw5dzrRA1GWWK7BPd4b
# OBXe+/O6u3mlhZeoIYWiiSjkfQcLHrWGbHl8hRkmtzWUKpXcevZ1vvyYvHYm5HwK
# SL1kBzGVy46xy8gW8EcG1yO4cdyJOzRZ/kbGqhzQ7w4V1eFHZXxduupH3de+OYmL
# LNHSytJUT8bXVpZAXH71UWmXwO4=
# SIG # End signature block
